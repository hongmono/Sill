import AppKit

/// 캡처 직후 큰 프리뷰를 띄워 사용자가 결정하게 한다.
/// Enter/Space=스택으로(날아가는 애니메이션), OCR키(기본 O)=텍스트 추출, ESC=버리기.
@MainActor
final class CapturePreviewController {
    var onKeep: ((NSImage) -> Void)?
    var onOCR: ((NSImage) -> Void)?
    var stackTargetProvider: (() -> NSRect)?  // fly 애니메이션 목적지(다음 썸네일 위치)

    private var panel: PreviewPanel?
    private var keyMonitor: Any?
    private var image: NSImage?

    func show(image: NSImage) {
        close() // 이전 프리뷰 정리
        self.image = image

        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = fitSize(image.size, maxW: visible.width * 0.7, maxH: visible.height * 0.7)
        let frame = NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                           width: size.width, height: size.height)

        // .nonactivatingPanel: 앱 활성화(비동기·비신뢰)와 무관하게 패널이 즉시 key가 되게 — 로컬 키 모니터가 곧바로 먹힘
        let p = PreviewPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.contentView = makeContent(image: image, size: size)

        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
        panel = p
        installMonitor()
    }

    private func installMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case 53: // ESC → 버리기
                self.close()
                return nil
            case 36, 76, 49: // Return, keypad Enter, Space → 스택으로
                self.keep()
                return nil
            default:
                if self.matchesOCRKey(event) {
                    self.runOCR()
                    return nil
                }
                return event
            }
        }
    }

    private func keep() {
        guard let panel, let image else { close(); return }
        let target = stackTargetProvider?() ?? panel.frame
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil } // 애니 중 키 무시
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.32
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.close()
            self?.onKeep?(image) // 애니 끝 → 스택에 추가(스택 자체 등장 애니로 이어짐)
        })
    }

    private func runOCR() {
        let img = image
        close()
        if let img { onOCR?(img) }
    }

    /// OCR 키 매칭 — 문자(영문)뿐 아니라 물리 키(keyCode)로도 비교해 한글 등 다른 입력 소스에서도 같은 자리 키가 먹힘.
    private func matchesOCRKey(_ event: NSEvent) -> Bool {
        let key = AppSettings.shared.ocrKey.lowercased()
        if event.charactersIgnoringModifiers?.lowercased() == key { return true }
        if let ch = key.first, Self.letterKeyCodes[ch] == event.keyCode { return true }
        return false
    }

    // 물리 키 위치(US-QWERTY ANSI) — 입력 소스와 무관하게 같은 자리 키를 잡기 위한 매핑
    private static let letterKeyCodes: [Character: UInt16] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31, "u": 32,
        "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46
    ]

    private func close() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
        panel?.orderOut(nil)
        panel = nil
        image = nil
    }

    private func fitSize(_ size: NSSize, maxW: CGFloat, maxH: CGFloat) -> NSSize {
        guard size.width > 0, size.height > 0 else { return NSSize(width: 400, height: 300) }
        let scale = min(min(maxW / size.width, maxH / size.height), 2.0) // 큰 건 맞추고, 작은 선택은 최대 2배까지만 확대
        return NSSize(width: size.width * scale, height: size.height * scale)
    }

    private func makeContent(image: NSImage, size: NSSize) -> NSView {
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor

        let imageView = NSImageView(frame: container.bounds)
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]
        container.addSubview(imageView)

        let barH: CGFloat = 28
        let bar = NSView(frame: NSRect(x: 0, y: 0, width: size.width, height: barH))
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
        bar.autoresizingMask = [.width]
        let hint = NSTextField(labelWithString:
            "Enter 저장   ·   \(AppSettings.shared.ocrKey.uppercased()) 텍스트 추출   ·   ESC 버리기")
        hint.font = .systemFont(ofSize: 12, weight: .medium)
        hint.textColor = .white
        hint.alignment = .center
        hint.drawsBackground = false
        hint.sizeToFit()
        hint.frame = NSRect(x: 0, y: (barH - hint.frame.height) / 2, width: size.width, height: hint.frame.height)
        hint.autoresizingMask = [.width]
        bar.addSubview(hint)
        container.addSubview(bar)
        return container
    }
}

private final class PreviewPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
