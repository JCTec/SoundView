import CoreML
import XCTest
@testable import SoundView

/// Proves the on-device crash fix: reading a Core ML **fp16** output tensor as
/// `Float` (the bug) vs. honoring its dtype (the fix). No Neural Engine needed —
/// an fp16 `MLMultiArray` built by hand exercises the exact read path that faulted.
final class MLMultiArrayFloatTests: XCTestCase {
    func testReadsFloat16StorageAsFloat() throws {
        let array = try MLMultiArray(shape: [6], dataType: .float16)
        // All exactly representable in fp16, so equality is exact.
        let values: [Float] = [0, 0.5, -0.25, 1.5, -2.0, 3.75]
        for (index, value) in values.enumerated() {
            array[index] = NSNumber(value: value)
        }

        let out = try array.floatValues()
        XCTAssertEqual(out.count, values.count)
        for (index, value) in values.enumerated() {
            XCTAssertEqual(out[index], value, accuracy: 0.001, "fp16 read mismatch at \(index)")
        }
    }

    func testReadsFloat32Storage() throws {
        let array = try MLMultiArray(shape: [4], dataType: .float32)
        let values: [Float] = [1, -2, 3.5, 4]
        for (index, value) in values.enumerated() {
            array[index] = NSNumber(value: value)
        }
        XCTAssertEqual(try array.floatValues(), values)
    }

    /// The crux: fp16 storage is 2 bytes/element, so reading `count` elements as
    /// Float16 stays in bounds — reading them as Float32 (the old bug) would run
    /// twice past the buffer and fault.
    func testFloat16MultiAxisReadStaysInBounds() throws {
        let array = try MLMultiArray(shape: [1, 512, 1024, 2], dataType: .float16)
        let out = try array.floatValues()
        XCTAssertEqual(out.count, 512 * 1024 * 2)
    }

    /// The garbled-audio bug: on-device `MLModel` outputs are **row-padded** (last
    /// axis stride > its length), so a contiguous read drifts into padding after
    /// the first row. `floatValues()` must gather by `strides` and return tight
    /// logical order. Build a padded array by hand (last axis 3, stride 4) and prove
    /// the padding never leaks into the result.
    func testNonContiguousStridesReturnTightLogicalOrder() throws {
        let shape = [2, 3]                 // logical 6 values
        let rowStride = 4                  // padded: 1 junk float after each row of 3
        let backing = 2 * rowStride        // 8 floats
        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: backing)
        defer { buffer.deallocate() }
        buffer.initialize(repeating: -999, count: backing)          // padding = sentinel
        let logical: [Float] = [1, 2, 3, 4, 5, 6]
        for row in 0..<2 {
            for col in 0..<3 { buffer[row * rowStride + col] = logical[row * 3 + col] }
        }

        let array = try MLMultiArray(
            dataPointer: buffer,
            shape: shape.map { NSNumber(value: $0) },
            dataType: .float32,
            strides: [rowStride, 1].map { NSNumber(value: $0) }
        )
        let out = try array.floatValues()
        XCTAssertEqual(out, logical, "must skip row padding, not read the sentinel")
        XCTAssertFalse(out.contains(-999), "padding leaked into the flattened output")
    }
}
