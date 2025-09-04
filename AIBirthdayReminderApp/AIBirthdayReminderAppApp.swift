import SwiftUI
import UIKit
import CoreData
import CloudKit
import AuthenticationServices
import Combine

// Helper: consider user "authorized" if signed in with Apple OR explicitly chose to defer sign-in
@MainActor fileprivate func isUserAuthorized() -> Bool {
    AppleSignInManager.shared.currentAppleId != nil
    || UserDefaults.standard.bool(forKey: "auth.deferredSignIn")
}

@main
struct AIBirthdayReminderAppApp: App {
    @StateObject private var store = StoreKitManager()
    @StateObject private var lang = LanguageManager()
    @StateObject private var holidaysVM = HolidaysViewModel()
    init() {
        _ = CoreDataManager.shared // инициализируем стек Core Data + CloudKit
        setupCloudKitEventLogging()
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

    // DEBUG: Логирование событий синхронизации CloudKit и проверка схемы модели
    private func setupCloudKitEventLogging() {
        let container = CoreDataManager.shared.persistentContainer
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: .main
        ) { note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }
            #if DEBUG
            
            if let ckError = event.error as? CKError {
                print("⚠️ CloudKit CKError: \(ckError.code) — \(ckError.localizedDescription)")
                if ckError.code == .quotaExceeded { print("🧺 iCloud storage is FULL (quotaExceeded)") }
            } else if let err = event.error {
                print("⚠️ CloudKit error: \(err.localizedDescription)")
            }
            #endif
        }
    }

    private func debugPrintModelInfo() {
        let model = CoreDataManager.shared.persistentContainer.managedObjectModel
        if let entity = model.entitiesByName["CardHistoryEntity"] {
            print("▶︎ Unique constraints for CardHistoryEntity:")
            for (i, group) in entity.uniquenessConstraints.enumerated() {
                let names = group.compactMap { $0 as? String }.joined(separator: ", ")
                print("  [\(i)]: \(names)")
            }
            // Проверяем индекс поля `date` через Fetch Indexes (современный способ)
            let hasDateIndex = entity.indexes.contains { index in
                index.elements.contains { $0.property?.name == "date" }
            }
            print("▶︎ 'date' indexed via Fetch Indexes: \(hasDateIndex ? "YES" : "NO")")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(holidaysVM)
                .environmentObject(store)
                .environmentObject(lang)
                .environment(\.locale, lang.locale)
                .task {
                    store.startTransactionListener()
                    await store.loadProducts()
                    #if DEBUG
                    debugPrintModelInfo()
                    #endif
                }
        }
    }
}

@MainActor struct RootView: View {
    @State private var isSignedIn = isUserAuthorized()

    var body: some View {
        Group {
            if isSignedIn {
                AppTabView()
            } else {
                SignInView(isSignedIn: $isSignedIn)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)) { _ in
            isSignedIn = isUserAuthorized()
        }
    }
}

@MainActor struct SignInView: View {
    @Binding var isSignedIn: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("sign_in.prompt")
                .font(.title2)

            AppleIDButton {
                AppleSignInManager.shared.startSignIn()
            }
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                // User chose to defer sign-in; remember and proceed to the app
                UserDefaults.standard.set(true, forKey: "auth.deferredSignIn")
                isSignedIn = true
            } label: {
                Text("auth.continue.without.signin")
                    .font(.body)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isLink)
            .accessibilityHint(Text("auth.guest.hint"))
        }
        .padding()
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)) { _ in
            isSignedIn = isUserAuthorized()
        }
    }
}

private struct AppleIDButton: UIViewRepresentable {
    var action: () -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.cornerRadius = 10
        button.addTarget(context.coordinator, action: #selector(Coordinator.didTap), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func didTap() { action() }
    }
}

// MARK: - In-app language switching
enum AppLanguage: String, CaseIterable, Identifiable {
    case ru = "ru"
    case en = "en"
    
    var id: String { rawValue }
    
    /// Human-readable names for the language picker (shown in the current app language)
    var displayName: String {
        switch self {
        case .ru: return "Русский"
        case .en: return "English"
        }
    }
}

/// Centralized language manager. Stores the selected language and exposes the SwiftUI locale.
@MainActor final class LanguageManager: ObservableObject {
    private static let storageKey = "app.language.code"

    /// Default app language: Russian only when the system language starts with "ru", else English
    private static func systemDefault() -> AppLanguage {
        let sys = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
        return sys.hasPrefix("ru") ? .ru : .en
    }

    @Published var current: AppLanguage {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: Self.storageKey) }
    }
    
    /// Locale used by SwiftUI to localize Text/labels dynamically
    var locale: Locale { Locale(identifier: current.rawValue) }
    
    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.storageKey),
           let lang = AppLanguage(rawValue: saved) {
            self.current = lang
        } else {
            self.current = Self.systemDefault()
        }
    }
    
    /// Public API for setting language (extend as you add more languages)
    func set(_ language: AppLanguage) { self.current = language }
}
