import Foundation
import SwiftUI

/// Единая точка для стилизации карточек (контактов, праздников и других).
struct CardStyle {
    // Размеры карточек
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 12
    static let cornerRadius: CGFloat = 20
    static let shadowRadius: CGFloat = 16
    static let shadowOpacity: Double = 0.18
    static let shadowYOffset: CGFloat = 12
    
    // Цвета
    // Для настоящего glass-эффекта рекомендуется использовать .background(.ultraThinMaterial) в SwiftUI-View карточки или overlay поверх backgroundColor.
    static let backgroundColor = Color.white.opacity(0.38)
    static let shadowColor = Color.black.opacity(shadowOpacity)
    static let borderColor = Color.gray.opacity(0.15)
    static let material: Material = .ultraThinMaterial
    static let translucentBackground = Color.white.opacity(0.16)
    
    // Отступы между карточками в списке
    static let cardSpacing: CGFloat = 12
    
    // Горизонтальные отступы для списков/экранов, где карточки выставляются по центру
    static let listHorizontalPadding: CGFloat = 20
    
    // Стили текста внутри карточки
    // ⚠️ Переход на системные стили шрифтов (Dynamic Type-friendly) согласно HIG 2025; избегаем фиксированных размеров.
    struct Title {
        static let font = Font.system(.headline, design: .rounded).weight(.semibold)
        static let color = Color.primary
    }
    struct Subtitle {
        static let font = Font.system(.subheadline, design: .rounded)
        static let color = Color.secondary
    }
    struct Extra {
        static let font = Font.system(.footnote, design: .rounded)
        static let color = Color.gray
    }

    // Шрифт эмодзи/иконки-аватарки внутри карточки (динамический, без фиксированных размеров)
    struct Emoji {
        static let font = Font.system(.title2)
    }

    // Шрифт заголовков на кнопках внутри карточек (например, "Поздравить")
    struct ButtonTitle {
        static let font = Font.system(.headline, design: .rounded).weight(.semibold)
    }
    
    // Параметры иконок (например, для кнопки "Поздравить" внутри карточки)
    struct Icon {
        static let size: CGFloat = 28
        static let color = Color.accentColor
    }
    
    // Единые отступы для CTA-кнопок внутри карточек (например, "Поздравить")
    struct CTA {
        /// Отступ над кнопкой (зазор между контентом карточки и кнопкой)
        static let topPadding: CGFloat = 14
        /// Отступ под кнопкой (зазор до нижнего края карточки)
        static let bottomPadding: CGFloat = 8
    }

    /// Дополнительные параметры для крупных карточек на детальных экранах (контакта, праздника).
    /// Используй эти параметры для карточек на экранах ContactDetailView и HolidayDetailView
    struct Detail {
        static let horizontalPadding: CGFloat = 24
        static let verticalPadding: CGFloat = 18
        static let spacing: CGFloat = 12
        static let iconSize: CGFloat = 24
        static let font = Font.system(.body, design: .rounded)
        static let innerHorizontalPadding: CGFloat = 16 // Внутренний горизонтальный отступ для содержимого внутри детальных карточек.
    }
    
    // Параметры аватара (единый размер и тень)
    struct Avatar {
        static let size: CGFloat = 64
        static let shadowRadius: CGFloat = 6
        static let shadowOpacity: Double = 0.18
        static let shadowYOffset: CGFloat = 2
        static let borderWidth: CGFloat = 0.5
        // Масштабы для крупного аватара в шапке
        static let headerScale: CGFloat = 2.5
        static let headerHaloExtraScale: CGFloat = 0.42
        // Коэффициенты шрифта для эмодзи и монограммы в шапке
        static let headerEmojiScale: CGFloat = 0.5
        static let headerInitialScale: CGFloat = 0.45
    }
}

// MARK: - Reusable Card Background (HIG 2025-friendly)
struct CardSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        // Shadow parameters tuned for readability and subtle depth
        let baseShadowOpacity = reduceTransparency ? 0.12 : CardStyle.shadowOpacity
        let shadowColor = Color.black.opacity(colorScheme == .dark ? baseShadowOpacity : baseShadowOpacity * 0.85)
        let shadowRadius = reduceTransparency ? 10.0 : Double(CardStyle.shadowRadius)
        let shadowYOffset = reduceTransparency ? 8.0 : Double(CardStyle.shadowYOffset)
        
        // Border adapts to Increased Contrast
        let borderWidth: CGFloat = (colorSchemeContrast == .increased) ? 1.0 : 0.5
        let borderColor: Color = {
            if colorSchemeContrast == .increased {
                return Color.primary.opacity(colorScheme == .dark ? 0.45 : 0.28)
            } else {
                return (colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.12))
            }
        }()
        
        return content
            .background {
                if reduceTransparency {
                    shape.fill(Color(.secondarySystemBackground))
                } else {
                    shape.fill(.thinMaterial)
                }
            }
            .clipShape(shape)
            .overlay(shape.stroke(borderColor, lineWidth: borderWidth))
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowYOffset)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: colorScheme)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: colorSchemeContrast)
    }
}

extension View {
    /// Применяет фирменный фон карточки с адаптивным материалом, бордером и тенью.
    func cardBackground(cornerRadius: CGFloat = CardStyle.cornerRadius) -> some View {
        self.modifier(CardSurfaceModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - ButtonStyle для карточек (аккуратный press-эффект)
enum CardButtonStyle {
    struct Press: ButtonStyle {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.colorScheme) private var colorScheme
        
        func makeBody(configuration: Configuration) -> some View {
            let shape = RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
            return configuration.label
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .overlay(
                    shape
                        .fill((colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)))
                        .opacity(configuration.isPressed ? 1 : 0)
                )
                .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.85), value: configuration.isPressed)
        }
    }
}

// MARK: - Avatar circle visuals (gradient + border) for card avatars
private struct AvatarCircleBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    func body(content: Content) -> some View {
        let gradient = LinearGradient(
            colors: colorScheme == .dark
                ? [Color.white.opacity(0.08), Color.white.opacity(0.16)]
                : [Color.white.opacity(0.85), Color.white.opacity(0.70)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let borderColor: Color = (colorScheme == .dark)
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.08)
        return content
            .background(
                Circle().fill(gradient)
            )
            .overlay(
                Circle().stroke(borderColor, lineWidth: CardStyle.Avatar.borderWidth)
            )
    }
}

private struct AvatarCircleBorderModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    func body(content: Content) -> some View {
        let borderColor: Color = (colorScheme == .dark)
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.08)
        return content
            .overlay(
                Circle().stroke(borderColor, lineWidth: CardStyle.Avatar.borderWidth)
            )
    }
}

extension View {
    /// Градиентный фон + деликатный бордер для кружка аватара (для emoji/инициала)
    func avatarCircleBackground() -> some View { self.modifier(AvatarCircleBackgroundModifier()) }
    /// Только бордер по контуру кружка (для фото-аватара)
    func avatarCircleBorder() -> some View { self.modifier(AvatarCircleBorderModifier()) }
}

extension View {
    /// Единый фрейм для аватаров (не привязывает форму — круг/прямоугольник задаётся в месте использования)
    func avatarFrame(size: CGFloat = CardStyle.Avatar.size) -> some View {
        self.frame(width: size, height: size)
    }
    /// Единая мягкая тень для аватаров (форма задаётся внешним clipShape)
    func avatarShadow() -> some View {
        self.shadow(color: Color.black.opacity(CardStyle.Avatar.shadowOpacity),
                    radius: CardStyle.Avatar.shadowRadius,
                    y: CardStyle.Avatar.shadowYOffset)
    }
}
