import Foundation

enum SettingsPane: Equatable, Hashable, Identifiable {
    case general
    case capture
    case text
    case about

    var id: Self { self }

    static let sidebarPanes: [SettingsPane] = [.general, .capture, .text, .about]

    var title: String {
        switch self {
        case .general:
            return "일반"
        case .capture:
            return "캡처"
        case .text:
            return "텍스트 추출"
        case .about:
            return "정보"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "gearshape"
        case .capture:
            return "camera.viewfinder"
        case .text:
            return "text.viewfinder"
        case .about:
            return "info.circle"
        }
    }
}
