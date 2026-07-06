import AppKit
import Carbon.HIToolbox
import Sparkle

// Swift 6(strict concurrency) 전환 시: Carbon 콜백과 AppSettings 격리 재검토 필요
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ScreenshotStore()
    private lazy var capture = CaptureService(store: store)
    private var statusItem: NSStatusItem!
    private var panelController: StackPanelController!
    private let ocrOverlay = OCROverlayController()
    private let hotkeys = HotkeyManager()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )
    private let settingsWindow = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController = StackPanelController(store: store) { [weak self] shot in
            TextRecognizer.recognize(shot.image) { self?.ocrOverlay.show(text: $0) } // 인식은 메모리 이미지로
            self?.store.remove(shot) // 텍스트 추출 = 소비 → 스택에서 제거 (관리 파일이면 삭제, 사용자 폴더 파일은 보존)
        }
        // ⇧⌘4 캡처 시 ⌘ 쥔 채로 선택을 끝내면 스택 대신 바로 OCR
        capture.onTextCaptured = { [weak self] image in
            TextRecognizer.recognize(image) { self?.ocrOverlay.show(text: $0) }
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "camera.viewfinder",
            accessibilityDescription: "Sill"
        )
        let menu = NSMenu()
        menu.addItem(withTitle: "영역/창 캡처 (⇧⌘4)", action: #selector(captureInteractive), keyEquivalent: "")
        menu.addItem(withTitle: "전체 화면 캡처 (⇧⌘3)", action: #selector(captureFullScreen), keyEquivalent: "")
        let timerMenu = NSMenu()
        timerMenu.addItem(withTitle: "3초 후", action: #selector(captureTimer3), keyEquivalent: "")
        timerMenu.addItem(withTitle: "10초 후", action: #selector(captureTimer10), keyEquivalent: "")
        let timerItem = NSMenuItem(title: "타이머 전체 캡처", action: nil, keyEquivalent: "")
        timerItem.submenu = timerMenu
        menu.addItem(timerItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "설정...", action: #selector(openSettings), keyEquivalent: ",")
        let updateItem = NSMenuItem(
            title: "업데이트 확인...",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updateItem.target = updaterController
        menu.addItem(updateItem)
        menu.addItem(withTitle: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        // 시스템 기본 스크린샷 단축키(⇧⌘4/⇧⌘3)를 이 앱이 가로챈다 (Shottr/CleanShot 방식)
        let interactiveStatus = hotkeys.register(
            keyCode: UInt32(kVK_ANSI_4),
            modifiers: UInt32(cmdKey | shiftKey),
            id: 1
        ) { [weak self] in self?.capture.captureInteractive() }
        let fullScreenStatus = hotkeys.register(
            keyCode: UInt32(kVK_ANSI_3),
            modifiers: UInt32(cmdKey | shiftKey),
            id: 2
        ) { [weak self] in self?.capture.captureFullScreen() }
        if interactiveStatus != noErr || fullScreenStatus != noErr {
            let alert = NSAlert()
            alert.messageText = "단축키 등록 실패"
            alert.informativeText = "⇧⌘4/⇧⌘3을 다른 앱이 사용 중입니다. 메뉴바 아이콘의 메뉴로 캡처할 수 있습니다."
            alert.runModal()
        }
    }

    @objc private func captureInteractive() {
        capture.captureInteractive()
    }

    @objc private func captureFullScreen() {
        capture.captureFullScreen()
    }

    @objc private func captureTimer3() {
        capture.captureFullScreen(afterSeconds: 3)
    }

    @objc private func captureTimer10() {
        capture.captureFullScreen(afterSeconds: 10)
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }
}
