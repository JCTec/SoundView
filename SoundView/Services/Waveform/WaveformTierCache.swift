import CryptoKit
import Foundation

/// Disk cache for peak-tier pyramids — computing tiers means decoding the whole
/// stem, so every open after the first should skip straight to draw.
///
/// Format: compact binary in Caches (evictable by the OS, never synced):
/// [UInt32 magic][Float64 duration][UInt32 tierCount] then per tier
/// [UInt32 bucketCount][Float32 min,max × buckets]. Keyed by file path + size +
/// modification date, so a re-separated stem never serves stale peaks.
enum WaveformTierCache {
    private static let magic: UInt32 = 0x5356_5741 // "SVWA"

    static func cacheURL(for audioURL: URL) -> URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = caches.appendingPathComponent("WaveformTiers", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        return folder.appendingPathComponent("\(cacheKey(for: audioURL)).svwave")
    }

    /// Container-independent identity: the app's sandbox path changes on every
    /// reinstall (each Xcode run), so absolute paths must never enter the key.
    /// package-folder/file-name + size + mtime survives reinstalls and still
    /// invalidates when a stem is re-separated. v3 = key-scheme bump.
    static func cacheKey(for audioURL: URL) -> String {
        let values = try? audioURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let size = values?.fileSize ?? 0
        let modified = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
        let identity = audioURL.pathComponents.suffix(2).joined(separator: "/")
        let key = "\(identity)|\(size)|\(modified)|v3"
        let digest = SHA256.hash(data: Data(key.utf8))
        return String(digest.map { String(format: "%02x", $0) }.joined().prefix(32))
    }

    static func load(for audioURL: URL) -> WaveformTiers? {
        let key = cacheKey(for: audioURL)
        if let inMemory = memory.value(for: key) {
            return inMemory
        }
        guard let url = cacheURL(for: audioURL),
              let data = try? Data(contentsOf: url),
              let tiers = decode(data) else { return nil }
        memory.store(tiers, for: key)
        return tiers
    }

    static func store(_ tiers: WaveformTiers, for audioURL: URL) {
        memory.store(tiers, for: cacheKey(for: audioURL))
        guard let url = cacheURL(for: audioURL) else { return }
        try? encode(tiers).write(to: url, options: .atomic)
    }

    /// Session-lifetime layer above disk: reopening the same song skips even the
    /// cache-file read. Bounded, thread-safe (loads run on detached tasks).
    private static let memory = MemoryStore()

    private final class MemoryStore: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [String: WaveformTiers] = [:]
        private let capacity = 24 // ~2.5 MB per 5-min stem at the finest tier

        func value(for key: String) -> WaveformTiers? {
            lock.lock()
            defer { lock.unlock() }
            return entries[key]
        }

        func store(_ tiers: WaveformTiers, for key: String) {
            lock.lock()
            defer { lock.unlock() }
            if entries.count >= capacity {
                entries.removeAll() // simple full flush; songs reload from disk cheaply
            }
            entries[key] = tiers
        }
    }

    // MARK: - Binary coding

    static func encode(_ tiers: WaveformTiers) -> Data {
        var data = Data()
        append(magic, to: &data)
        append(tiers.duration.bitPattern, to: &data)
        append(UInt32(tiers.tiers.count), to: &data)
        for (bucketCount, peaks) in tiers.tiers.sorted(by: { $0.key < $1.key }) {
            append(UInt32(bucketCount), to: &data)
            append(UInt32(peaks.count), to: &data)
            for peak in peaks {
                append(peak.min.bitPattern, to: &data)
                append(peak.max.bitPattern, to: &data)
            }
        }
        return data
    }

    static func decode(_ data: Data) -> WaveformTiers? {
        var cursor = 0
        guard read(UInt32.self, from: data, at: &cursor) == magic,
              let durationBits = read(UInt64.self, from: data, at: &cursor),
              let tierCount = read(UInt32.self, from: data, at: &cursor) else { return nil }

        var tiers: [Int: [PeakDecimation.Peak]] = [:]
        for _ in 0..<tierCount {
            guard let bucketCount = read(UInt32.self, from: data, at: &cursor),
                  let peakCount = read(UInt32.self, from: data, at: &cursor) else { return nil }
            var peaks: [PeakDecimation.Peak] = []
            peaks.reserveCapacity(Int(peakCount))
            for _ in 0..<peakCount {
                guard let minBits = read(UInt32.self, from: data, at: &cursor),
                      let maxBits = read(UInt32.self, from: data, at: &cursor) else { return nil }
                peaks.append(PeakDecimation.Peak(
                    min: Float(bitPattern: minBits),
                    max: Float(bitPattern: maxBits)
                ))
            }
            tiers[Int(bucketCount)] = peaks
        }
        return WaveformTiers(tiers: tiers, duration: Double(bitPattern: durationBits))
    }

    // MARK: - Primitives

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }

    private static func read<T: FixedWidthInteger>(_ type: T.Type, from data: Data, at cursor: inout Int) -> T? {
        let size = MemoryLayout<T>.size
        guard cursor + size <= data.count else { return nil }
        let value = data.subdata(in: cursor..<(cursor + size)).withUnsafeBytes {
            $0.loadUnaligned(as: T.self)
        }
        cursor += size
        return T(littleEndian: value)
    }
}
