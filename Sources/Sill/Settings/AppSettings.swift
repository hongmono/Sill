import AppKit
import Combine
import ServiceManagement

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum StackSide: String {
        case left, right
    }

    @Published var stackSide: StackSide {
        didSet { UserDefaults.standard.set(stackSide.rawValue, forKey: "stackSide") }
    }

    /// SMAppService 상태가 진실의 원천 — 등록/해제 실패 시 토글 원복
    @Published var launchAtLogin: Bool {
        didSet {
            guard oldValue != launchAtLogin else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("로그인 시 자동 실행 변경 실패: \(error.localizedDescription)")
                launchAtLogin = oldValue
            }
        }
    }

    private init() {
        stackSide = StackSide(rawValue: UserDefaults.standard.string(forKey: "stackSide") ?? "") ?? .right
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
