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

            VStack(alignment: .leading, spacing: 2) {
                Toggle("메뉴바에 아이콘 표시", isOn: $settings.showMenuBarIcon)
                Text("숨겨도 Sill을 다시 실행하면 설정창이 열립니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
        }
    }
}
