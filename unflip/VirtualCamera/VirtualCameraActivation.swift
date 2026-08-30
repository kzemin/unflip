import AVFoundation
import Foundation
import SystemExtensions

/// Every state the install can be in, including the ones people actually hit.
/// `installed` and `active` are separate on purpose: the system reporting a
/// completed request is not the same as call apps being able to see `unflip`.
enum VirtualCameraActivationState: Equatable {
    case notInstalled
    case submitted
    case replacing
    case needsUserApproval
    case needsRestart
    case installed
    case active
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .submitted, .replacing, .needsUserApproval: return true
        default: return false
        }
    }

    var statusText: String {
        switch self {
        case .notInstalled: return UnflipConfiguration.Copy.virtualCameraOff
        case .submitted: return UnflipConfiguration.Copy.virtualCameraInstalling
        case .replacing: return UnflipConfiguration.Copy.virtualCameraUpdating
        case .needsUserApproval: return UnflipConfiguration.Copy.virtualCameraNeedsApproval
        case .needsRestart: return UnflipConfiguration.Copy.virtualCameraNeedsRestart
        case .installed: return UnflipConfiguration.Copy.virtualCameraInstalledNotVisible
        case .active: return UnflipConfiguration.Copy.virtualCameraOn
        case .failed(let reason): return reason
        }
    }
}

/// Drives `OSSystemExtensionManager` for the embedded `unflipCamera` extension.
/// Activation is always an explicit user action — nothing here runs on launch.
@MainActor
final class VirtualCameraActivation: NSObject, ObservableObject, OSSystemExtensionRequestDelegate {

    @Published private(set) var state: VirtualCameraActivationState = .notInstalled

    private let extensionIdentifier: String
    private let bundleLocation: URL
    private let submit: (OSSystemExtensionRequest) -> Void
    private let deviceIsPublished: () -> Bool

    init(
        extensionIdentifier: String = UnflipConfiguration.extensionBundleIdentifier,
        bundleLocation: URL = Bundle.main.bundleURL,
        submit: @escaping (OSSystemExtensionRequest) -> Void = { OSSystemExtensionManager.shared.submitRequest($0) },
        deviceIsPublished: @escaping () -> Bool = VirtualCameraActivation.extensionDeviceIsPublished
    ) {
        self.extensionIdentifier = extensionIdentifier
        self.bundleLocation = bundleLocation
        self.submit = submit
        self.deviceIsPublished = deviceIsPublished
        super.init()
    }

    /// macOS refuses to install a system extension embedded in an app running
    /// from anywhere else, and the failure is otherwise cryptic.
    var canInstallFromCurrentLocation: Bool {
        bundleLocation.path.hasPrefix("/Applications/")
    }

    func activate() {
        guard canInstallFromCurrentLocation else {
            state = .failed(UnflipConfiguration.Copy.virtualCameraNeedsApplicationsFolder)
            return
        }
        guard !state.isBusy else { return }

        state = .submitted
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: extensionIdentifier,
            queue: .main
        )
        request.delegate = self
        submit(request)
    }

    /// Event-driven promotion from `installed` to `active`. Called when the
    /// popover opens, never on a timer.
    func refresh() {
        switch state {
        case .installed, .notInstalled:
            if deviceIsPublished() { state = .active }
        case .active:
            if !deviceIsPublished() { state = .installed }
        default:
            break
        }
    }

    static func extensionDeviceIsPublished() -> Bool {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external, .continuityCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices.contains {
            $0.uniqueID.range(of: UnflipConfiguration.reservedVirtualCameraDeviceID, options: .caseInsensitive) != nil
        }
    }

    // MARK: - OSSystemExtensionRequestDelegate

    nonisolated func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension replacement: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        Task { @MainActor in self.markReplacing() }
        return .replace
    }

    nonisolated func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        Task { @MainActor in self.markNeedsUserApproval() }
    }

    nonisolated func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        Task { @MainActor in self.finish(with: result) }
    }

    nonisolated func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        Task { @MainActor in self.fail(with: error) }
    }

    // MARK: - Main-actor state transitions

    func markReplacing() { state = .replacing }

    func markNeedsUserApproval() { state = .needsUserApproval }

    func finish(with result: OSSystemExtensionRequest.Result) {
        switch result {
        case .willCompleteAfterReboot:
            state = .needsRestart
        default:
            // Do not claim `active` until a call app could actually find it.
            state = deviceIsPublished() ? .active : .installed
        }
    }

    func fail(with error: Error) {
        if let error = error as? OSSystemExtensionError, error.code == .requestCanceled {
            state = .notInstalled
            return
        }
        state = .failed(UnflipConfiguration.Copy.virtualCameraFailed(error.localizedDescription))
    }
}
