import SwiftUI
import UIKit

@main
struct AIBirthdayReminderAppApp: App {
    init() {
        NotificationManager.shared.requestAuthorization()
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = .clear
        appearance.shadowImage = nil
        appearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(HolidaysViewModel())
        }
    }
}

struct RootView: View {
    @State private var isSignedIn = AppleSignInManager.shared.currentAppleId != nil

    var body: some View {
        if isSignedIn {
            AppTabView()
        } else {
            SignInView(isSignedIn: $isSignedIn)
        }
    }
}

struct SignInView: View {
    @Binding var isSignedIn: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Пожалуйста, войдите через Apple")
                .font(.title2)
            Button(action: {
                AppleSignInManager.shared.startSignIn()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isSignedIn = AppleSignInManager.shared.currentAppleId != nil
                }
            }) {
                Text("Войти через Apple")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}
