import Foundation
import NaturalLanguage
import Translation

/// 번역 엔진 seam. 나중에 DeepL 등으로 갈아끼우려면 이 프로토콜만 구현하면 된다.
protocol Translator {
    /// 언어 자동감지 후 방향 규칙에 따라 번역. 한국어→영어, 그 외→한국어.
    func translate(_ text: String) async throws -> String
}

/// 애플 온디바이스 번역. `TranslationSession`은 SwiftUI `.translationTask`로만 얻을 수 있어(직접 생성 불가),
/// 뷰가 세션을 넘겨주면 continuation으로 이어받는 브리지 구조.
@MainActor
final class AppleTranslator: ObservableObject, Translator {
    @Published var configuration: TranslationSession.Configuration?
    private var continuation: CheckedContinuation<String, Error>?
    private var pendingText = ""

    func translate(_ text: String) async throws -> String {
        // 방향 결정만 감지로 하고, 실제 소스 언어는 프레임워크 자동감지(source=nil)에 맡긴다.
        let target = Locale.Language(identifier: Self.isKorean(text) ? "en" : "ko")
        pendingText = text
        return try await withCheckedThrowingContinuation { cont in
            continuation = cont
            // 새 인스턴스로 세팅해야 .translationTask가 (재)실행된다.
            configuration = TranslationSession.Configuration(target: target)
        }
    }

    /// 카드 뷰의 `.translationTask`에서 호출. 세션으로 실제 번역 후 continuation 완료.
    func runSession(_ session: TranslationSession) async {
        guard let cont = continuation else { return }
        continuation = nil
        defer { configuration = nil }
        do {
            let response = try await session.translate(pendingText)
            cont.resume(returning: response.targetText)
        } catch {
            cont.resume(throwing: error)
        }
    }

    // ponytail: dominant 언어 기준 휴리스틱. 한/영 혼합이면 우세 언어로 판정. 부족하면 그때 정교화.
    private static func isKorean(_ text: String) -> Bool {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage == .korean
    }
}
