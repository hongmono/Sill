import AppKit
import SwiftUI

/// OCR 결과를 화면 중앙 카드로 표시. ESC=취소, Enter/⌘C=복사 후 닫기.
@MainActor
final class OCROverlayController {
    private let panel: KeyablePanel
    private var keyMonitor: Any?
    private var text = ""

    init() {
        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.borderless], // 모달처럼 키 포커스를 받아야 하므로 nonactivating 제외
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
    }

    func show(text: String) {
        self.text = text
        panel.contentView = NSHostingView(rootView: OCRResultView(text: text))

        // 마우스가 있는 스크린 중앙
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.midY - size.height / 2
            ))
        }

        NSApp.activate(ignoringOtherApps: true) // accessory 앱 — 키 입력 받으려면 활성화
        panel.makeKeyAndOrderFront(nil)
        installMonitor()
    }

    private func installMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case 53: // ESC
                self.close()
                return nil
            case 36, 76: // Return, keypad Enter
                self.copyAndClose()
                return nil
            default:
                if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "c" {
                    self.copyAndClose()
                    return nil
                }
                return event
            }
        }
    }

    private func copyAndClose() {
        if !text.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        close()
    }

    private func close() {
        panel.orderOut(nil)
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }
}

/// borderless 패널은 기본적으로 key가 못 된다 — 키 입력을 받으려면 override 필요.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private struct OCRResultView: View {
    let text: String

    var body: some View {
        VStack(spacing: 12) {
            ScrollView {
                Text(text.isEmpty ? "(인식된 텍스트 없음)" : text)
                    .textSelection(.enabled)
                    .font(.body)
                    .foregroundStyle(text.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("Enter · ⌘C 복사   ·   ESC 닫기")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 480, height: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
