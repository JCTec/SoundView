import Foundation
import os

/// On-device memory diagnostics — the signal for OOM/jetsam kills (the prime
/// suspect for a crash during full-song separation).
enum MemoryReport {
    /// Bytes remaining before this app is likely jetsam-killed. Returns 0 where
    /// the API is unavailable (e.g. the simulator).
    static var availableBytes: UInt64 {
        UInt64(os_proc_available_memory())
    }

    /// The app's current physical memory footprint (what jetsam accounts for).
    static var footprintBytes: UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? UInt64(info.phys_footprint) : 0
    }

    static var availableMB: Int { Int(availableBytes / 1_048_576) }
    static var footprintMB: Int { Int(footprintBytes / 1_048_576) }

    /// Metadata block to attach to a log event.
    static func snapshot() -> [String: String] {
        ["footprintMB": String(footprintMB), "availableMB": String(availableMB)]
    }
}
