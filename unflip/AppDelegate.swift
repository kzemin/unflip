import AppKit

final class UnflipAppDelegate: NSObject, NSApplicationDelegate {

    private var menuBar: UnflipMenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ponytail: LSUIElement already suppresses the Dock tile; nothing to
        // set at runtime. No window, no Settings scene, no main menu work.
        menuBar = UnflipMenuBarController()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
