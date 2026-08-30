import Accelerate
import CoreVideo

/// Produces the outgoing virtual-camera frame by reflecting captured pixels.
///
/// This is deliberately an explicit pixel operation. Preview mirroring lives on
/// the preview connections and is presentation state only; it must never be
/// used to produce what other apps receive.
final class FrameMirror {

    private var pool: CVPixelBufferPool?
    private var poolWidth = 0
    private var poolHeight = 0

    /// Returns `source` unchanged for `.unmirrored`, or a horizontally
    /// reflected copy for `.mirrored`. Dimensions and crop are preserved.
    func frame(from source: CVPixelBuffer, orientation: VirtualCameraOrientation) -> CVPixelBuffer? {
        guard orientation.requiresHorizontalReflection else { return source }
        return mirroredHorizontally(source)
    }

    func mirroredHorizontally(_ source: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)

        guard CVPixelBufferGetPixelFormatType(source) == kCVPixelFormatType_32BGRA,
              let pool = reusablePool(width: width, height: height)
        else { return nil }

        var destination: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &destination) == kCVReturnSuccess,
              let destination
        else { return nil }

        CVPixelBufferLockBaseAddress(source, .readOnly)
        CVPixelBufferLockBaseAddress(destination, [])
        defer {
            CVPixelBufferUnlockBaseAddress(destination, [])
            CVPixelBufferUnlockBaseAddress(source, .readOnly)
        }

        guard var input = imageBuffer(source), var output = imageBuffer(destination) else { return nil }
        guard vImageHorizontalReflect_ARGB8888(&input, &output, vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
            return nil
        }
        return destination
    }

    // MARK: - Private

    /// One pool per size, reused across frames. Recreated only when the capture
    /// dimensions actually change.
    private func reusablePool(width: Int, height: Int) -> CVPixelBufferPool? {
        if let pool, poolWidth == width, poolHeight == height { return pool }

        let attributes: NSDictionary = [
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            // Required so the buffer can cross to the Camera Extension later.
            kCVPixelBufferIOSurfacePropertiesKey: [:] as NSDictionary,
        ]

        var created: CVPixelBufferPool?
        guard CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes, &created) == kCVReturnSuccess else {
            return nil
        }
        pool = created
        poolWidth = width
        poolHeight = height
        return created
    }

    private func imageBuffer(_ buffer: CVPixelBuffer) -> vImage_Buffer? {
        guard let data = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        return vImage_Buffer(
            data: data,
            height: vImagePixelCount(CVPixelBufferGetHeight(buffer)),
            width: vImagePixelCount(CVPixelBufferGetWidth(buffer)),
            rowBytes: CVPixelBufferGetBytesPerRow(buffer)
        )
    }
}
