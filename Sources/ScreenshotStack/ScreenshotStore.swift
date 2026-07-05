import AppKit
import Combine

final class ScreenshotStore: ObservableObject {
    struct Screenshot: Identifiable {
        let id = UUID()
        let url: URL
        let image: NSImage
    }

    @Published var screenshots: [Screenshot] = []
    @Published var selectedID: UUID?

    static let directory: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScreenshotStack")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    func add(url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            try? FileManager.default.removeItem(at: url) // 로드 불가한 파일은 UI에서 지울 수 없으니 즉시 정리
            return
        }
        screenshots.insert(Screenshot(url: url, image: image), at: 0)
        selectedID = screenshots.first?.id // 새 캡처가 곧바로 ⌘C 대상
    }

    func remove(_ shot: Screenshot) {
        try? FileManager.default.removeItem(at: shot.url)
        screenshots.removeAll { $0.id == shot.id }
        if selectedID == shot.id { selectedID = screenshots.first?.id }
    }

    /// DnD 드롭 완료 후: 스택에서는 즉시 제거, 파일은 수신 앱이 복사할 여유를 두고 삭제
    func removeAfterDrag(_ shot: Screenshot) {
        screenshots.removeAll { $0.id == shot.id }
        if selectedID == shot.id { selectedID = screenshots.first?.id }
        // ponytail: 60초 유예 후 삭제 — 느린 수신 앱(업로드 등)이 문제 되면 보존으로 전환
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            try? FileManager.default.removeItem(at: shot.url)
        }
    }

    func copySelected() {
        guard let shot = screenshots.first(where: { $0.id == selectedID }) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([shot.url as NSURL, shot.image])
    }
}
