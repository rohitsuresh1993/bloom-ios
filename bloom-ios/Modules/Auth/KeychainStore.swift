import Foundation
import Security

// Minimal Keychain Services wrapper. Not Auth-specific — Security's future PIN-fallback storage
// reuses this too. There's no server anywhere in this app, so the only things that ever live
// here are the Sign in with Apple opaque user identifier and, later, a PIN fallback.
enum KeychainStore {
    // `.whenUnlockedThisDeviceOnly`: never syncs to iCloud Keychain, never restorable to another
    // device, and unreadable while the device is locked — consistent with the rest of the app's
    // local-only, locked-device-unreadable storage posture.
    static func save(_ value: String, service: String, account: String) {
        let query = query(service: service, account: account)
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func read(service: String, account: String) -> String? {
        var attributes = query(service: service, account: account)
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(attributes as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(service: String, account: String) {
        SecItemDelete(query(service: service, account: account) as CFDictionary)
    }

    private static func query(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
