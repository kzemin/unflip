import AVFoundation
import Foundation

/// Real AVFoundation implementations of the collaborators
/// `CameraSessionController` drives. Everything here touches hardware, so the
/// unit tests use fakes instead and none of this runs during `xcodebuild test`.

enum CaptureEngineError: Error {
    case cannotUseDevice
}

final class SystemCameraAuthorizer: CameraAuthorizing {

    func currentStatus() -> CameraPermission {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        default: return .notDetermined
        }
    }

    func requestAccess() async -> Bool {
        // Video only. unflip never asks for the microphone.
        await AVCaptureDevice.requestAccess(for: .video)
    }
}

final class SystemCameraDiscovery: CameraDiscovering {

    var onDevicesChanged: (() -> Void)?

    private let discoverySession = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera, .continuityCamera, .external],
        mediaType: .video,
        position: .unspecified
    )

    private var observers: [NSObjectProtocol] = []

    init() {
        // ponytail: hot-plug notifications rather than KVO on `devices`; two
        // lines, documented, and enough for a picker that re-reads on change.
        let center = NotificationCenter.default
        for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            observers.append(
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    self?.onDevicesChanged?()
                }
            )
        }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func availableCameras() -> [CameraDeviceDescriptor] {
        CameraDeviceDescriptor.presentable(discoverySession.devices.map(CameraDeviceDescriptor.init(device:)))
    }
}

final class AVFoundationCaptureEngine: CaptureEngine {

    private let session = AVCaptureSession()
    /// Every session mutation and every start/stop happens here, never on the
    /// main actor.
    private let queue = DispatchQueue(label: "io.unflip.capture", qos: .userInitiated)
    private var currentInput: AVCaptureDeviceInput?

    var previewSession: AVCaptureSession? { session }

    /// `isRunning` is safe to read from any thread.
    var isRunning: Bool { session.isRunning }

    func select(deviceUniqueID: String?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                do {
                    try applySelection(deviceUniqueID)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func start() {
        queue.async { [self] in
            guard !session.isRunning, currentInput != nil else { return }
            session.startRunning()
        }
    }

    func stop() {
        queue.async { [self] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    // MARK: - Session queue only

    private func applySelection(_ uniqueID: String?) throws {
        dispatchPrecondition(condition: .onQueue(queue))

        guard uniqueID != currentInput?.device.uniqueID else { return }

        guard let uniqueID, let device = AVCaptureDevice(uniqueID: uniqueID) else {
            removeCurrentInput()
            return
        }

        let replacement: AVCaptureDeviceInput
        do {
            replacement = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CaptureEngineError.cannotUseDevice
        }

        let previous = currentInput
        session.beginConfiguration()
        if let previous { session.removeInput(previous) }

        if session.canAddInput(replacement) {
            session.addInput(replacement)
            currentInput = replacement
            session.commitConfiguration()
            return
        }

        // Restore the last known-good input rather than leaving a dead session.
        if let previous, session.canAddInput(previous) {
            session.addInput(previous)
        } else {
            currentInput = nil
        }
        session.commitConfiguration()
        throw CaptureEngineError.cannotUseDevice
    }

    private func removeCurrentInput() {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let currentInput else { return }
        session.beginConfiguration()
        session.removeInput(currentInput)
        session.commitConfiguration()
        self.currentInput = nil
        if session.isRunning { session.stopRunning() }
    }
}
