import Foundation
import SwiftUI
import UIKit

// MARK: - Localization helpers (file-local)
private func appLocale() -> Locale {
    if let code = UserDefaults.standard.string(forKey: "app.language.code") {
        return Locale(identifier: code)
    }
    if let code = Bundle.main.preferredLocalizations.first {
        return Locale(identifier: code)
    }
    return .current
}

private func appBundle() -> Bundle {
    if let code = UserDefaults.standard.string(forKey: "app.language.code"),
       let path = Bundle.main.path(forResource: code, ofType: "lproj"),
       let bundle = Bundle(path: path) {
        return bundle
    }
    return .main
}

/// Централизованные стили для всех кастомных кнопок приложения.
/// Используй параметры этого файла для любых кнопок (в том числе "Поздравить", FAB и пр.).
struct AppButtonStyle {
    // Основные параметры (универсальные)
    // ⚠️ Шрифты переведены на системные стили (Dynamic Type-friendly) по HIG 2025; не используем фиксированные размеры.
    static let cornerRadius: CGFloat = 16
    static let horizontalPadding: CGFloat = 20
    static let verticalPadding: CGFloat = 12
    static let height: CGFloat = 44
    static let iconSize: CGFloat = 22

    /// Брендовый акцент: System Blue
    static let brandAccent = Color(UIColor.systemBlue) // dynamic system blue (adapts to light/dark)
    /// Pressed — чуть темнее/насыщеннее оттенок синего
    static let brandAccentPressed = Color(.sRGB, red: 0.0/255.0, green: 103.0/255.0, blue: 229.0/255.0, opacity: 1.0) // #0067E5
    
    /// Прозрачность глянца для CTA
    static let ctaGlossTopOpacity: Double = 0.12

    /// Динамический цвет (light/dark)
    static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark ? dark : light
        })
    }
    
    /// Градиент для CTA (Primary / "Поздравить"): softened electric indigo → softened azure
    static func primaryFill() -> LinearGradient {
        let start = dynamicColor(
            light: UIColor(red: 0.47, green: 0.36, blue: 1.00, alpha: 1.0),   // light: softened electric indigo
            dark:  UIColor(red: 0.22, green: 0.20, blue: 0.55, alpha: 1.0)    // dark: deeper & muted violet
        )
        let end = dynamicColor(
            light: UIColor(red: 0.33, green: 0.66, blue: 1.00, alpha: 1.0),   // light: softened azure
            dark:  UIColor(red: 0.10, green: 0.38, blue: 0.70, alpha: 1.0)    // dark: muted azure
        )
        return LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    /// Вспомогательный градиент для тонкой рамки CTA
    static func primaryStroke() -> LinearGradient {
        let top = dynamicColor(
            light: UIColor(white: 1.0, alpha: 0.75),
            dark:  UIColor(red: 0.75, green: 0.70, blue: 0.95, alpha: 0.28) // dark: softer violet rim
        )
        let bottom = dynamicColor(
            light: UIColor(white: 1.0, alpha: 0.25),
            dark:  UIColor(red: 0.35, green: 0.55, blue: 0.90, alpha: 0.12) // dark: softer azure rim
        )
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }
    
    /// Верхний глянец (white→clear), очень деликатный
    static func primaryGloss() -> LinearGradient {
        let top = dynamicColor(
            light: UIColor(white: 1.0, alpha: ctaGlossTopOpacity),
            dark:  UIColor(white: 1.0, alpha: 0.06) // darker theme: more muted gloss
        )
        return LinearGradient(colors: [top, .clear], startPoint: .top, endPoint: .bottom)
    }
    
    // Основная кнопка (Primary)
    struct Primary {
        static let backgroundColor = AppButtonStyle.brandAccent
        static let textColor = Color.white
        static let font = Font.system(.headline, design: .rounded)
        static let shadow = Color.black.opacity(0.10)
        static let shadowRadius: CGFloat = 4
    }
    
    // Второстепенная кнопка (Secondary)
    struct Secondary {
        static let backgroundColor = Color.gray.opacity(0.13)
        static let textColor = AppButtonStyle.brandAccent
        static let font = Font.system(.body, design: .rounded)
        static let shadow = Color.clear
        static let borderColor = Color(.sRGB, red: 184.0/255.0, green: 198.0/255.0, blue: 221.0/255.0, opacity: 0.28) // #B8C6DD @ 28%
        static let borderWidth: CGFloat = 1
    }
    
    // Круглая кнопка (для иконок)
    struct Circular {
        static let diameter: CGFloat = 44
        static let backgroundColor = AppButtonStyle.brandAccent.opacity(0.14)
        static let iconColor = AppButtonStyle.brandAccent
        static let iconSize: CGFloat = 20
        static let shadow = Color.black.opacity(0.07)
        static let shadowRadius: CGFloat = 2
    }
    
    // Кнопка "Поздравить" (для карточки контакта/праздника)
    struct Congratulate {
        static let backgroundColor = AppButtonStyle.brandAccent
        static let textColor = Color.white
        static let font = Font.system(.headline, design: .rounded)
        static let horizontalPadding: CGFloat = 30
        static let verticalPadding: CGFloat = 12
        static let cornerRadius: CGFloat = 14
        static let iconSize: CGFloat = 18
        static let shadow: Color = Color(UIColor { tc in
            if tc.userInterfaceStyle == .dark {
                return UIColor(red: 0.12, green: 0.44, blue: 0.90, alpha: 0.30) // darker, muted glow in dark
            } else {
                return UIColor(red: 0.23, green: 0.56, blue: 0.98, alpha: 0.35)
            }
        })
        static let shadowRadius: CGFloat = 14
        static let ambientShadow: Color = Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.0, alpha: 0.12)   // reduce ambient in dark
            : UIColor(white: 0.0, alpha: 0.08)
        })
        static let ambientShadowRadius: CGFloat = 3
    }
    // Стили для фильтр-кнопок (капсул) в списках и фильтрах
    struct FilterChip {
        /// Фон под фильтрами/капсулами (например, .ultraThinMaterial)
        // static let backgroundMaterial: Material = .ultraThinMaterial
        /// Материал для невыбранных чипсов (как у карточек)
        static let unselectedMaterial: Material = .thinMaterial
        /// Дополнительный оверлей при нажатии (деликатный)
        static let pressedOverlayOpacity: Double = 0.12
        static let selectedBackground = AppButtonStyle.brandAccent
        static let unselectedBackground = Color(.systemGray6)
        static let selectedText = Color.white
        static let unselectedText = Color.primary
        static let font = Font.system(.subheadline, design: .rounded)
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 8
        /// Горизонтальный отступ между капсулами в HStack
        static let spacing: CGFloat = 10
        static let cornerRadius: CGFloat = 22
        static let selectedShadow = AppButtonStyle.brandAccent.opacity(0.18)
        static let unselectedShadow = Color.clear
        static let shadowRadius: CGFloat = 5
        static let shadowYOffset: CGFloat = 2
    }

    // Стили и параметры для строки поиска (AppSearchBar) и анимации появления
    struct SearchBar {
        static let background = Color(.systemGray6)
        static let cornerRadius: CGFloat = 18
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 8
        static let iconColor = Color.secondary
        static let textColor = Color.primary
        static let font = Font.system(.body, design: .rounded)
        static let shadow = Color.black.opacity(0.05)
        static let shadowRadius: CGFloat = 3
        static let animation: Animation = .spring(response: 0.28, dampingFraction: 0.77, blendDuration: 0.25)
    }
}

// MARK: - ButtonStyle для чипсов (деликатный press-эффект)
enum FilterChipButtonStyle {
    struct Press: ButtonStyle {
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        
        func makeBody(configuration: Configuration) -> some View {
            let overlayColor: Color = (colorScheme == .dark)
            ? Color.white.opacity(AppButtonStyle.FilterChip.pressedOverlayOpacity)
            : Color.black.opacity(AppButtonStyle.FilterChip.pressedOverlayOpacity)
            
            return configuration.label
                .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
                .overlay(
                    Capsule()
                        .fill(overlayColor)
                        .opacity(configuration.isPressed ? 1 : 0)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.16), lineWidth: configuration.isPressed ? 1 : 0)
                )
                .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.88), value: configuration.isPressed)
        }
    }
}

// MARK: - ButtonStyle для "Поздравить" (деликатный press-эффект)
enum CongratulateButtonStyle {
    struct Press: ButtonStyle {
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.86), value: configuration.isPressed)
        }
    }
}

// MARK: - Универсальная Primary CTA (иконка+текст), единый стиль для всех крупных действий
struct PrimaryCTAButton: View {
    var title: String
    var systemImage: String?
    var price: Int? = nil
    var isLoading: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
            action()
        } label: {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: AppButtonStyle.Congratulate.iconSize, weight: .semibold))
                }
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)
                if let price {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 15, weight: .semibold))
                        Text("\(price)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.18)))
                }
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(AppButtonStyle.Congratulate.textColor)
            .padding(.horizontal, AppButtonStyle.Congratulate.horizontalPadding)
            .padding(.vertical, AppButtonStyle.Congratulate.verticalPadding)
            .frame(minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: AppButtonStyle.Congratulate.cornerRadius, style: .continuous)
                    .fill(AppButtonStyle.primaryFill())
                    .overlay(
                        RoundedRectangle(cornerRadius: AppButtonStyle.Congratulate.cornerRadius, style: .continuous)
                            .stroke(AppButtonStyle.primaryStroke(), lineWidth: 0.8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppButtonStyle.Congratulate.cornerRadius, style: .continuous)
                            .fill(AppButtonStyle.primaryGloss())
                    )
            )
            .shadow(color: AppButtonStyle.Congratulate.ambientShadow, radius: AppButtonStyle.Congratulate.ambientShadowRadius, y: 0)
            .shadow(color: AppButtonStyle.Congratulate.shadow, radius: AppButtonStyle.Congratulate.shadowRadius, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: AppButtonStyle.Congratulate.cornerRadius, style: .continuous))
            .accessibilityLabel(Text(title))
        }
        .buttonStyle(CongratulateButtonStyle.Press())
        .disabled(isLoading)
    }
}

// MARK: - Универсальная кнопка "Поздравить" (CTA) для экрана контактов/праздников
struct CongratulateButton: View {
    var title: String = String(localized: "button.congratulate", bundle: appBundle(), locale: appLocale())
    /// Стоимость действия в токенах (опционально). Если nil — бейдж не показывается.
    var price: Int? = nil
    /// Отображать загрузку: перекрытие и индикатор прогресса
    var isLoading: Bool = false
    var action: () -> Void

    var body: some View {
        PrimaryCTAButton(title: title, systemImage: "gift.fill", price: price, isLoading: isLoading, action: action)
    }
}

// Централизованная капитализация первой буквы для всех фильтр-кнопок и любых других UI-текстов, где это требуется.
// Рекомендуется использовать эту функцию во всех фильтр-кнопках для единообразного отображения текста с заглавной буквы.
extension String {
    /// Возвращает строку с заглавной первой буквой и остальными без изменений.
    func capitalizedFirstLetter() -> String {
        guard let first = self.first else { return self }
        return first.uppercased() + self.dropFirst()
    }
}
