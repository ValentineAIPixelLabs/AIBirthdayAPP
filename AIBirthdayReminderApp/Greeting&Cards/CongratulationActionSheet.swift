import SwiftUI
import Foundation

// MARK: - Localization helpers (file-local)
private func appLocale() -> Locale {
    if let code = UserDefaults.standard.string(forKey: "app.language.code") { return Locale(identifier: code) }
    if let code = Bundle.main.preferredLocalizations.first { return Locale(identifier: code) }
    return .current
}
private func appBundle() -> Bundle {
    if let code = UserDefaults.standard.string(forKey: "app.language.code"),
       let path = Bundle.main.path(forResource: code, ofType: "lproj"),
       let bundle = Bundle(path: path) { return bundle }
    return .main
}

@MainActor
struct CongratulationActionSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onGenerateText: () -> Void
    var onGenerateCard: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            

            Text(String(localized: "congrats.sheet.title",
                        defaultValue: "Что вы хотите сгенерировать?",
                        bundle: appBundle(),
                        locale: appLocale()))
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.top, 6)

            PrimaryCTAButton(
                title: String(localized: "congrats.sheet.text",
                               defaultValue: "Текстовое поздравление",
                               bundle: appBundle(),
                               locale: appLocale()),
                systemImage: "wand.and.stars",
                isLoading: false,
                action: onGenerateText
            )

            PrimaryCTAButton(
                title: String(localized: "congrats.sheet.card",
                               defaultValue: "Открытку",
                               bundle: appBundle(),
                               locale: appLocale()),
                systemImage: "photo.on.rectangle.angled",
                isLoading: false,
                action: onGenerateCard
            )

            Spacer()
        }
        .background(Color.clear)
        .padding()
        .presentationDetents([.medium, .fraction(0.4)])
        .presentationBackground(.ultraThinMaterial) // полупрозрачный стеклянный фон как у таб-бара
        .presentationCornerRadius(24)               // плавные скругления контейнера
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
        .presentationBackgroundInteraction(.disabled) // взаимодействие с контентом под шитом (iOS 17+)
    }
}
