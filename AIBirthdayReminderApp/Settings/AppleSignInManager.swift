import AuthenticationServices
import UIKit

final class AppleSignInManager: NSObject {
    static let shared = AppleSignInManager()
    private override init() { super.init() }

    private let appleIdKey = "apple_id"
    private let jwtTokenKey = "jwt_token" // Ключ для хранения JWT токена в UserDefaults
    var isStubEnabled = true

    // Получить сохранённый apple_id
    var currentAppleId: String? {
        return UserDefaults.standard.string(forKey: appleIdKey)
    }
    
    // Получить сохранённый JWT токен
    var currentJWTToken: String? {
        return UserDefaults.standard.string(forKey: jwtTokenKey)
    }

    // Запуск Sign In with Apple
    func startSignIn(presentationAnchor: ASPresentationAnchor? = nil) {
        
        if isStubEnabled {
                   // Генерируем фейковые данные
                   let fakeAppleId = "test-apple-id-\(UUID().uuidString)"
                   let fakeEmail = "testuser\(Int.random(in: 1000...9999))@example.com"
                   UserDefaults.standard.set(fakeAppleId, forKey: appleIdKey)
                   self.registerUserOnServer(appleId: fakeAppleId, email: fakeEmail)
                   print("✅ [STUB] Apple ID saved: \(fakeAppleId)")
                   return
               }
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        controller.performRequests()
    }
}

extension AppleSignInManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userIdentifier = appleIDCredential.user
            // Сохраняем apple_id
            UserDefaults.standard.set(userIdentifier, forKey: appleIdKey)
            self.registerUserOnServer(appleId: userIdentifier, email: appleIDCredential.email)
            print("✅ Apple ID saved: \(userIdentifier)")
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Sign in with Apple failed: \(error.localizedDescription)")
    }
}

extension AppleSignInManager {
    private func registerUserOnServer(appleId: String, email: String?) {
        guard let url = URL(string: "https://aibirthday-backend.up.railway.app/api/users") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "apple_id": appleId,
            "email": email ?? ""
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Ошибка регистрации пользователя:", error)
                return
            }
            if let data = data,
               let resp = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("Регистрация на сервере прошла успешно:", resp)
                // Если в ответе есть поле "token", сохраняем его в UserDefaults
                if let token = resp["token"] as? String {
                    UserDefaults.standard.set(token, forKey: self.jwtTokenKey)
                    print("✅ JWT токен сохранён: \(token)")
                }
            }
        }.resume()
    }
    
    // Пример использования currentJWTToken для добавления Authorization в запрос
    func makeAuthorizedRequest() {
        guard let url = URL(string: "https://example.com/protected/resource") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = currentJWTToken {
            // Добавляем заголовок Authorization с Bearer токеном
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Обработка ответа
        }.resume()
    }
}

extension AppleSignInManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            return window
        }
        fatalError("No window available for presentation")
    }
}
