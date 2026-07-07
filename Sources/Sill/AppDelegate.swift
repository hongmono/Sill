import AppKit
import Carbon.HIToolbox
import Combine
import Sparkle

// Swift 6(strict concurrency) 전환 시: Carbon 콜백과 AppSettings 격리 재검토 필요
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ScreenshotStore()
    private lazy var capture = CaptureService(store: store)
    private var statusItem: NSStatusItem!
    private var panelController: StackPanelController!
    private let ocrOverlay = OCROverlayController()
    private let preview = CapturePreviewController()
    private let hotkeys = HotkeyManager()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )
    private let settingsWindow = SettingsWindowController()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        TranslationSelfCheck.run() // 엔드포인트·방향 순수 로직 self-check
        #endif
        installMainMenu() // 없으면 텍스트 필드에서 ⌘V/⌘X/⌘A가 안 먹음 (accessory 앱엔 기본 메뉴바 없음)
        panelController = StackPanelController(store: store) { [weak self] shot in
            TextRecognizer.recognize(shot.image) { self?.ocrOverlay.show(text: $0) } // 인식은 메모리 이미지로
            self?.store.remove(shot) // 텍스트 추출 = 소비 → 스택에서 제거 (관리 파일이면 삭제, 사용자 폴더 파일은 보존)
        }
        // 프리뷰: Enter=스택(fly 애니메이션), OCR키=텍스트 추출, ESC=버리기
        preview.onKeep = { [weak self] image in self?.capture.saveToStack(image) }
        preview.onOCR = { [weak self] image in
            TextRecognizer.recognize(image) { self?.ocrOverlay.show(text: $0) }
        }
        preview.stackTargetProvider = { [weak self] in self?.panelController.nextThumbnailFrame() ?? .zero }
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
        // 메뉴바 아이콘 표시 여부를 설정에 연동 (숨겨도 재실행 시 설정창으로 복귀 가능)
        let settings = AppSettings.shared
        statusItem.isVisible = settings.showMenuBarIcon
        settings.$showMenuBarIcon
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.statusItem.isVisible = $0 }
            .store(in: &cancellables)
        // 시스템 기본 스크린샷 단축키(⇧⌘4/⇧⌘3)를 이 앱이 가로챈다 (Shottr/CleanShot 방식)
        let interactiveStatus = hotkeys.register(
            keyCode: UInt32(kVK_ANSI_4),
            modifiers: UInt32(cmdKey | shiftKey),
            id: 1
        ) { [weak self] in self?.startRegionCapture() }
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

    /// accessory 앱은 기본 메뉴바가 없어 텍스트 필드 표준 편집(붙여넣기 등)이 안 된다 — 최소 메뉴로 라우팅만 연결.
    /// 로컬 이벤트 모니터(프리뷰·OCR 카드)는 sendEvent보다 먼저 실행되므로 카드 단축키는 여기 영향 없이 우선.
    private func installMainMenu() {
        let mainMenu = NSMenu()

        // 첫 서브메뉴는 macOS가 앱 메뉴(굵은 앱 이름)로 표시 — Edit가 그 자리에 오지 않게 앞에 둔다.
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "설정...", action: #selector(openSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Sill 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "편집")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "실행 취소", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "다시 실행", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "잘라내기", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "복사", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "붙여넣기", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "전체 선택", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    @objc private func captureInteractive() {
        startRegionCapture()
    }

    private func startRegionCapture() {
        capture.captureRegionForPreview { [weak self] image in self?.preview.show(image: image) }
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

    /// 이미 실행 중인 Sill을 다시 열려고 하면(Finder 재실행/`open -a`) macOS가 이 reopen을
    /// 기존 인스턴스로 보낸다 — 메뉴바 아이콘을 숨겼을 때도 설정창으로 돌아올 수 있는 경로.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return true
    }
}
