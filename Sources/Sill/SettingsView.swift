import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Toggle("로그인 시 자동 실행", isOn: $settings.launchAtLogin)
            Picker("스택 위치:", selection: $settings.stackSide) {
                Text("왼쪽").tag(AppSettings.StackSide.left)
                Text("오른쪽").tag(AppSettings.StackSide.right)
            }
            .pickerStyle(.radioGroup)
        }
        .padding(20)
        .frame(width: 280)
    }
}
