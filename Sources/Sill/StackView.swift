import AppKit
import SwiftUI

struct StackView: View {
    @ObservedObject var store: ScreenshotStore

    var body: some View {
        // 콘텐츠를 하단 정렬 — 패널이 하단 앵커(위로 자람)라 기준을 맞춰야 새 항목 삽입 시 기존(아래) 썸네일이 안 움직인다
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(store.screenshots) { shot in
                        ThumbnailView(
                            shot: shot,
                            dragEnded: { store.removeAfterDrag(shot) },
                            copy: { store.copy(shot) },
                            saveAs: { store.saveAs(shot) },
                            close: { store.remove(shot) }
                        )
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .bottom)
            }
        }
    }
}

struct ThumbnailView: View {
    let shot: ScreenshotStore.Screenshot
    let dragEnded: () -> Void
    let copy: () -> Void
    let saveAs: () -> Void
    let close: () -> Void
    @State private var hovering = false
    @State private var appeared = false // 새로 추가된 이 썸네일만 슬라이드업+페이드인, 기존 항목엔 발생 안 함

    var body: some View {
        Image(nsImage: shot.image)
            .resizable()
            .scaledToFill()
            .frame(width: 160, height: 104)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.2), lineWidth: 1)
            )
            .shadow(radius: hovering ? 8 : 4)
            .overlay(DragArea(shot: shot, dragEnded: dragEnded, copy: copy, saveAs: saveAs))
            .overlay(alignment: .topTrailing) {
                if hovering {
                    Button(action: close) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white, .black.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                    .transition(.opacity)
                }
            }
            .scaleEffect(hovering ? 1.04 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovering)
            .onHover { hovering = $0 }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20) // 아래(+y)에서 시작해 제자리로 올라옴 — offset은 레이아웃 슬롯 불변이라 기존 항목 안 밀림
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { appeared = true }
            }
    }
}

/// SwiftUI onDrag는 드롭 완료 콜백이 없다 — 드롭 후 스택에서 제거하려면 AppKit 드래그 소스 필요.
struct DragArea: NSViewRepresentable {
    let shot: ScreenshotStore.Screenshot
    let dragEnded: () -> Void
    let copy: () -> Void
    let saveAs: () -> Void

    func makeNSView(context: Context) -> DragNSView { DragNSView() }

    func updateNSView(_ view: DragNSView, context: Context) {
        view.url = shot.url
        view.image = shot.image
        view.onDragEnded = dragEnded
        view.onCopy = copy
        view.onSaveAs = saveAs
    }
}

final class DragNSView: NSView, NSDraggingSource {
    var url: URL?
    var image: NSImage?
    var onDragEnded: (() -> Void)?
    var onCopy: (() -> Void)?
    var onSaveAs: (() -> Void)?
    private var mouseDownLocation: NSPoint = .zero
    private var isDragging = false

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isDragging, let url else { return }
        let delta = hypot(event.locationInWindow.x - mouseDownLocation.x,
                          event.locationInWindow.y - mouseDownLocation.y)
        guard delta > 4 else { return } // 클릭 떨림은 드래그로 취급하지 않음
        isDragging = true
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        item.setDraggingFrame(bounds, contents: image)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? .copy : []
    }

    func draggingSession(_ session: NSDraggingSession,
                         endedAt screenPoint: NSPoint,
                         operation: NSDragOperation) {
        if operation != [] { onDragEnded?() } // 실제 드롭됐을 때만 (취소 시 유지)
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let copyItem = NSMenuItem(title: "클립보드에 복사", action: #selector(copyAction), keyEquivalent: "")
        copyItem.target = self
        menu.addItem(copyItem)
        let saveItem = NSMenuItem(title: "다른 이름으로 저장...", action: #selector(saveAsAction), keyEquivalent: "")
        saveItem.target = self
        menu.addItem(saveItem)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func copyAction() {
        onCopy?()
    }

    @objc private func saveAsAction() {
        onSaveAs?()
    }
}
