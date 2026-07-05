import AppKit
import Combine
import SwiftUI

/// borderless 패널은 기본적으로 key window가 될 수 없어 ⌘C를 못 받는다 — 오버라이드 필요.
final class KeyablePanel: NSPanel {
    var onCopy: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers == "c" {
            onCopy?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

final class StackPanelController {
    private let panel: KeyablePanel
    private var cancellable: AnyCancellable?
    private let panelWidth: CGFloat = 176
    private let itemHeight: CGFloat = 112 // 썸네일 104 + 간격 8

    init(store: ScreenshotStore) {
        panel = KeyablePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.onCopy = { [weak store] in store?.copySelected() }

        let view = StackView(store: store, makeKey: { [weak panel] in panel?.makeKey() })
        panel.contentView = NSHostingView(rootView: view)

        cancellable = store.$screenshots
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shots in self?.layout(count: shots.count) }
    }

    private func layout(count: Int) {
        guard count > 0, let screen = NSScreen.main else {
            panel.orderOut(nil)
            return
        }
        let visible = screen.visibleFrame
        let height = min(CGFloat(count) * itemHeight + 16, visible.height)
        panel.setFrame(
            NSRect(x: visible.maxX - panelWidth, y: visible.midY - height / 2,
                   width: panelWidth, height: height),
            display: true
        )
        panel.orderFrontRegardless()
    }
}
