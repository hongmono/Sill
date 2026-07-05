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
        guard let image = NSImage(contentsOf: url) else { return }
        screenshots.insert(Screenshot(url: url, image: image), at: 0)
        selectedID = screenshots.first?.id // 새 캡처가 곧바로 ⌘C 대상
    }

    func remove(_ shot: Screenshot) {
        try? FileManager.default.removeItem(at: shot.url)
        screenshots.removeAll { $0.id == shot.id }
        if selectedID == shot.id { selectedID = screenshots.first?.id }
    }

    func copySelected() {
        guard let shot = screenshots.first(where: { $0.id == selectedID }) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([shot.url as NSURL, shot.image])
    }
}
