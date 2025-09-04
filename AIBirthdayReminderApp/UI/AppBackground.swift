import SwiftUI

/// Фирменный бэкграунд приложения (повышенный контраст).
/// Адаптация под: Light/Dark, Increased Contrast, Reduce Transparency / Motion.
struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Group {
            if reduceTransparency {
                Color(.systemBackground)
            } else {
                baseGradient
                    // Мягкий «световой» акцент сверху
                    .overlay(radialHighlight.opacity(highlightOpacity))
                    // Лёгкая виньетка для локального увеличения контраста и читаемости
                    .overlay(vignetteOverlay)
            }
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: colorScheme)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: colorSchemeContrast)
    }
}

// MARK: - Layers

private extension AppBackground {
    var baseGradient: some View {
        LinearGradient(gradient: Gradient(stops: gradientStops),
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }
    
    var radialHighlight: some View {
        RadialGradient(gradient: Gradient(colors: [
            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.16),
            .clear
        ]), center: .top, startRadius: 0, endRadius: 420)
        .blendMode(.softLight)
    }
    
    /// Лёгкая вертикальная виньетка: подчёркивает контент, не «съедая» цвет.
    var vignetteOverlay: some View {
        let top = colorScheme == .dark ? 0.06 : 0.03
        let bottom = colorScheme == .dark ? 0.10 : 0.05
        return LinearGradient(colors: [
            Color.black.opacity(top),
            Color.black.opacity(bottom)
        ], startPoint: .top, endPoint: .bottom)
        .allowsHitTesting(false)
    }
}

// MARK: - Tokens

private extension AppBackground {
    /// Дополнительный коэффициент контраста поверх базовых значений
    var contrastGain: Double {
        0.08 + (colorSchemeContrast == .increased ? 0.06 : 0.0)
    }
    
    var gradientStops: [Gradient.Stop] {
        // Тёплая палитра: Electric Magenta → Coral → Amber
        // Непрозрачность усиливается при Increased Contrast
        let gain: Double = contrastGain
        func alpha(_ base: Double) -> Double { max(0.02, min(0.50, base + gain)) }

        if colorScheme == .dark {
            // DARK: глубже и насыщеннее
            let magenta = Color(.sRGB,
                                red: 0.82, green: 0.28, blue: 1.00,
                                opacity: alpha(0.22))   // #D149FF
            let coral   = Color(.sRGB,
                                red: 1.00, green: 0.40, blue: 0.45,
                                opacity: alpha(0.20))   // #FF6673
            let amber   = Color(.sRGB,
                                red: 1.00, green: 0.68, blue: 0.20,
                                opacity: alpha(0.18))   // #FFAD33
            return [
                .init(color: magenta, location: 0.0),
                .init(color: coral,   location: 0.45),
                .init(color: amber,   location: 1.0)
            ]
        } else {
            // LIGHT: светлее, но всё ещё выразительно
            let pink    = Color(.sRGB,
                                red: 1.00, green: 0.62, blue: 0.90,
                                opacity: alpha(0.18))   // #FF9EE6
            let peach   = Color(.sRGB,
                                red: 1.00, green: 0.74, blue: 0.50,
                                opacity: alpha(0.20))   // #FFBC80
            let apricot = Color(.sRGB,
                                red: 1.00, green: 0.56, blue: 0.43,
                                opacity: alpha(0.18))   // #FF8F6E
            return [
                .init(color: pink,    location: 0.0),
                .init(color: peach,   location: 0.45),
                .init(color: apricot, location: 1.0)
            ]
        }
    }
    
    var highlightOpacity: Double {
        (colorSchemeContrast == .increased) ? 0.95 : 0.85
    }
}
