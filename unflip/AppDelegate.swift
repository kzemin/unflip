import AppKit

final class UnflipAppDelegate: NSObject, NSApplicationDelegate {

    private var camera: CameraSessionController?
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
        menuBar = UnflipMenuBarController(camera: camera)
    }

    func applicationWillTerminate(_ notification: Notification) {
        camera?.tearDown()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
