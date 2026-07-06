import SwiftUI

struct SettingsDetailView: View {
    @ObservedObject var settings: AppSettings
    let pane: SettingsPane

    var body: some View {
        ScrollView {
            detailStack
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.leading, SettingsViewLayout.detailHorizontalPadding)
                .padding(.trailing, SettingsViewLayout.detailHorizontalPadding)
                .padding(.top, SettingsViewLayout.detailTopMargin)
                .padding(.bottom, SettingsViewLayout.detailBottomPadding)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var detailStack: some View {
        VStack(alignment: .leading, spacing: SettingsViewLayout.sectionSpacing) {
            switch pane {
            case .general:
                GeneralSettingsView(settings: settings)
            case .capture:
                CaptureSettingsView(settings: settings)
            case .text:
                TextSettingsView(settings: settings)
            case .about:
                AboutSettingsView()
            }
        }
    }
}
