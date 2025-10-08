import Foundation
import Security

/// Управляет устойчивым идентификатором устройства, который будем использовать как appAccountToken
@MainActor
final class DeviceAccountManager: ObservableObject {
    static let shared = DeviceAccountManager()

    private let tokenKey = "device.account.token"
    private let service = Bundle.main.bundleIdentifier ?? "AIBirthdayReminderApp"

    private(set) var token: String

    private init() {
        let existing = (try? Self.readKeychainValue(for: tokenKey, service: service)) ?? nil
        if let value = existing,
           !value.isEmpty,
           UUID(uuidString: value) != nil {
            token = value
        } else {
            let newToken = UUID().uuidString
            token = newToken
            try? Self.storeKeychainValue(newToken, for: tokenKey, service: service)
        }
    }

    /// Гарантирует, что токен существует, и возвращает его строковое значение
    func appAccountToken() -> String {
        if token.isEmpty {
            let newToken = UUID().uuidString
            token = newToken
            try? Self.storeKeychainValue(newToken, for: tokenKey, service: service)
        }
        return token
    }

    func appAccountUUID() -> UUID {
        if let uuid = UUID(uuidString: token) {
            return uuid
        }
        resetToken()
        return UUID(uuidString: token) ?? UUID()
    }

    /// Сбрасывает токен (использовать осторожно, приведёт к созданию нового "аккаунта")
    func resetToken() {
        let newToken = UUID().uuidString
        token = newToken
        try? Self.storeKeychainValue(newToken, for: tokenKey, service: service)
    }

    // MARK: - Private helpers

    private static func storeKeychainValue(_ value: String, for key: String, service: String, accessibility: CFString = kSecAttrAccessibleAfterFirstUnlock) throws {
        let data = Data(value.utf8)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }

    private static func readKeychainValue(for key: String, service: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        guard let data = item as? Data, let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }
}
