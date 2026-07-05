import SwiftUI

/// 설정 창의 사이드바 선택 상태. SettingsWindowController가 소유한다.
final class SettingsNavigationState: ObservableObject {
    @Published var selectedPane: SettingsPane?

    init(selectedPane: SettingsPane? = .general) {
        self.selectedPane = selectedPane
    }
}

enum SettingsViewLayout {
    static let windowMinWidth: CGFloat = 560
    static let windowMinHeight: CGFloat = 400
    static let sidebarMinWidth: CGFloat = 150
    static let sidebarWidth: CGFloat = 160
    static let sidebarMaxWidth: CGFloat = 260
    static let detailHorizontalPadding: CGFloat = 24
    static let detailTopMargin: CGFloat = 24
    static let detailMinWidth: CGFloat = 320
    static let sectionSpacing: CGFloat = 16
    static let detailGroupSpacing: CGFloat = 8
    static let detailRowSpacing: CGFloat = 12
    static let detailBottomPadding: CGFloat = 24
}
