import CoreVideo
import XCTest

@testable import unflip

/// Pixel-level proof that the published orientation is produced by an explicit
/// transform, not by preview presentation state.
final class FrameMirrorTests: XCTestCase {

    private let mirror = FrameMirror()

    func testMirroredOrientationReflectsAsymmetricInputHorizontally() throws {
        // Deliberately asymmetric: every pixel carries its own x position.
        let source = try makeBuffer(width: 4, height: 2) { x, y in UInt32(x + 1 + y * 10) }

        let reflected = try XCTUnwrap(mirror.frame(from: source, orientation: .mirrored))

        XCTAssertEqual(try pixels(of: reflected, width: 4, height: 2), [
            [4, 3, 2, 1],
            [14, 13, 12, 11],
        ])
    }

    func testUnmirroredOrientationLeavesTheFrameAlone() throws {
        let source = try makeBuffer(width: 4, height: 2) { x, y in UInt32(x + 1 + y * 10) }

        let passed = try XCTUnwrap(mirror.frame(from: source, orientation: .unmirrored))

        XCTAssertTrue(passed === source, "an unmirrored publish must not spend a copy")
        XCTAssertEqual(try pixels(of: passed, width: 4, height: 2), [
            [1, 2, 3, 4],
            [11, 12, 13, 14],
        ])
    }

    func testReflectingTwiceReturnsTheOriginalImage() throws {
        let source = try makeBuffer(width: 6, height: 3) { x, y in UInt32(x + 1 + y * 10) }

        let once = try XCTUnwrap(mirror.mirroredHorizontally(source))
        let twice = try XCTUnwrap(mirror.mirroredHorizontally(once))

        XCTAssertEqual(try pixels(of: twice, width: 6, height: 3), try pixels(of: source, width: 6, height: 3))
    }

    func testCropAndDimensionsArePreserved() throws {
        let source = try makeBuffer(width: 16, height: 9) { x, _ in UInt32(x) }

        let reflected = try XCTUnwrap(mirror.mirroredHorizontally(source))

        XCTAssertEqual(CVPixelBufferGetWidth(reflected), 16)
        XCTAssertEqual(CVPixelBufferGetHeight(reflected), 9)
        XCTAssertEqual(CVPixelBufferGetPixelFormatType(reflected), kCVPixelFormatType_32BGRA)
    }

    func testUnsupportedPixelFormatIsRejectedRatherThanPublishedWrong() throws {
        let source = try makeBuffer(width: 4, height: 2, format: kCVPixelFormatType_32ARGB) { x, _ in UInt32(x) }

        XCTAssertNil(mirror.mirroredHorizontally(source))
    }

    func testTheMVPPublishesTheMirroredOrientation() {
        XCTAssertEqual(VirtualCameraOrientation.published, .mirrored)
        XCTAssertTrue(VirtualCameraOrientation.mirrored.requiresHorizontalReflection)
        XCTAssertFalse(VirtualCameraOrientation.unmirrored.requiresHorizontalReflection)
        XCTAssertTrue(VirtualCameraOrientation.mirrored.isOfferedInMVP)
        XCTAssertFalse(VirtualCameraOrientation.unmirrored.isOfferedInMVP, "the MVP offers only the mirrored publish")
        XCTAssertEqual(VirtualCameraOrientation.mirrored.controlTitle, "Mandar a la call la vista espejo")
    }

    // MARK: - Helpers

    private func makeBuffer(
        width: Int,
        height: Int,
        format: OSType = kCVPixelFormatType_32BGRA,
        value: (Int, Int) -> UInt32
    ) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let attributes: NSDictionary = [kCVPixelBufferIOSurfacePropertiesKey: [:] as NSDictionary]
        XCTAssertEqual(
            CVPixelBufferCreate(kCFAllocatorDefault, width, height, format, attributes, &buffer),
            kCVReturnSuccess
        )
        let pixelBuffer = try XCTUnwrap(buffer)

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(pixelBuffer))
        let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        for y in 0..<height {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt32.self)
            for x in 0..<width { row[x] = value(x, y) }
        }
        return pixelBuffer
    }

    private func pixels(of buffer: CVPixelBuffer, width: Int, height: Int) throws -> [[UInt32]] {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(buffer))
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        return (0..<height).map { y in
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt32.self)
            return (0..<width).map { row[$0] }
        }
    }
}
