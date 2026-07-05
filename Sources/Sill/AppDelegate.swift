import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ScreenshotStore()
    private lazy var capture = CaptureService(store: store)
    private var statusItem: NSStatusItem!
    private var panelController: StackPanelController!
    private let hotkeys = HotkeyManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController = StackPanelController(store: store)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "camera.viewfinder",
            accessibilityDescription: "Sill"
        )
        let menu = NSMenu()
        menu.addItem(withTitle: "영역/창 캡처 (⇧⌘4)", action: #selector(captureInteractive), keyEquivalent: "")
        menu.addItem(withTitle: "전체 화면 캡처 (⇧⌘3)", action: #selector(captureFullScreen), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        // 시스템 기본 스크린샷 단축키(⇧⌘4/⇧⌘3)를 이 앱이 가로챈다 (Shottr/CleanShot 방식)
        hotkeys.register(
            keyCode: UInt32(kVK_ANSI_4),
            modifiers: UInt32(cmdKey | shiftKey),
            id: 1
        ) { [weak self] in self?.capture.captureInteractive() }
        hotkeys.register(
            keyCode: UInt32(kVK_ANSI_3),
            modifiers: UInt32(cmdKey | shiftKey),
            id: 2
        ) { [weak self] in self?.capture.captureFullScreen() }
    }

    @objc private func captureInteractive() {
        capture.captureInteractive()
    }

    @objc private func captureFullScreen() {
        capture.captureFullScreen()
    }
}
