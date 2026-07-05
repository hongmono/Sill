import AppKit

final class CaptureService {
    private let store: ScreenshotStore

    init(store: ScreenshotStore) {
        self.store = store
    }

    /// 대화형 캡처. screencapture -i는 드래그=영역, 스페이스바=창 캡처를 자체 지원한다.
    func captureInteractive() {
        run(flags: ["-i"])
    }

    func captureFullScreen() {
        run(flags: [])
    }

    private func run(flags: [String]) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss.SSS"
        let url = ScreenshotStore.directory
            .appendingPathComponent("Screenshot \(formatter.string(from: Date())).png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = flags + [url.path]
        process.terminationHandler = { [weak store] _ in
            DispatchQueue.main.async {
                // ESC로 취소하면 파일이 안 생긴다 — 그 경우 무시
                if FileManager.default.fileExists(atPath: url.path) {
                    store?.add(url: url)
                }
            }
        }
        try? process.run()
    }
}
