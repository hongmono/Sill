import AppKit
import Vision

/// Vision OCR 래퍼. UI 없음 — 이미지에서 텍스트를 인식해 줄 단위로 돌려준다.
enum TextRecognizer {
    /// 백그라운드에서 인식, 메인에서 completion. 실패/빈 결과는 빈 문자열.
    static func recognize(_ image: NSImage, completion: @escaping (String) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion("")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["ko-KR", "en-US"] // 한국어는 macOS 14+(revision 3)
            try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            let text = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            DispatchQueue.main.async { completion(text) }
        }
    }
}
