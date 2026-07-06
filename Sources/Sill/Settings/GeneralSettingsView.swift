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
        }
    }
}
