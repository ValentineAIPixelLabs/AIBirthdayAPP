import AuthenticationServices
import UIKit

final class AppleSignInManager: NSObject {
    static let shared = AppleSignInManager()
    private override init() { super.init() }

    private let appleIdKey = "apple_id"

    // Получить сохранённый apple_id
    var currentAppleId: String? {
        return UserDefaults.standard.string(forKey: appleIdKey)
    }

    // Запуск Sign In with Apple
    func startSignIn(presentationAnchor: ASPresentationAnchor? = nil) {
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
            print("✅ Apple ID saved: \(userIdentifier)")
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Sign in with Apple failed: \(error.localizedDescription)")
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
