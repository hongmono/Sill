import Foundation
import NaturalLanguage
import Translation

/// 번역 엔진 seam. 애플/DeepL 등이 이 프로토콜만 구현하면 갈아끼울 수 있다.
protocol Translator {
    /// 언어 자동감지 후 방향 규칙에 따라 번역. 한국어→영어, 그 외→한국어.
    func translate(_ text: String) async throws -> String
}

/// 방향 규칙 공유 — 두 엔진이 같은 기준으로 대상 언어를 고른다.
// ponytail: dominant 언어 기준 휴리스틱. 한/영 혼합이면 우세 언어로 판정. 부족하면 그때 정교화.
enum TranslationLanguage {
    static func isKorean(_ text: String) -> Bool {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage == .korean
    }
}

enum TranslationError: LocalizedError {
    case missingDeepLKey
    case deepLHTTP(Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingDeepLKey: return "DeepL API 키를 설정에서 입력하세요."
        case .deepLHTTP(let code): return code == 403 ? "DeepL 인증 실패 — 키를 확인하세요." : "DeepL 오류 (HTTP \(code))."
        case .emptyResponse: return "번역 결과가 비어 있습니다."
        }
    }
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
        let target = Locale.Language(identifier: TranslationLanguage.isKorean(text) ? "en" : "ko")
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
}

/// DeepL API 번역. 순수 네트워크 호출이라 뷰 바인딩 불필요.
struct DeepLTranslator: Translator {
    let apiKey: String

    func translate(_ text: String) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw TranslationError.missingDeepLKey }

        let target = TranslationLanguage.isKorean(text) ? "EN-US" : "KO"
        var request = URLRequest(url: Self.endpoint(for: key))
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Sill/\(Self.appVersion)", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(RequestBody(text: [text], target_lang: target))

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw TranslationError.deepLHTTP(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let translated = decoded.translations.first?.text, !translated.isEmpty else {
            throw TranslationError.emptyResponse
        }
        return translated
    }

    /// free 키는 ":fx"로 끝난다 → api-free, 아니면 pro.
    static func endpoint(for key: String) -> URL {
        let host = key.hasSuffix(":fx") ? "api-free.deepl.com" : "api.deepl.com"
        return URL(string: "https://\(host)/v2/translate")!
    }

    private static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"

    private struct RequestBody: Encodable { let text: [String]; let target_lang: String }
    private struct ResponseBody: Decodable {
        struct Translation: Decodable { let text: String }
        let translations: [Translation]
    }
}

#if DEBUG
/// ponytail: 순수 로직(엔드포인트·방향) self-check. AppDelegate가 DEBUG에서 한 번 호출.
enum TranslationSelfCheck {
    static func run() {
        assert(DeepLTranslator.endpoint(for: "abc:fx").host == "api-free.deepl.com")
        assert(DeepLTranslator.endpoint(for: "abc").host == "api.deepl.com")
        assert(TranslationLanguage.isKorean("안녕하세요 반갑습니다") == true)
        assert(TranslationLanguage.isKorean("Hello there friend") == false)
    }
}
#endif
