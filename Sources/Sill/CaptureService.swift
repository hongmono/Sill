import AppKit

final class CaptureService {
    private let store: ScreenshotStore
    var onTextCaptured: ((NSImage) -> Void)? // 선택 끝날 때 ⌘ 쥐고 있으면 스택 대신 OCR (AppDelegate가 주입)

    init(store: ScreenshotStore) {
        self.store = store
    }

    /// 대화형 캡처. screencapture -i는 드래그=영역, 스페이스바=창 캡처를 자체 지원한다.
    /// 선택 완료(mouseUp) 시 ⌘가 눌려 있으면 스택 대신 바로 OCR로 보낸다.
    func captureInteractive() {
        run(flags: ["-i"], detectCommand: true)
    }

    func captureFullScreen() {
        run(flags: [])
    }

    /// 지연 후 전체 화면 캡처 (메뉴 열림 등 순간 포착용)
    func captureFullScreen(afterSeconds seconds: Int) {
        run(flags: ["-T", "\(seconds)"])
    }

    private func run(flags: [String], detectCommand: Bool = false) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss.SSS"
        let settings = AppSettings.shared
        let directory = settings.saveDirectory ?? ScreenshotStore.directory
        let ext = settings.imageFormat.rawValue
        let url = directory
            .appendingPathComponent("Screenshot \(formatter.string(from: Date())).\(ext)")

        // 캡처 내내 ⌘이 계속 눌려 있었는지 샘플링 → 종료 타이밍에 흔들리지 않게. screencapture가 이벤트를
        // 가로채 전역 모니터로는 못 잡으니 하드웨어 상태를 폴링한다. ⇧⌘4로 시작해 ⌘ 유지=OCR, 중간에 떼면=스택.
        var sampled = false           // 타이머가 한 번이라도 돌았는지 — 안 돌면 안전하게 스택
        var cmdHeldThroughout = true
        var pollTimer: Timer?
        if detectCommand {
            pollTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
                sampled = true
                if !NSEvent.modifierFlags.contains(.command) { cmdHeldThroughout = false }
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = flags + ["-t", ext, url.path]
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                pollTimer?.invalidate()
                // ESC로 취소하면 파일이 안 생긴다 — 그 경우 무시
                guard FileManager.default.fileExists(atPath: url.path) else { return }
                if detectCommand, sampled, cmdHeldThroughout, let image = NSImage(contentsOf: url) {
                    self?.onTextCaptured?(image)
                    try? FileManager.default.removeItem(at: url) // OCR 캡처는 저장 안 함
                } else {
                    self?.store.add(url: url)
                }
            }
        }
        try? process.run()
    }
}
