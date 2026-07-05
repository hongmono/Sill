import Foundation

enum SettingsPane: Equatable, Hashable, Identifiable {
    case general
    case about

    var id: Self { self }

    static let sidebarPanes: [SettingsPane] = [.general, .about]

    var title: String {
        switch self {
        case .general:
            return "일반"
        case .about:
            return "정보"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "gearshape"
        case .about:
            return "info.circle"
        }
    }
}
