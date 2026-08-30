import AppKit
import SwiftUI

/// Owns the one status item and the one popover. AppKit rather than a SwiftUI
/// `MenuBarExtra` because capture demand needs precise open/close callbacks, and
/// because the status item has a right-click menu.
@MainActor
final class UnflipMenuBarController: NSObject, NSPopoverDelegate {

    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let camera: CameraSessionController

    init(camera: CameraSessionController) {
        self.camera = camera
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "person.crop.rectangle",
                accessibilityDescription: UnflipConfiguration.productName
            )
            button.image?.isTemplate = true
            button.toolTip = UnflipConfiguration.productName
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: UnflipPopoverView(camera: camera))
    }

    @objc private func togglePopover() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    @objc func showPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        // An accessory app is not active when its status item is clicked, and a
        // transient popover closes as soon as it loses key. Activate first.
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let open = NSMenuItem(title: UnflipConfiguration.Copy.menuOpen, action: #selector(showPopover), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        // Enabled by Plan 003, once there is an extension to activate.
        let install = NSMenuItem(title: UnflipConfiguration.Copy.menuInstallExtension, action: nil, keyEquivalent: "")
        install.isEnabled = false
        menu.addItem(install)

        menu.addItem(.separator())
        menu.addItem(
            withTitle: UnflipConfiguration.Copy.quit,
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - Capture demand

    // The popover being open is the only thing that asks for frames in Plan 002.
    // `popoverDidClose` covers every close path: outside click, Escape, and the
    // status-item toggle.

    func popoverWillShow(_ notification: Notification) {
        camera.setPreviewDemand(true)
    }

    func popoverDidClose(_ notification: Notification) {
        camera.setPreviewDemand(false)
    }
}
