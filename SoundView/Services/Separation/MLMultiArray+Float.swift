import CoreML

extension MLMultiArray {
    /// Flattens the array to `[Float]` in **tight, row-major logical order**,
    /// converting from its **actual** element type.
    ///
    /// Two runtime facts make the naïve read wrong:
    /// 1. Core ML returns **fp16** from the Neural Engine and fp32 from the CPU, so
    ///    the read must honor `dataType` (reading fp16 as 32-bit `Float` faults).
    /// 2. On-device/simulator `MLModel` outputs are **not contiguous** — the last
    ///    axis is padded for alignment (e.g. `spec_stem` `[1,4,2048,336]` ships
    ///    with a row stride of 352, not 336), so `strides` ≠ the tight strides.
    ///    coremltools' NumPy path *is* tight, which is why this only bites on device.
    ///
    /// So we gather by `strides` and return a densely-packed array whose element
    /// `i` is the `i`-th element in logical order — letting callers index it with
    /// plain contiguous arithmetic (`plane * bins * frames + …`).
    func floatValues() throws -> [Float] {
        let shape = self.shape.map { $0.intValue }
        let strides = self.strides.map { $0.intValue }
        let total = shape.reduce(1, *)

        // Tight (contiguous) strides for this shape; if they match, it's a fast copy.
        var tight = [Int](repeating: 1, count: shape.count)
        if shape.count >= 2 {
            for axis in stride(from: shape.count - 2, through: 0, by: -1) {
                tight[axis] = tight[axis + 1] * shape[axis + 1]
            }
        }
        let contiguous = strides == tight
        // Largest byte offset any logical index can reach (for the bind capacity).
        let extent = zip(shape, strides).reduce(0) { $0 + max(0, $1.0 - 1) * max(0, $1.1) } + 1

        func gather<Element>(_ pointer: UnsafePointer<Element>, _ convert: (Element) -> Float) -> [Float] {
            if contiguous {
                return (0..<total).map { convert(pointer[$0]) }
            }
            var out = [Float](repeating: 0, count: total)
            var coordinate = [Int](repeating: 0, count: shape.count)
            for logical in 0..<total {
                var offset = 0
                for axis in 0..<shape.count { offset += coordinate[axis] * strides[axis] }
                out[logical] = convert(pointer[offset])
                var axis = shape.count - 1                      // row-major increment
                while axis >= 0 {
                    coordinate[axis] += 1
                    if coordinate[axis] < shape[axis] { break }
                    coordinate[axis] = 0
                    axis -= 1
                }
            }
            return out
        }

        switch dataType {
        case .float32:
            return gather(dataPointer.bindMemory(to: Float.self, capacity: extent)) { $0 }
        case .float16:
            return gather(dataPointer.bindMemory(to: Float16.self, capacity: extent)) { Float($0) }
        case .double:
            return gather(dataPointer.bindMemory(to: Double.self, capacity: extent)) { Float($0) }
        @unknown default:
            throw StemSeparatorError.modelUnavailable(
                "Unsupported model output type (\(dataType.rawValue))."
            )
        }
    }
}
