import AppKit
import SwiftUI
import Translation // .translationTask 모디파이어

/// OCR 카드의 표시 상태. 컨트롤러(복사)와 뷰(표시)가 공유한다.
@MainActor
final class OCRCardModel: ObservableObject {
    let original: String
    @Published var translation: String?
    @Published var isTranslating = false
    @Published var error: String?

    init(original: String) { self.original = original }

    /// 복사 대상 — 번역이 있으면 원문+번역, 없으면 원문.
    var clipboardText: String {
        if let translation, !translation.isEmpty {
            return original + "\n\n" + translation
        }
        return original
    }
}

/// OCR 결과를 화면 중앙 카드로 표시. ESC=취소, Enter/⌘C=복사 후 닫기, T=번역.
@MainActor
final class OCROverlayController {
    private let panel: KeyablePanel
    private var keyMonitor: Any?
    private var resignObserver: Any?
    private var model: OCRCardModel?
    private let appleTranslator = AppleTranslator() // .translationTask 바인딩용 — DeepL 선택 시엔 idle

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
        panel.sharingType = .none // OCR 카드가 다음 스크린샷/녹화에 안 찍히게
    }

    func show(text: String) {
        let model = OCRCardModel(original: text)
        self.model = model
        panel.contentView = NSHostingView(rootView: OCRResultView(model: model, translator: appleTranslator))

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
        // 다른 앱/창을 클릭해 카드가 key를 잃으면 닫는다 (모달 카드 UX)
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in self?.close() }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case 53: // ESC
                self.close()
                return nil
            case 36, 76: // Return, keypad Enter
                self.copyAndClose()
                return nil
            case 17 where !event.modifierFlags.contains(.command): // T
                self.startTranslation()
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

    private func startTranslation() {
        guard let model, !model.isTranslating, !model.original.isEmpty else { return }
        model.error = nil
        model.isTranslating = true
        // 설정 엔진 선택 — 애플은 .translationTask 바인딩 때문에 보유 인스턴스, DeepL은 현재 키로 즉석 생성
        let settings = AppSettings.shared
        let engine: Translator = settings.translationEngine == .deepl
            ? DeepLTranslator(apiKey: settings.deepLAPIKey)
            : appleTranslator
        Task {
            do {
                model.translation = try await engine.translate(model.original)
            } catch {
                model.error = "번역 실패: \(error.localizedDescription)"
            }
            model.isTranslating = false
        }
    }

    private func copyAndClose() {
        if let model, !model.original.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(model.clipboardText, forType: .string)
        }
        close()
    }

    private func close() {
        // orderOut이 didResignKey를 동기 발생시켜 재진입할 수 있으니 옵저버부터 제거
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        panel.orderOut(nil)
        model = nil
    }
}

/// borderless 패널은 기본적으로 key가 못 된다 — 키 입력을 받으려면 override 필요.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private struct OCRResultView: View {
    @ObservedObject var model: OCRCardModel
    @ObservedObject var translator: AppleTranslator

    var body: some View {
        VStack(spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(model.original.isEmpty ? "(인식된 텍스트 없음)" : model.original)
                        .textSelection(.enabled)
                        .font(.body)
                        .foregroundStyle(model.original.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if model.isTranslating {
                        Divider()
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("번역 중…").font(.callout).foregroundStyle(.secondary)
                        }
                    } else if let error = model.error {
                        Divider()
                        Text(error).font(.callout).foregroundStyle(.red)
                    } else if let translation = model.translation, !translation.isEmpty {
                        Divider()
                        Text(translation)
                            .textSelection(.enabled)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            Text("Enter · ⌘C 복사   ·   T 번역   ·   ESC 닫기")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 480, height: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        // 애플 엔진 특화 seam: 세션을 받아 번역 실행. 다른 엔진은 이 줄이 필요 없다.
        .translationTask(translator.configuration) { session in
            await translator.runSession(session)
        }
    }
}
