import AVFoundation
import XCTest

@testable import unflip

@MainActor
final class CameraSessionControllerTests: XCTestCase {

    private let builtIn = CameraDeviceDescriptor(uniqueID: "built-in-1", localizedName: "FaceTime HD Camera", category: .builtIn)
    private let external = CameraDeviceDescriptor(uniqueID: "usb-1", localizedName: "Aluratek HD", category: .external)

    private func makeController(
        permission: CameraPermission = .authorized,
        cameras: [CameraDeviceDescriptor]? = nil
    ) -> (CameraSessionController, FakeAuthorizer, FakeDiscovery, FakeEngine) {
        let authorizer = FakeAuthorizer(status: permission)
        let discovery = FakeDiscovery(cameras: cameras ?? [builtIn])
        let engine = FakeEngine()
        let controller = CameraSessionController(authorizer: authorizer, discovery: discovery, engine: engine)
        return (controller, authorizer, discovery, engine)
    }

    // MARK: - Demand truth table

    func testNoDemandLeavesCaptureIdle() async {
        let (controller, _, _, engine) = makeController()
        await controller.setPreviewDemand(false).value

        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(engine.startCount, 0)
        XCTAssertEqual(controller.status, .idle)
    }

    func testPreviewDemandAloneRunsCapture() async {
        let (controller, _, _, engine) = makeController()
        await controller.setPreviewDemand(true).value

        XCTAssertTrue(engine.isRunning)
        XCTAssertEqual(controller.status, .running)
    }

    func testVirtualCameraDemandAloneRunsCapture() async {
        let (controller, _, _, engine) = makeController()
        await controller.setVirtualCameraDemand(true).value

        XCTAssertTrue(engine.isRunning)
        XCTAssertEqual(controller.status, .running)
    }

    func testCaptureStopsOnlyWhenBothDemandsAreGone() async {
        let (controller, _, _, engine) = makeController()

        await controller.setPreviewDemand(true).value
        await controller.setVirtualCameraDemand(true).value
        XCTAssertTrue(engine.isRunning)

        // Popover closed, but a call app is still consuming the virtual camera.
        await controller.setPreviewDemand(false).value
        XCTAssertTrue(engine.isRunning, "capture must survive a popover close while a consumer is attached")

        await controller.setVirtualCameraDemand(false).value
        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(controller.status, .idle)
    }

    // MARK: - Idempotency

    func testRepeatedOpenAndCloseDoesNotDoubleStartOrStop() async {
        let (controller, _, _, engine) = makeController()

        for _ in 0..<3 { await controller.setPreviewDemand(true).value }
        XCTAssertEqual(engine.startCount, 1)

        for _ in 0..<3 { await controller.setPreviewDemand(false).value }
        XCTAssertEqual(engine.stopCount, 1)

        await controller.setPreviewDemand(true).value
        XCTAssertEqual(engine.startCount, 2, "reopening starts capture again")
    }

    // MARK: - Permission

    func testDeniedPermissionNeverStartsCapture() async {
        let (controller, _, _, engine) = makeController(permission: .denied)
        await controller.setPreviewDemand(true).value

        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(engine.startCount, 0)
        XCTAssertEqual(controller.permission, .denied)
        XCTAssertEqual(controller.message, UnflipConfiguration.Copy.permissionDenied)
    }

    func testRestrictedPermissionHasItsOwnMessage() async {
        let (controller, _, _, _) = makeController(permission: .restricted)
        await controller.setPreviewDemand(true).value

        XCTAssertEqual(controller.message, UnflipConfiguration.Copy.permissionRestricted)
    }

    func testAccessIsRequestedOnceEvenAcrossManyOpens() async {
        let (controller, authorizer, _, _) = makeController(permission: .notDetermined)
        authorizer.statusAfterRequest = .denied

        await controller.setPreviewDemand(true).value
        await controller.setPreviewDemand(false).value
        await controller.setPreviewDemand(true).value

        XCTAssertEqual(authorizer.requestCount, 1, "unflip must not re-prompt on every popover open")
    }

    func testGrantedAccessStartsCaptureWithoutAsecondPrompt() async {
        let (controller, authorizer, _, engine) = makeController(permission: .notDetermined)
        authorizer.statusAfterRequest = .authorized

        await controller.setPreviewDemand(true).value

        XCTAssertEqual(authorizer.requestCount, 1)
        XCTAssertTrue(engine.isRunning)
    }

    // MARK: - Devices

    func testNoCamerasReportsItAndStaysIdle() async {
        let (controller, _, _, engine) = makeController(cameras: [])
        await controller.setPreviewDemand(true).value

        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(controller.message, UnflipConfiguration.Copy.noCameras)
    }

    func testFirstOpenSelectsTheBuiltInCamera() async {
        let (controller, _, _, engine) = makeController(cameras: [external, builtIn])
        await controller.setPreviewDemand(true).value

        XCTAssertEqual(controller.selectedDeviceID, "built-in-1")
        XCTAssertEqual(engine.selected, ["built-in-1"])
    }

    func testFailedSwitchKeepsTheLastGoodCamera() async {
        let (controller, _, _, engine) = makeController(cameras: [builtIn, external])
        await controller.setPreviewDemand(true).value
        XCTAssertEqual(controller.selectedDeviceID, "built-in-1")

        engine.selectError = CaptureEngineError.cannotUseDevice
        await controller.select(deviceUniqueID: "usb-1").value

        XCTAssertEqual(controller.selectedDeviceID, "built-in-1", "the picker must show what is really feeding the previews")
        XCTAssertEqual(controller.message, UnflipConfiguration.Copy.captureFailed)
    }

    func testDisconnectingTheSelectedCameraFallsBack() async {
        let (controller, _, discovery, _) = makeController(cameras: [builtIn, external])
        await controller.select(deviceUniqueID: "usb-1").value
        await controller.setPreviewDemand(true).value
        XCTAssertEqual(controller.selectedDeviceID, "usb-1")

        discovery.cameras = [builtIn]
        await controller.setPreviewDemand(true).value

        XCTAssertEqual(controller.selectedDeviceID, "built-in-1")
    }

    // MARK: - Teardown

    func testTearDownDropsEveryDemandAndStopsCapture() async {
        let (controller, _, _, engine) = makeController()
        await controller.setPreviewDemand(true).value
        await controller.setVirtualCameraDemand(true).value

        controller.tearDown()

        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(controller.status, .idle)
        XCTAssertFalse(controller.demand.isActive)
    }
}

// MARK: - Hardware-free fakes

final class FakeAuthorizer: CameraAuthorizing {
    var status: CameraPermission
    var statusAfterRequest: CameraPermission?
    private(set) var requestCount = 0

    init(status: CameraPermission) { self.status = status }

    func currentStatus() -> CameraPermission { status }

    func requestAccess() async -> Bool {
        requestCount += 1
        if let statusAfterRequest { status = statusAfterRequest }
        return status == .authorized
    }
}

final class FakeDiscovery: CameraDiscovering {
    var onDevicesChanged: (() -> Void)?
    var cameras: [CameraDeviceDescriptor]

    init(cameras: [CameraDeviceDescriptor]) { self.cameras = cameras }

    func availableCameras() -> [CameraDeviceDescriptor] { cameras }
}

final class FakeEngine: CaptureEngine {
    var previewSession: AVCaptureSession? { nil }
    private(set) var isRunning = false
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var selected: [String?] = []
    var selectError: Error?

    func select(deviceUniqueID: String?) async throws {
        if let selectError {
            self.selectError = nil
            throw selectError
        }
        selected.append(deviceUniqueID)
    }

    func start() {
        startCount += 1
        isRunning = true
    }

    func stop() {
        stopCount += 1
        isRunning = false
    }
}
