import CoreML

extension MLMultiArray {
    /// Flattens the array to `[Float]`, converting from its **actual** element
    /// type. Core ML returns **fp16** tensors from the Neural Engine and fp32 from
    /// the CPU; reading fp16 storage as 32-bit `Float` reads twice the bytes that
    /// exist and faults, so the read must honor `dataType`. Elements are taken in
    /// memory order (Core ML prediction outputs are contiguous); callers apply the
    /// array's `strides` on top for indexing.
    func floatValues() throws -> [Float] {
        // The backing buffer may be larger than `count` (Core ML can pad rows, so
        // strides aren't tight). Size the read to the strided extent so callers can
        // index it by `strides` without running off the end.
        let shapeInts = shape.map { $0.intValue }
        let strideInts = strides.map { $0.intValue }
        let capacity = zip(shapeInts, strideInts)
            .reduce(0) { $0 + max(0, $1.0 - 1) * max(0, $1.1) } + 1

        switch dataType {
        case .float32:
            let pointer = dataPointer.bindMemory(to: Float.self, capacity: capacity)
            return Array(UnsafeBufferPointer(start: pointer, count: capacity))
        case .float16:
            let pointer = dataPointer.bindMemory(to: Float16.self, capacity: capacity)
            return (0..<capacity).map { Float(pointer[$0]) }
        case .double:
            let pointer = dataPointer.bindMemory(to: Double.self, capacity: capacity)
            return (0..<capacity).map { Float(pointer[$0]) }
        @unknown default:
            throw StemSeparatorError.modelUnavailable(
                "Unsupported model output type (\(dataType.rawValue))."
            )
        }
    }
}
