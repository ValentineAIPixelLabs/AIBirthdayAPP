// Централизованный стиль для карточек. Используй параметры этого файла на всех экранах, где есть карточки.
//
//  CardStyle.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 10.07.2025.
//

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
    
    // Стили текста внутри карточки
    struct Title {
        static let font = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let color = Color.primary
    }
    struct Subtitle {
        static let font = Font.system(size: 14, weight: .regular, design: .rounded)
        static let color = Color.secondary
    }
    struct Extra {
        static let font = Font.system(size: 12, weight: .medium, design: .rounded)
        static let color = Color.gray
    }
    
    // Параметры иконок (например, для кнопки "Поздравить" внутри карточки)
    struct Icon {
        static let size: CGFloat = 28
        static let color = Color.accentColor
    }

    /// Дополнительные параметры для крупных карточек на детальных экранах (контакта, праздника).
    /// Используй эти параметры для карточек на экранах ContactDetailView и HolidayDetailView
    struct Detail {
        static let horizontalPadding: CGFloat = 24
        static let verticalPadding: CGFloat = 18
        static let spacing: CGFloat = 12
        static let iconSize: CGFloat = 24
        static let font = Font.system(size: 16, weight: .medium, design: .rounded)
        static let innerHorizontalPadding: CGFloat = 16 // Внутренний горизонтальный отступ для содержимого внутри детальных карточек.
    }
}
