import CoreML
@testable import SoundView
import XCTest

/// Cross-checks Swift's `DemucsSpec` against torch ground truth (tools/spec_probe.py).
/// Reads the exact same samples torch used and dumps Swift's spectrum so the two
/// can be SNR-compared — the seam the Python parity gate never exercised.
/// Enabled only when `PROBE_DIR` points at the probe interchange directory.
final class DemucsProbeTests: XCTestCase {
    /// The interchange dir written by `tools/spec_probe.py`. Off by default; set
    /// `PROBE_DIR` to re-run the torch cross-check. See docs/COREML.md.
    private func probeDir() throws -> URL {
        guard let path = ProcessInfo.processInfo.environment["PROBE_DIR"],
              FileManager.default.fileExists(atPath: path + "/probe_x.f32") else {
            throw XCTSkip("Set PROBE_DIR (run tools/spec_probe.py) to enable the probe.")
        }
        return URL(fileURLWithPath: path)
    }

    private func readF32(_ url: URL) throws -> [Float] {
        let data = try Data(contentsOf: url)
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float32.self)) }
    }

    private func writeF32(_ values: [Float], to url: URL) throws {
        var copy = values
        try copy.withUnsafeBytes { try Data($0).write(to: url) }
    }

    func testDumpSwiftSpec() throws {
        let dir = try probeDir()
        let x = try readF32(dir.appendingPathComponent("probe_x.f32"))
        let segment = 343_980, channels = 2
        XCTAssertEqual(x.count, segment * channels)

        guard let spec = DemucsSpec() else { return XCTFail("DemucsSpec init") }
        var out: [Float] = []
        out.reserveCapacity(channels * 2 * spec.bins * spec.frames)
        for channel in 0..<channels {
            let samples = Array(x[channel * segment ..< (channel + 1) * segment])
            let s = spec.forward(samples)
            out.append(contentsOf: s.real)   // channel-major: [c0r, c0i, c1r, c1i]
            out.append(contentsOf: s.imag)
        }
        try writeF32(out, to: dir.appendingPathComponent("probe_swift_spec.f32"))
        print("[probe] wrote swift spec: \(out.count) floats")
    }

    /// Runs one Core ML model directly (drums) on the synthetic mix and dumps its
    /// raw `spec_stem` + `wave_stem` — isolates the model runtime from DemucsSpec.
    func testDumpModelOutput() throws {
        try XCTSkipUnless(CoreMLDemucsBackend.isModelBundled, "models not bundled")
        let dir = try probeDir()
        let x = try readF32(dir.appendingPathComponent("probe_x.f32"))
        let segment = 343_980, channels = 2
        guard let spec = DemucsSpec() else { return XCTFail("DemucsSpec") }
        let bins = spec.bins, frames = spec.frames, planeSize = bins * frames

        // Build mix + spec inputs exactly like the backend does.
        let mix = try MLMultiArray(shape: [1, channels as NSNumber, segment as NSNumber], dataType: .float32)
        let mixP = mix.dataPointer.bindMemory(to: Float.self, capacity: channels * segment)
        let specArr = try MLMultiArray(
            shape: [1, (channels * 2) as NSNumber, bins as NSNumber, frames as NSNumber], dataType: .float32)
        let specP = specArr.dataPointer.bindMemory(to: Float.self, capacity: channels * 2 * planeSize)
        for channel in 0..<channels {
            let samples = Array(x[channel * segment ..< (channel + 1) * segment])
            for index in 0..<segment { mixP[channel * segment + index] = samples[index] }
            let cs = spec.forward(samples)
            for index in 0..<planeSize {
                specP[(channel * 2) * planeSize + index] = cs.real[index]
                specP[(channel * 2 + 1) * planeSize + index] = cs.imag[index]
            }
        }

        let config = MLModelConfiguration()
        config.computeUnits = .cpuOnly
        guard let url = Bundle.main.url(forResource: "htdemucs_ft_drums", withExtension: "mlmodelc") else {
            return XCTFail("drums model not in bundle")
        }
        let model = try MLModel(contentsOf: url, configuration: config)
        let input = try MLDictionaryFeatureProvider(dictionary: ["mix": mix, "spec": specArr])
        let out = try model.prediction(from: input)
        guard let specStem = out.featureValue(for: "spec_stem")?.multiArrayValue,
              let waveStem = out.featureValue(for: "wave_stem")?.multiArrayValue else {
            return XCTFail("outputs: \(out.featureNames)")
        }
        // The exact values the backend's reconstruct() consumes.
        try writeF32(try specStem.floatValues(),
                     to: dir.appendingPathComponent("probe_swift_specstem_drums.f32"))
        try writeF32(try waveStem.floatValues(),
                     to: dir.appendingPathComponent("probe_swift_wavestem_drums.f32"))
        func tight(_ a: MLMultiArray) -> [Int] {  // contiguous strides for its shape
            let s = a.shape.map { $0.intValue }
            var out = [Int](repeating: 1, count: s.count)
            for i in stride(from: s.count - 2, through: 0, by: -1) { out[i] = out[i + 1] * s[i + 1] }
            return out
        }
        print("[probe] spec_stem shape=\(specStem.shape.map { $0.intValue }) "
              + "strides=\(specStem.strides.map { $0.intValue }) tight=\(tight(specStem)) "
              + "dtype=\(specStem.dataType.rawValue) count=\(specStem.count)")
        print("[probe] wave_stem shape=\(waveStem.shape.map { $0.intValue }) "
              + "strides=\(waveStem.strides.map { $0.intValue }) tight=\(tight(waveStem)) "
              + "dtype=\(waveStem.dataType.rawValue) count=\(waveStem.count)")
    }

    /// Invert torch's own spectra with Swift's `inverse` — isolates the iSTFT.
    /// Reads torch [2C, bins, frames] (channel order c0r,c0i,c1r,c1i) and writes
    /// Swift inverse [C, segment] for both the mixture spec and a masked spec.
    func testDumpSwiftInverse() throws {
        let dir = try probeDir()
        let channels = 2
        guard let spec = DemucsSpec() else { return XCTFail("DemucsSpec init") }
        let planeSize = spec.bins * spec.frames

        func invert(_ file: String) throws -> [Float] {
            let flat = try readF32(dir.appendingPathComponent(file))
            XCTAssertEqual(flat.count, channels * 2 * planeSize)
            var out: [Float] = []
            for channel in 0..<channels {
                let rBase = (channel * 2) * planeSize
                let iBase = (channel * 2 + 1) * planeSize
                let cs = DemucsSpec.ChannelSpectrum(
                    real: Array(flat[rBase ..< rBase + planeSize]),
                    imag: Array(flat[iBase ..< iBase + planeSize])
                )
                out.append(contentsOf: spec.inverse(cs))
            }
            return out  // [C, segment]
        }

        try writeF32(try invert("probe_torch_spec.f32"),
                     to: dir.appendingPathComponent("probe_swift_ispec_ref.f32"))
        try writeF32(try invert("probe_masked_spec.f32"),
                     to: dir.appendingPathComponent("probe_swift_ispec_masked.f32"))
        print("[probe] wrote swift inverse (ref + masked)")
    }

    /// Full Swift pipeline (backend + Core ML models + iSTFT + OLA) on the same
    /// synthetic mix, dumped as [S, C, segment] in manifest source order.
    func testDumpSwiftStems() async throws {
        try XCTSkipUnless(CoreMLDemucsBackend.isModelBundled, "Demucs models not bundled")
        let dir = try probeDir()
        let x = try readF32(dir.appendingPathComponent("probe_x.f32"))
        let segment = 343_980, channels = 2, sampleRate = 44_100.0
        guard let manifest = DemucsManifest.bundled() else { return XCTFail("manifest") }

        // Write the exact samples as a canonical WAV for the backend to load.
        var interleaved = [Float](repeating: 0, count: segment * channels)
        for frame in 0..<segment {
            for channel in 0..<channels {
                interleaved[frame * channels + channel] = x[channel * segment + frame]
            }
        }
        let pcm = AudioFileIO.PCMBuffer(
            sampleRate: sampleRate, channelCount: channels, interleaved: interleaved
        )
        let wavURL = dir.appendingPathComponent("probe_mix.wav")
        try AudioFileIO.writeWAV(pcm: pcm, to: wavURL)

        var byKey: [String: URL] = [:]
        for try await event in CoreMLDemucsBackend().separate(
            originalURL: wavURL, title: "probe", duration: 7.8, mode: .four
        ) {
            if case .stem(let stem) = event { byKey[stem.id] = stem.fileURL }
        }

        var out: [Float] = []
        for key in manifest.sources {
            guard let url = byKey[key] else { return XCTFail("missing stem \(key)") }
            let stem = try AudioFileIO.loadPCM(from: url)  // interleaved [C]
            var planar = [Float](repeating: 0, count: segment * channels)
            for frame in 0..<min(segment, stem.frameCount) {
                for channel in 0..<channels {
                    planar[channel * segment + frame] =
                        stem.interleaved[frame * stem.channelCount + channel]
                }
            }
            out.append(contentsOf: planar)  // [S, C, segment]
        }
        try writeF32(out, to: dir.appendingPathComponent("probe_swift_stems.f32"))
        print("[probe] wrote swift stems: \(out.count) floats, order=\(manifest.sources)")
    }
}
