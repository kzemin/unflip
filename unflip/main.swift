import AppKit

// Explicit entry point instead of `@main`: `NSApplicationMain` only connects the
// delegate through a MainMenu nib, and unflip deliberately ships no nib, no
// storyboard, and no window.
let application = NSApplication.shared
let delegate = UnflipAppDelegate()
application.delegate = delegate
application.run()
