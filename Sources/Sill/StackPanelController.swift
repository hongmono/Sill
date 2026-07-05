import AppKit
import Combine
import SwiftUI

final class StackPanelController {
    private let panel: NSPanel
    private var cancellables: Set<AnyCancellable> = []
    private var count = 0
    private let panelWidth: CGFloat = 176
    private let itemHeight: CGFloat = 112 // 썸네일 104 + 간격 8

    init(store: ScreenshotStore) {
        panel = NSPanel(
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

        panel.contentView = NSHostingView(rootView: StackView(store: store))

        store.$screenshots
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shots in
                self?.count = shots.count
                self?.layout()
            }
            .store(in: &cancellables)

        AppSettings.shared.$stackSide
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.layout() }
            .store(in: &cancellables)
    }

    private func layout() {
        guard count > 0, let screen = NSScreen.screens.first else {
            panel.orderOut(nil)
            return
        }
        let visible = screen.visibleFrame
        let margin: CGFloat = 16
        let height = min(CGFloat(count) * itemHeight + 16, visible.height - margin * 2)
        let x = AppSettings.shared.stackSide == .right
            ? visible.maxX - panelWidth - margin
            : visible.minX + margin
        // 하단 앵커: y는 하단 마진에 고정, 항목이 늘면 위로 자람
        panel.setFrame(
            NSRect(x: x, y: visible.minY + margin, width: panelWidth, height: height),
            display: true
        )
        panel.orderFrontRegardless()
    }
}
