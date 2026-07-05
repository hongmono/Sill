import SwiftUI
import AppKit

struct AboutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SettingsViewLayout.detailGroupSpacing) {
            Label("정보", systemImage: "info.circle")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: SettingsViewLayout.detailRowSpacing) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sill")
                        .font(.title3)
                        .bold()
                    Text("버전 \(Self.appVersion)")
                        .foregroundStyle(.secondary)
                }
            }

            Link("GitHub", destination: URL(string: "https://github.com/hongmono/Sill")!)
        }
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
}
