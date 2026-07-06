import AppKit

final class CaptureService {
    private let store: ScreenshotStore

    init(store: ScreenshotStore) {
        self.store = store
    }

    func captureFullScreen() {
        run(flags: [])
    }

    /// 지연 후 전체 화면 캡처 (메뉴 열림 등 순간 포착용)
    func captureFullScreen(afterSeconds seconds: Int) {
        run(flags: ["-T", "\(seconds)"])
    }

    /// 영역/창 대화형 캡처(애플 screencapture -i, 드래그=영역·스페이스=창) → 프리뷰로.
    /// 항상 임시 파일로 찍고 메모리 이미지만 넘긴다(보관은 프리뷰가 결정, keep이면 saveToStack이 설정 위치에 새로 저장).
    func captureRegionForPreview(completion: @escaping (NSImage) -> Void) {
        let ext = AppSettings.shared.imageFormat.rawValue
        let url = ScreenshotStore.directory.appendingPathComponent("preview-\(UUID().uuidString).\(ext)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-t", ext, url.path]
        process.terminationHandler = { _ in
            DispatchQueue.main.async {
                // ESC로 취소하면 파일이 안 생긴다 — 그 경우 무시
                guard let image = NSImage(contentsOf: url) else { return }
                try? FileManager.default.removeItem(at: url) // 메모리로 로드했으니 임시 파일 삭제
                completion(image)
            }
        }
        try? process.run()
    }

    /// 프리뷰에서 keep한 이미지를 설정 폴더·포맷으로 저장하고 스택에 추가.
    func saveToStack(_ image: NSImage) {
        let url = captureURL()
        let type: NSBitmapImageRep.FileType = AppSettings.shared.imageFormat == .jpg ? .jpeg : .png
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: type, properties: [:]) else { return }
        try? data.write(to: url)
        store.add(url: url)
    }

    private func captureURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss.SSS"
        let settings = AppSettings.shared
        let directory = settings.saveDirectory ?? ScreenshotStore.directory
        return directory.appendingPathComponent(
            "Screenshot \(formatter.string(from: Date())).\(settings.imageFormat.rawValue)")
    }

    private func run(flags: [String]) {
        let url = captureURL()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = flags + ["-t", AppSettings.shared.imageFormat.rawValue, url.path]
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
