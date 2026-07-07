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
    private var resignObserver: Any?
    private var image: NSImage?
    private var isDragging = false // 드래그 내보내기 중엔 포커스 상실 자동저장을 억제

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
        p.sharingType = .none // 프리뷰가 다음 스크린샷/녹화에 안 찍히게 (연속 캡처 시)
        p.contentView = makeContent(image: image, size: size)

        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
        panel = p
        installMonitor()
    }

    private func installMonitor() {
        // 다른 앱/창을 클릭해 프리뷰가 key를 잃으면 스택에 보관(Enter와 동일 — 썸네일로 날아감)
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in
            guard let self, !self.isDragging else { return } // 드래그 중 포커스 상실은 무시
            self.keep()
        }
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
        // 애니 중 키·포커스 무시 (완료 시 orderOut이 또 resignKey를 유발하는 재진입도 차단)
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver); self.resignObserver = nil }
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
        // orderOut이 didResignKey를 동기 발생시켜 keep()로 재진입하는 걸 막으려 옵저버부터 제거
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver); self.resignObserver = nil }
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
        let container = PreviewDragView(frame: NSRect(origin: .zero, size: size))
        container.image = image
        container.onDragWillBegin = { [weak self] in self?.isDragging = true }
        container.onDragDidEnd = { [weak self] dropped in
            guard let self else { return }
            self.isDragging = false
            if dropped { self.close() } // 다른 앱으로 내보냈으면 프리뷰 종료(스택엔 안 쌓임)
        }
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
            "끌어서 내보내기   ·   Enter 저장   ·   \(AppSettings.shared.ocrKey.uppercased()) 텍스트 추출   ·   ESC 버리기")
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

/// 프리뷰를 다른 앱으로 바로 끌어 내보내는 드래그 소스. 스택 DragNSView와 같은 방식(파일 URL 드래그)이되,
/// 프리뷰는 아직 저장 전이라 드래그가 시작될 때 임시 파일을 만들어 끈다. 드롭되면 컨트롤러가 프리뷰를 닫는다.
private final class PreviewDragView: NSView, NSDraggingSource {
    var image: NSImage?
    var onDragWillBegin: (() -> Void)?
    var onDragDidEnd: ((Bool) -> Void)? // dropped 여부
    private var mouseDownLocation: NSPoint = .zero
    private var dragging = false
    private var tempURL: URL?

    // 위에 얹힌 이미지·힌트 서브뷰가 아니라 이 뷰가 마우스 이벤트를 받게 한다
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
        dragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !dragging, let image else { return }
        let delta = hypot(event.locationInWindow.x - mouseDownLocation.x,
                          event.locationInWindow.y - mouseDownLocation.y)
        guard delta > 4 else { return } // 클릭 떨림은 드래그로 취급하지 않음
        guard let url = writeTempImage(image) else { return }
        dragging = true
        tempURL = url
        onDragWillBegin?()
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        item.setDraggingFrame(bounds, contents: image) // 힌트 바 없는 원본 이미지를 드래그 미리보기로
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? .copy : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint,
                         operation: NSDragOperation) {
        let dropped = operation != []
        if dropped, let url = tempURL {
            // 수신 앱이 복사할 여유를 두고 삭제 (스택 removeAfterDrag과 동일 취지)
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                try? FileManager.default.removeItem(at: url)
            }
        } else if let url = tempURL {
            try? FileManager.default.removeItem(at: url) // 취소 → 임시 파일 즉시 정리
        }
        tempURL = nil
        dragging = false
        onDragDidEnd?(dropped)
    }

    /// 드래그용 임시 파일 — 설정 포맷으로 관리 폴더에 쓴다(스택 saveToStack과 동일 인코딩).
    private func writeTempImage(_ image: NSImage) -> URL? {
        let settings = AppSettings.shared
        let type: NSBitmapImageRep.FileType = settings.imageFormat == .jpg ? .jpeg : .png
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: type, properties: [:]) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss.SSS"
        let name = "Screenshot \(formatter.string(from: Date())).\(settings.imageFormat.rawValue)"
        let url = ScreenshotStore.directory.appendingPathComponent(name)
        do { try data.write(to: url); return url } catch { return nil }
    }
}
