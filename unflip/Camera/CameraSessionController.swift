import AVFoundation
import Foundation

enum CameraPermission: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

enum CaptureStatus: Equatable {
    case idle
    case running
    case failed
}

/// Capture runs while *any* consumer needs frames. Plan 002 only ever sets
/// `preview`; Plan 003 sets `virtualCamera` from the extension's client count
/// without touching the rest of the lifecycle.
struct CaptureDemand: Equatable {
    var preview = false
    var virtualCamera = false

    var isActive: Bool { preview || virtualCamera }
}

// MARK: - Injectable collaborators

protocol CameraAuthorizing: AnyObject {
    func currentStatus() -> CameraPermission
    func requestAccess() async -> Bool
}

protocol CameraDiscovering: AnyObject {
    var onDevicesChanged: (() -> Void)? { get set }
    func availableCameras() -> [CameraDeviceDescriptor]
}

protocol CaptureEngine: AnyObject {
    /// `nil` for the fake engine used by hardware-free tests.
    var previewSession: AVCaptureSession? { get }
    var isRunning: Bool { get }
    func select(deviceUniqueID: String?) async throws
    func start()
    func stop()
}

// MARK: - Controller

@MainActor
final class CameraSessionController: ObservableObject {

    @Published private(set) var permission: CameraPermission = .notDetermined
    @Published private(set) var devices: [CameraDeviceDescriptor] = []
    @Published private(set) var selectedDeviceID: String?
    @Published private(set) var status: CaptureStatus = .idle
    @Published private(set) var message: String?

    private(set) var demand = CaptureDemand()

    private let authorizer: CameraAuthorizing
    private let discovery: CameraDiscovering
    private let engine: CaptureEngine

    /// One prompt per launch, whatever the user does with the popover.
    private var hasRequestedAccess = false

    /// The last camera the engine actually accepted, so a failed switch can fall
    /// back to a configuration that is known to work.
    private var lastGoodDeviceID: String?

    var previewSession: AVCaptureSession? { engine.previewSession }

    init(authorizer: CameraAuthorizing, discovery: CameraDiscovering, engine: CaptureEngine) {
        self.authorizer = authorizer
        self.discovery = discovery
        self.engine = engine
        self.discovery.onDevicesChanged = { [weak self] in
            Task { @MainActor in await self?.reconcile() }
        }
    }

    // MARK: Demand

    @discardableResult
    func setPreviewDemand(_ active: Bool) -> Task<Void, Never> {
        demand.preview = active
        return Task { @MainActor in await self.reconcile() }
    }

    @discardableResult
    func setVirtualCameraDemand(_ active: Bool) -> Task<Void, Never> {
        demand.virtualCamera = active
        return Task { @MainActor in await self.reconcile() }
    }

    @discardableResult
    func select(deviceUniqueID: String) -> Task<Void, Never> {
        selectedDeviceID = deviceUniqueID
        return Task { @MainActor in await self.reconcile() }
    }

    /// Called on quit. Drops every demand so capture is torn down before the
    /// process exits and the camera indicator never lingers.
    func tearDown() {
        demand = CaptureDemand()
        engine.stop()
        status = .idle
    }

    // MARK: Reconciliation

    private func reconcile() async {
        guard demand.isActive else {
            stopCapture()
            return
        }

        permission = authorizer.currentStatus()

        if permission == .notDetermined, !hasRequestedAccess {
            hasRequestedAccess = true
            _ = await authorizer.requestAccess()
            permission = authorizer.currentStatus()
        }

        guard permission == .authorized else {
            stopCapture()
            message = permission == .restricted
                ? UnflipConfiguration.Copy.permissionRestricted
                : UnflipConfiguration.Copy.permissionDenied
            return
        }

        devices = CameraDeviceDescriptor.presentable(discovery.availableCameras())
        guard !devices.isEmpty else {
            stopCapture()
            message = UnflipConfiguration.Copy.noCameras
            return
        }

        let wanted = CameraDeviceDescriptor.selection(preferring: selectedDeviceID, from: devices)
        do {
            try await engine.select(deviceUniqueID: wanted)
            selectedDeviceID = wanted
            lastGoodDeviceID = wanted
            message = nil
        } catch {
            // The engine keeps the last good input, so point the UI back at the
            // camera that is really feeding the previews.
            selectedDeviceID = lastGoodDeviceID
            status = lastGoodDeviceID == nil ? .failed : .running
            message = UnflipConfiguration.Copy.captureFailed
            return
        }

        if !engine.isRunning { engine.start() }
        status = .running
    }

    private func stopCapture() {
        if engine.isRunning { engine.stop() }
        status = .idle
        message = nil
    }
}
