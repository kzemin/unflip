import AppKit
import SwiftUI

/// Owns the one status item and the one popover. AppKit rather than a SwiftUI
/// `MenuBarExtra` because Plan 002 needs precise open/close callbacks to start
/// and stop capture, and a right-click menu.
final class UnflipMenuBarController: NSObject, NSPopoverDelegate {

    private let statusItem: NSStatusItem
    private let popover = NSPopover()

    override init() {
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
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: UnflipPopoverView())
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

    private func showPopover() {
        guard let button = statusItem.button else { return }
        // An accessory app is not active when its status item is clicked, and a
        // transient popover closes as soon as it loses key. Activate first.
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(
            withTitle: UnflipConfiguration.Copy.quit,
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
}
