import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsViewLayout.detailGroupSpacing) {
            Label("일반", systemImage: "gearshape")
                .font(.headline)
                .foregroundStyle(.primary)

            Toggle("로그인 시 자동 실행", isOn: $settings.launchAtLogin)

            HStack(spacing: SettingsViewLayout.detailRowSpacing) {
                Text("스택 위치:")

                Picker("", selection: $settings.stackSide) {
                    Text("왼쪽").tag(AppSettings.StackSide.left)
                    Text("오른쪽").tag(AppSettings.StackSide.right)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            HStack(spacing: SettingsViewLayout.detailRowSpacing) {
                Text("파일 형식:")

                Picker("", selection: $settings.imageFormat) {
                    Text("PNG").tag(AppSettings.ImageFormat.png)
                    Text("JPEG").tag(AppSettings.ImageFormat.jpg)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

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

            VStack(alignment: .leading, spacing: 4) {
                Text("저장 위치:")

                Text(settings.saveDirectory?.path ?? "임시 폴더 (스택에서 빼면 파일 삭제)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: SettingsViewLayout.detailRowSpacing) {
                    Button("폴더 선택...") { chooseSaveDirectory() }
                    if settings.saveDirectory != nil {
                        Button("임시 폴더로 되돌리기") { settings.saveDirectory = nil }
                    }
                }
            }
        }
    }

    private func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "선택"
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            settings.saveDirectory = url
        }
    }
}
