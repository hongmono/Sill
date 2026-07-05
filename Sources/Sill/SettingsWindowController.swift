import AppKit
import SwiftUI

final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let win = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.title = "Sill 설정"
            win.contentView = NSHostingView(rootView: SettingsView(settings: .shared))
            win.isReleasedWhenClosed = false
            win.center()
            window = win
        }
        NSApp.activate(ignoringOtherApps: true) // accessory 앱이라 명시적으로 앞으로
        window?.makeKeyAndOrderFront(nil)
    }
}
