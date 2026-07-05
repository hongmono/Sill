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
            .onTapGesture(perform: select)
            .onDrag { NSItemProvider(object: shot.url as NSURL) }
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
