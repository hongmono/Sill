import AppKit
import SwiftUI

struct StackView: View {
    @ObservedObject var store: ScreenshotStore
    let makeKey: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
                ForEach(store.screenshots) { shot in
                    ThumbnailView(
                        shot: shot,
                        isSelected: store.selectedID == shot.id,
                        select: {
                            store.selectedID = shot.id
                            makeKey() // 패널을 key로 만들어야 ⌘C가 패널에 도착
                        },
                        dragEnded: { store.removeAfterDrag(shot) },
                        close: { store.remove(shot) }
                    )
                }
            }
            .padding(8)
        }
    }
}

struct ThumbnailView: View {
    let shot: ScreenshotStore.Screenshot
    let isSelected: Bool
    let select: () -> Void
    let dragEnded: () -> Void
    let close: () -> Void
    @State private var hovering = false

    var body: some View {
        Image(nsImage: shot.image)
            .resizable()
            .scaledToFill()
            .frame(width: 160, height: 104)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.black.opacity(0.2),
                            lineWidth: isSelected ? 3 : 1)
            )
            .shadow(radius: 4)
            .overlay(DragSelectArea(shot: shot, select: select, dragEnded: dragEnded))
            .overlay(alignment: .topTrailing) {
                if hovering {
                    Button(action: close) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white, .black.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                }
            }
            .onHover { hovering = $0 }
    }
}

/// SwiftUI onDrag는 드롭 완료 콜백이 없다 — 드롭 후 스택에서 제거하려면 AppKit 드래그 소스 필요.
struct DragSelectArea: NSViewRepresentable {
    let shot: ScreenshotStore.Screenshot
    let select: () -> Void
    let dragEnded: () -> Void

    func makeNSView(context: Context) -> DragSelectNSView { DragSelectNSView() }

    func updateNSView(_ view: DragSelectNSView, context: Context) {
        view.url = shot.url
        view.image = shot.image
        view.onSelect = select
        view.onDragEnded = dragEnded
    }
}

final class DragSelectNSView: NSView, NSDraggingSource {
    var url: URL?
    var image: NSImage?
    var onSelect: (() -> Void)?
    var onDragEnded: (() -> Void)?
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

    override func mouseUp(with event: NSEvent) {
        if !isDragging { onSelect?() }
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
}
