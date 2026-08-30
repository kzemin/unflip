import XCTest

@testable import unflip

final class CameraDeviceDescriptorTests: XCTestCase {

    private let builtIn = CameraDeviceDescriptor(uniqueID: "built-in-1", localizedName: "FaceTime HD Camera", category: .builtIn)
    private let continuity = CameraDeviceDescriptor(uniqueID: "continuity-1", localizedName: "iPhone de Facundo", category: .continuity)
    private let externalA = CameraDeviceDescriptor(uniqueID: "usb-1", localizedName: "Aluratek HD", category: .external)
    private let externalB = CameraDeviceDescriptor(uniqueID: "usb-2", localizedName: "Zoom Q2n", category: .external)

    func testOrderingIsBuiltInThenContinuityThenExternal() {
        let ordered = CameraDeviceDescriptor.presentable([externalB, continuity, externalA, builtIn])
        XCTAssertEqual(ordered.map(\.uniqueID), ["built-in-1", "continuity-1", "usb-1", "usb-2"])
    }

    func testExternalCamerasAreOrderedByLocalizedName() {
        let ordered = CameraDeviceDescriptor.presentable([externalB, externalA])
        XCTAssertEqual(ordered.map(\.localizedName), ["Aluratek HD", "Zoom Q2n"])
    }

    func testLocalizedNameIsNeverReplacedByACategoryLabel() {
        let ordered = CameraDeviceDescriptor.presentable([externalA])
        XCTAssertEqual(ordered.first?.localizedName, "Aluratek HD")
    }

    func testReservedVirtualCameraIsExcludedSoUnflipCannotCaptureItself() {
        let virtualCamera = CameraDeviceDescriptor(
            uniqueID: UnflipConfiguration.reservedVirtualCameraDeviceID,
            localizedName: "unflip",
            category: .other
        )
        XCTAssertTrue(virtualCamera.isReservedVirtualCamera)
        XCTAssertEqual(CameraDeviceDescriptor.presentable([builtIn, virtualCamera]).map(\.uniqueID), ["built-in-1"])
    }

    func testReservedVirtualCameraMatchIgnoresCaseAndSuffixes() {
        let lowercased = CameraDeviceDescriptor(
            uniqueID: UnflipConfiguration.reservedVirtualCameraDeviceID.lowercased() + ":0",
            localizedName: "unflip",
            category: .other
        )
        XCTAssertTrue(lowercased.isReservedVirtualCamera)
        XCTAssertFalse(builtIn.isReservedVirtualCamera)
    }

    func testSelectionIsPreservedWhenTheCameraIsStillConnected() {
        let selection = CameraDeviceDescriptor.selection(preferring: "usb-1", from: [builtIn, externalA])
        XCTAssertEqual(selection, "usb-1")
    }

    func testSelectionFallsBackToBuiltInThenContinuityThenExternal() {
        XCTAssertEqual(CameraDeviceDescriptor.selection(preferring: "gone", from: [externalA, continuity, builtIn]), "built-in-1")
        XCTAssertEqual(CameraDeviceDescriptor.selection(preferring: "gone", from: [externalA, continuity]), "continuity-1")
        XCTAssertEqual(CameraDeviceDescriptor.selection(preferring: "gone", from: [externalA]), "usb-1")
    }

    func testSelectionIsNilWhenNoCameraIsConnected() {
        XCTAssertNil(CameraDeviceDescriptor.selection(preferring: "usb-1", from: []))
    }
}
