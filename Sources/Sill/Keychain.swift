import Foundation
import Security

/// 최소 키체인 래퍼 — generic password 하나(계정 이름)당 문자열 하나. service=번들 ID.
enum Keychain {
    private static let service = Bundle.main.bundleIdentifier ?? "com.hongmono.Sill"

    static func string(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// nil/빈 문자열이면 항목 삭제, 아니면 저장(있으면 갱신).
    static func set(_ value: String?, for account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        guard let value, !value.isEmpty, let data = value.data(using: .utf8) else {
            SecItemDelete(base as CFDictionary)
            return
        }
        let status = SecItemCopyMatching(base as CFDictionary, nil)
        if status == errSecSuccess {
            SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        } else {
            SecItemAdd(base.merging([kSecValueData as String: data]) { $1 } as CFDictionary, nil)
        }
    }
}
