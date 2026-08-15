import Foundation
import Security

enum KeychainStore {
    private static let service = "com.shiqixiaoyao.accounting51.credentials"
    static func read(_ key: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func write(_ value: String, for key: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        let data = Data(value.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound { var item = query; item[kSecValueData as String] = data; let addStatus = SecItemAdd(item as CFDictionary, nil); guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) } } else if status != errSecSuccess { throw KeychainError(status: status) }
    }
    static func delete(_ key: String) throws { let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]; let status = SecItemDelete(query as CFDictionary); guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) } }
    static func clear() throws { for key in ["aiAPIKey", "webDAVPassword", "githubToken"] { try delete(key) } }
    struct KeychainError: LocalizedError { let status: OSStatus; var errorDescription: String? { "Keychain 操作失败（状态码 \(status)）。" } }
}
