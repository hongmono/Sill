import AppKit
import Combine

final class ScreenshotStore: ObservableObject {
    struct Screenshot: Identifiable {
        let id = UUID()
        let url: URL
        let image: NSImage
        /// 임시 폴더 소속 = 스택에서 빠질 때 파일도 삭제
        let isManaged: Bool
    }

    @Published var screenshots: [Screenshot] = []

    static let directory: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sill")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    func add(url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            try? FileManager.default.removeItem(at: url) // 로드 불가한 파일은 UI에서 지울 수 없으니 즉시 정리
            return
        }
        let isManaged = url.deletingLastPathComponent().path == Self.directory.path
        screenshots.insert(Screenshot(url: url, image: image, isManaged: isManaged), at: 0)
    }

    func remove(_ shot: Screenshot) {
        if shot.isManaged {
            try? FileManager.default.removeItem(at: shot.url)
        }
        screenshots.removeAll { $0.id == shot.id }
    }

    /// DnD 드롭 완료 후: 스택에서는 즉시 제거, 파일은 수신 앱이 복사할 여유를 두고 삭제
    func removeAfterDrag(_ shot: Screenshot) {
        screenshots.removeAll { $0.id == shot.id }
        guard shot.isManaged else { return }
        // ponytail: 60초 유예 후 삭제 — 느린 수신 앱(업로드 등)이 문제 되면 보존으로 전환
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            try? FileManager.default.removeItem(at: shot.url)
        }
    }

    func copy(_ shot: Screenshot) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([shot.url as NSURL, shot.image])
    }

    func saveAs(_ shot: Screenshot) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = shot.url.lastPathComponent
        NSApp.activate(ignoringOtherApps: true) // accessory 앱이라 패널을 앞으로
        panel.begin { response in
            guard response == .OK, let destination = panel.url else { return }
            try? FileManager.default.removeItem(at: destination) // 패널이 덮어쓰기 확인을 이미 받음
            try? FileManager.default.copyItem(at: shot.url, to: destination)
        }
    }
}
