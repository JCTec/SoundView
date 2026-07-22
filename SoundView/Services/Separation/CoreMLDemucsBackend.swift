import CoreML
import Foundation

/// On-device separation with Meta's **official Demucs** (`htdemucs_ft`), wired to
/// `htdemucs_manifest.json`. `htdemucs_ft` is a bag of four fine-tuned HTDemucs
/// nets, one per stem; each model input is `mix [1,2,343980]` + `spec [1,4,2048,336]`
/// (mixture STFT, complex-as-channels) and it returns its owned source's
/// `spec_stem [1,4,2048,336]` + `wave_stem [1,2,343980]`.
///
/// The app computes STFT/iSTFT in vDSP (`Math/DemucsSpec.swift`) because Core ML
/// cannot convert torch's complex STFT ops. Per chunk it runs all four models,
/// reconstructs each owned stem as `iSTFT(spec_stem) + wave_stem` (Demucs' hybrid
/// spectral + time branches), and overlap-adds 7.8 s chunks (25 % hop, Hann WOLA).
struct CoreMLDemucsBackend: StemSeparationBackend {
    /// Explicit compiled-model directory (a user-imported bag, resolved by
    /// `ModelCatalog`). `nil` uses the bundled models named in the manifest.
    var modelBundleURL: URL?

    /// Every model resource named in the manifest resolves to a compiled `.mlmodelc`.
    static var isModelBundled: Bool {
        guard let manifest = DemucsManifest.bundled() else { return false }
        return manifest.models.allSatisfy { entry in
            Bundle.main.url(forResource: entry.resource, withExtension: "mlmodelc") != nil
        }
    }

    func separate(
        originalURL: URL,
        title: String,
        duration: TimeInterval,
        mode: StemMode
    ) -> AsyncThrowingStream<BackendStemEvent, Error> {
        let bundleURL = modelBundleURL
        return AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                do {
                    try await Engine(modelBundleURL: bundleURL)
                        .run(originalURL: originalURL, continuation: continuation)
                    continuation.finish()
                } catch is CancellationError {
                    Log.notice(.separation, "Demucs cancelled")
                    continuation.finish(throwing: CancellationError())
                } catch {
                    Log.error(.separation, "Demucs failed", Log.withMemory([
                        "error": String(describing: error)
                    ]))
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - Engine

/// One separation run. Not an actor: lives entirely on its detached task.
private final class Engine {
    private let manifest: DemucsManifest
    private let spec: DemucsSpec
    private let crossfade: [Float]
    private let modelBundleURL: URL?
    private var chunkSeconds: [TimeInterval] = []

    private var segment: Int { manifest.segmentSamples }
    private var channels: Int { manifest.channels }
    private var bins: Int { manifest.bins }
    private var frames: Int { manifest.frames }

    init(modelBundleURL: URL?) {
        self.modelBundleURL = modelBundleURL
        guard let manifest = DemucsManifest.bundled() else {
            preconditionFailure("Demucs manifest missing — availability gate should prevent this.")
        }
        self.manifest = manifest
        guard let spec = DemucsSpec(
            nfft: manifest.nfft, hop: manifest.hop,
            frames: manifest.frames, segmentSamples: manifest.segmentSamples
        ) else {
            preconditionFailure("DemucsSpec init cannot fail with power-of-two nfft.")
        }
        self.spec = spec
        crossfade = OverlapAdd.hannWindow(length: manifest.segmentSamples)
    }

    func run(
        originalURL: URL,
        continuation: AsyncThrowingStream<BackendStemEvent, Error>.Continuation
    ) async throws {
        continuation.yield(.progress(0.02, eta: nil))

        let pcm = try AudioFileIO.loadPCMCanonical(from: originalURL)
        let totalFrames = pcm.frameCount
        guard totalFrames > 0 else {
            throw StemSeparatorError.modelUnavailable("This file has no audio to separate.")
        }
        let hop = segment * 3 / 4
        let chunkCount = max(1, (max(0, totalFrames - 1)) / hop + 1)
        let modelCount = manifest.models.count
        Log.info(.separation, "Demucs start", Log.withMemory([
            "model": "htdemucs_ft",
            "seconds": String(format: "%.1f", Double(totalFrames) / pcm.sampleRate),
            "chunks": String(chunkCount)
        ]))

        // Per-stem streaming WAV files in one temp dir (constant memory, any length).
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SoundView-sep-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        // Model-outer, chunk-inner: only ONE 100+ MB model is resident at a time.
        // Loading all four HTDemucs nets at once blows the on-device jetsam limit
        // during model load. Prediction count (models × chunks) is unchanged; we
        // just re-derive the cheap vDSP STFT per pass instead of once per chunk.
        let totalUnits = modelCount * chunkCount
        var unitsDone = 0
        var producedStems: [ProducedStem] = []

        for (modelIndex, entry) in manifest.models.enumerated() {
            try Task.checkCancellation()
            let key = manifest.sources[entry.sourceIndex]
            let stemURL = root.appendingPathComponent("\(key).wav")
            Log.breadcrumb("demucs: model \(modelIndex + 1)/\(modelCount) (\(key))")

            try autoreleasepool {
                let model = try loadModel(entry)
                Log.info(.coreml, "model loaded", Log.withMemory(["stem": key]))
                let streamer = OverlapAddStreamer(
                    segment: segment, channels: channels, window: crossfade
                )
                let writer = try WAVStreamWriter(
                    url: stemURL, sampleRate: pcm.sampleRate, channels: channels
                )

                for chunk in 0..<chunkCount {
                    try Task.checkCancellation()
                    let started = Date()
                    let offset = chunk * hop
                    try autoreleasepool {
                        let channelSamples = extractChunk(pcm: pcm, offset: offset)
                        let stem = try predictStem(model: model, channelSamples: channelSamples)
                        let flush = chunk == chunkCount - 1 ? totalFrames - offset : hop
                        try writer.append(streamer.push(stem, flush: flush))
                    }
                    // DIAG: per-chunk memory trajectory (flat = load spike; rising = leak).
                    Log.info(.separation, "chunk", Log.withMemory([
                        "stem": key, "chunk": "\(chunk + 1)/\(chunkCount)"
                    ]))
                    unitsDone += 1
                    chunkSeconds.append(Date().timeIntervalSince(started))
                    let average = chunkSeconds.reduce(0, +) / Double(chunkSeconds.count)
                    let done = Double(unitsDone) / Double(totalUnits)
                    continuation.yield(.progress(
                        0.02 + done * 0.9, eta: average * Double(totalUnits - unitsDone)
                    ))
                }
                Log.info(.separation, "stem done", Log.withMemory([
                    "stem": key, "model": "\(modelIndex + 1)/\(modelCount)"
                ]))
            }  // model + streamer + writer released before the next model loads

            producedStems.append(ProducedStem(
                id: key,
                name: StemCatalog.displayName(forFileKey: key),
                index: entry.sourceIndex,
                fileURL: stemURL
            ))
        }

        Log.breadcrumb("demucs: finalizing stems")
        for stem in producedStems.sorted(by: { $0.index < $1.index }) {
            continuation.yield(.stem(stem))
        }
        continuation.yield(.progress(1, eta: 0))
        Log.info(.separation, "Demucs done", Log.withMemory(["chunks": String(chunkCount)]))
        Log.clearBreadcrumb()
    }

    /// Loads a single fine-tuned net. Only one is ever resident (see `run`).
    private func loadModel(_ entry: DemucsManifest.ModelEntry) throws -> MLModel {
        let configuration = MLModelConfiguration()
        // CPU only. The GPU/MPSGraph backend faults on these converted models, and
        // the Neural Engine OOM-kills the app *while compiling* a single htdemucs
        // net (the ANE program for its large tensors exceeds the jetsam limit before
        // the model is even usable — confirmed on-device: death inside MLModel init,
        // before any prediction). CPU inference is memory-bounded and is the same
        // path the E2E separation test exercises.
        configuration.computeUnits = .cpuOnly
        let url: URL
        if let bundle = modelBundleURL {
            url = bundle.appendingPathComponent("\(entry.resource).mlmodelc")
        } else if let bundled = Bundle.main.url(
            forResource: entry.resource, withExtension: "mlmodelc"
        ) {
            url = bundled
        } else {
            throw StemSeparatorError.modelUnavailable(
                "Demucs model '\(entry.resource)' isn't bundled — see docs/COREML.md."
            )
        }
        Log.info(.coreml, "loading Demucs model", Log.withMemory(["resource": entry.resource]))
        return try MLModel(contentsOf: url, configuration: configuration)
    }

    // MARK: - Per chunk

    /// The mixture chunk at `offset` → `[channel][segment]` (zero-padded past EOF).
    /// Feeds both the raw `mix` input and the `spec` STFT.
    private func extractChunk(pcm: AudioFileIO.PCMBuffer, offset: Int) -> [[Float]] {
        var channelSamples: [[Float]] = []
        for channel in 0..<channels {
            var samples = [Float](repeating: 0, count: segment)
            for index in 0..<segment {
                let frame = offset + index
                if frame < pcm.frameCount {
                    samples[index] = pcm.interleaved[frame * pcm.channelCount + channel]
                }
            }
            channelSamples.append(samples)
        }
        return channelSamples
    }

    /// Runs one model on one chunk → its owned source's `[channel][segment]`.
    private func predictStem(model: MLModel, channelSamples: [[Float]]) throws -> [[Float]] {
        let mixArray = try makeMixArray(channelSamples)
        let specArray = try makeSpecArray(channelSamples)
        let input = try MLDictionaryFeatureProvider(
            dictionary: ["mix": mixArray, "spec": specArray]
        )
        return try reconstruct(prediction: try model.prediction(from: input))
    }

    private func makeMixArray(_ channelSamples: [[Float]]) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: [1, channels as NSNumber, segment as NSNumber], dataType: .float32)
        let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: channels * segment)
        for channel in 0..<channels {
            let base = channel * segment
            for index in 0..<segment { pointer[base + index] = channelSamples[channel][index] }
        }
        return array
    }

    private func makeSpecArray(_ channelSamples: [[Float]]) throws -> MLMultiArray {
        let array = try MLMultiArray(
            shape: [1, (channels * 2) as NSNumber, bins as NSNumber, frames as NSNumber],
            dataType: .float32
        )
        let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: channels * 2 * bins * frames)
        let planeSize = bins * frames
        for channel in 0..<channels {
            let channelSpec = spec.forward(channelSamples[channel])
            let realPlane = channel * 2, imagPlane = channel * 2 + 1
            for index in 0..<planeSize {
                pointer[realPlane * planeSize + index] = channelSpec.real[index]
                pointer[imagPlane * planeSize + index] = channelSpec.imag[index]
            }
        }
        return array
    }

    /// One model's outputs → owned source's `[channel][segment]` waveform:
    /// `iSTFT(spec_stem)` (spectral branch) + `wave_stem` (time branch).
    private func reconstruct(prediction: MLFeatureProvider) throws -> [[Float]] {
        guard let specStem = prediction.featureValue(for: "spec_stem")?.multiArrayValue,
              let waveStem = prediction.featureValue(for: "wave_stem")?.multiArrayValue else {
            let names = prediction.featureNames.sorted().joined(separator: ", ")
            throw StemSeparatorError.modelUnavailable(
                "Model outputs don't match the manifest (got: \(names))."
            )
        }
        // Read respecting the actual dtype — the Neural Engine returns fp16 tensors,
        // and reading them as Float32 would fault (see MLMultiArray+Float).
        let spec32 = try specStem.floatValues()
        let wave32 = try waveStem.floatValues()
        let planeSize = bins * frames

        var channelsOut: [[Float]] = []
        for channel in 0..<channels {
            let realBase = (channel * 2) * planeSize
            let imagBase = (channel * 2 + 1) * planeSize
            let channelSpec = DemucsSpec.ChannelSpectrum(
                real: Array(spec32[realBase..<realBase + planeSize]),
                imag: Array(spec32[imagBase..<imagBase + planeSize])
            )
            var waveform = spec.inverse(channelSpec)
            let timeBase = channel * segment
            for index in 0..<segment { waveform[index] += wave32[timeBase + index] }
            channelsOut.append(waveform)
        }
        return channelsOut
    }
}
