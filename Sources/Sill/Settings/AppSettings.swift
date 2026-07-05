import AppKit
import Combine
import ServiceManagement

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum StackSide: String {
        case left, right
    }

    enum ImageFormat: String {
        case png, jpg
    }

    @Published var stackSide: StackSide {
        didSet { UserDefaults.standard.set(stackSide.rawValue, forKey: "stackSide") }
    }

    @Published var imageFormat: ImageFormat {
        didSet { UserDefaults.standard.set(imageFormat.rawValue, forKey: "imageFormat") }
    }

    /// nil = 임시 폴더(앱이 관리, 스택에서 빠지면 파일 삭제)
    @Published var saveDirectory: URL? {
        didSet { UserDefaults.standard.set(saveDirectory?.path, forKey: "saveDirectory") }
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
        imageFormat = ImageFormat(rawValue: UserDefaults.standard.string(forKey: "imageFormat") ?? "") ?? .png
        if let path = UserDefaults.standard.string(forKey: "saveDirectory"), !path.isEmpty {
            saveDirectory = URL(fileURLWithPath: path)
        } else {
            saveDirectory = nil
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
