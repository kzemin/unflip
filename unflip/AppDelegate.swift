import AppKit

final class UnflipAppDelegate: NSObject, NSApplicationDelegate {

    private var camera: CameraSessionController?
    private var activation: VirtualCameraActivation?
    private var menuBar: UnflipMenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Nothing touches the camera at launch: no discovery, no permission
        // prompt, no session. That only happens once the popover opens.
        let camera = CameraSessionController(
            authorizer: SystemCameraAuthorizer(),
            discovery: SystemCameraDiscovery(),
            engine: AVFoundationCaptureEngine()
        )
        self.camera = camera

        // Nothing is activated here either: installing the Camera Extension is
        // always an explicit user action from the menu.
        let activation = VirtualCameraActivation()
        self.activation = activation

        menuBar = UnflipMenuBarController(camera: camera, activation: activation)
    }

    func applicationWillTerminate(_ notification: Notification) {
        camera?.tearDown()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
