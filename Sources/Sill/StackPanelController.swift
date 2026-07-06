import AppKit
import Combine
import SwiftUI

final class StackPanelController {
    private let panel: NSPanel
    private var cancellables: Set<AnyCancellable> = []
    private var count = 0
    private var anchoredScreen: NSScreen? // 스택이 현재 떠 있는 스크린. 캡처 때 마우스 스크린으로 정하고, 다른 모니터 클릭 시 그리로 이동
    private var focusMonitor: Any?
    private let panelWidth: CGFloat = 176
    private let itemHeight: CGFloat = 120 // 썸네일 104 + 간격 16

    init(store: ScreenshotStore, onExtractText: @escaping (ScreenshotStore.Screenshot) -> Void) {
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

        panel.contentView = NSHostingView(rootView: StackView(store: store, onExtractText: onExtractText))

        // receive(on:main) 필수 — @Published는 값 대입 전(willSet)에 발행하므로, 홉 없이 동기로 돌면
        // layout()이 stale한 store.screenshots를 강제 렌더해 표시가 한 캡처씩 밀린다.
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

        // 다른 모니터 클릭 = 포커스 이동 → 스택을 그 모니터로. 전역 모니터는 우리 앱 자신의 클릭엔 안 울려 드래그/삭제 중 튐 없음
        focusMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.followFocusedScreen()
        }
    }

    deinit {
        if let focusMonitor { NSEvent.removeMonitor(focusMonitor) }
    }

    private func followFocusedScreen() {
        guard count > 0, let screen = screenUnderMouse, screen.frame != anchoredScreen?.frame else { return }
        anchoredScreen = screen
        layout()
    }

    private func layout() {
        guard count > 0 else {
            anchoredScreen = nil // 스택이 비면 다음 캡처 때 마우스 스크린으로 재확정
            panel.orderOut(nil)
            return
        }
        if anchoredScreen == nil { anchoredScreen = screenUnderMouse }
        guard let screen = anchoredScreen else { return }
        let visible = screen.visibleFrame
        let margin: CGFloat = 16
        // 콘텐츠 정확 높이: 패딩 8*2 + 썸네일 104*n + 간격 16*(n-1) = 120n
        let height = min(CGFloat(count) * itemHeight, visible.height - margin * 2)
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

    private var screenUnderMouse: NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
    }

    /// 다음에 추가될 썸네일이 뜰 화면상 위치(맨 위 슬롯) — 프리뷰 fly 애니메이션 목적지.
    func nextThumbnailFrame() -> NSRect {
        guard let visible = (anchoredScreen ?? screenUnderMouse)?.visibleFrame else { return .zero }
        let margin: CGFloat = 16, pad: CGFloat = 8, thumbW: CGFloat = 160, thumbH: CGFloat = 104
        let height = min(CGFloat(count + 1) * itemHeight, visible.height - margin * 2)
        let panelTop = visible.minY + margin + height
        let x = AppSettings.shared.stackSide == .right
            ? visible.maxX - panelWidth - margin + pad
            : visible.minX + margin + pad
        return NSRect(x: x, y: panelTop - pad - thumbH, width: thumbW, height: thumbH)
    }
}
