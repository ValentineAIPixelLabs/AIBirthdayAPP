import AuthenticationServices
import CryptoKit
import Security
import UIKit

@MainActor final class AppleSignInManager: NSObject {
    static let shared = AppleSignInManager()
    private override init() {
        super.init()
        if let legacy = UserDefaults.standard.string(forKey: jwtTokenKey) {
            try? KeychainStore.set(legacy, for: jwtTokenKey)
            UserDefaults.standard.removeObject(forKey: jwtTokenKey)
        }
    }

    private let appleIdKey = "apple_id"
    private let jwtTokenKey = "jwt_token" // Ключ для хранения JWT токена (Keychain)
    private var currentNonce: String?

    // MARK: - Public state
    var currentAppleId: String? { UserDefaults.standard.string(forKey: appleIdKey) }
    var currentJWTToken: String? { try? KeychainStore.get(jwtTokenKey) }

    // MARK: - Sign In entrypoint
    func startSignIn(presentationAnchor: ASPresentationAnchor? = nil) {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        // Готовим nonce: в запрос кладём sha256, сырой сохраняем локально для последующей сверки на сервере
        let rawNonce = Self.randomNonce()
        currentNonce = rawNonce
        request.nonce = Self.sha256(rawNonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - Session helpers
    func signOut() async {
        UserDefaults.standard.removeObject(forKey: appleIdKey)
        try? KeychainStore.delete(jwtTokenKey)
        
        // Переключаем CoreDataManager на локальный режим
        await CoreDataManager.shared.disableCloudKit()
        print("✅ Переключение на локальный режим после выхода")
        
        // Уведомляем о смене пользователя
        NotificationCenter.default.post(name: .userDidSignOut, object: nil)
    }

    func refreshCredentialState(completion: @escaping (ASAuthorizationAppleIDProvider.CredentialState) -> Void) {
        guard let user = currentAppleId else { completion(.notFound); return }
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: user) { state, _ in
            DispatchQueue.main.async { completion(state) }
        }
    }
}

// MARK: - Delegate
extension AppleSignInManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

        let userIdentifier = credential.user
        let email = credential.email // только при первом логине

        guard let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            print("❌ No identityToken from Apple")
            return
        }

        let authorizationCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }

        // Обмен на наш JWT на сервере
        guard let url = URL(string: "https://aibirthday-backend.up.railway.app/api/auth/apple") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any?] = [
            "identity_token": identityToken,
            "authorization_code": authorizationCode,
            "nonce": currentNonce, // сырой nonce; сервер сверит sha256(nonce) с токеном
            "email": email
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })

        URLSession.shared.dataTask(with: req) { data, resp, error in
            if let error = error {
                print("❌ Apple auth exchange failed:", error.localizedDescription)
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ Apple auth exchange: bad response")
                return
            }

            if let err = json["error"] as? String {
                print("❌ Apple auth exchange error:", err)
                return
            }

            // Сохраняем стабильный идентификатор и наш JWT (на главном потоке)
            DispatchQueue.main.async {
                if let user = (json["user"] as? [String: Any]),
                   let appleId = user["apple_id"] as? String {
                    UserDefaults.standard.set(appleId, forKey: self.appleIdKey)
                } else {
                    // fallback: что пришло от Apple
                    UserDefaults.standard.set(userIdentifier, forKey: self.appleIdKey)
                }

                if let token = json["token"] as? String {
                    try? KeychainStore.set(token, for: self.jwtTokenKey)
                    print("✅ Saved app JWT (Keychain)")
                    print("🔐 JWT: \(token)")
                    UIPasteboard.general.string = token
                }

                print("✅ Sign in with Apple completed")
                
                // Переключаем CoreDataManager на CloudKit режим с принудительной синхронизацией
                Task {
                    do {
                        try await CoreDataManager.shared.forceSyncWithCloudKit()
                        print("✅ CloudKit режим активирован после входа")
                    } catch {
                        print("❌ Ошибка активации CloudKit: \(error)")
                    }
                }
                
                // Уведомляем о смене пользователя
                NotificationCenter.default.post(name: .userDidSignIn, object: nil)
            }
        }.resume()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Sign in with Apple failed:", error.localizedDescription)
    }
}

// MARK: - Presentation anchor
extension AppleSignInManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first { return window }
        fatalError("No window available for presentation")
    }
}

// MARK: - Keychain helper
private enum KeychainStore {
    private static var service: String { Bundle.main.bundleIdentifier ?? "AIBirthdayReminderApp" }

    static func set(_ value: String, for key: String, accessibility: CFString = kSecAttrAccessibleAfterFirstUnlock) throws {
        let data = Data(value.utf8)
        // delete any existing item
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        // add new item
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

    static func get(_ key: String) throws -> String? {
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

    static func delete(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}

// MARK: - Nonce helpers
private extension AppleSignInManager {
    static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess { fatalError("Unable to generate nonce. SecRandom failed.") }

            randoms.forEach { random in
                if remaining == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Notifications for user switching
extension Notification.Name {
    static let userDidSignIn = Notification.Name("userDidSignIn")
    static let userDidSignOut = Notification.Name("userDidSignOut")
}
