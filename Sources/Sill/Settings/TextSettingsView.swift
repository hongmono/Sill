import AppKit
import SwiftUI

struct TextSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsViewLayout.detailGroupSpacing) {
            Label("텍스트 추출", systemImage: "text.viewfinder")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: SettingsViewLayout.detailRowSpacing) {
                Text("OCR 단축키 (프리뷰):")

                TextField("", text: Binding(
                    get: { settings.ocrKey.uppercased() },
                    set: { newValue in
                        if let ch = newValue.lowercased().last(where: { $0.isLetter }) {
                            settings.ocrKey = String(ch)
                        }
                    }
                ))
                .frame(width: 40)
                .multilineTextAlignment(.center)
            }

            Divider().padding(.vertical, 4)

            HStack(spacing: SettingsViewLayout.detailRowSpacing) {
                Text("번역 엔진:")

                Picker("", selection: $settings.translationEngine) {
                    Text("애플").tag(AppSettings.TranslationEngine.apple)
                    Text("DeepL").tag(AppSettings.TranslationEngine.deepl)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            if settings.translationEngine == .deepl {
                HStack(spacing: SettingsViewLayout.detailRowSpacing) {
                    Text("DeepL API 키:")

                    SecureField("xxxxxxxx-xxxx-...:fx", text: $settings.deepLAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                }
            }

            Text("애플: 온디바이스·무료·오프라인. DeepL: API 키 필요, free/pro 자동 판별.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
