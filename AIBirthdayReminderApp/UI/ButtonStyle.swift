// Централизованный стиль для всех кастомных кнопок. Используй параметры этого файла на всех экранах, где есть кнопки.
//
//  ButtonStyle.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 10.07.2025.
//

import Foundation
import SwiftUI

/// Централизованные стили для всех кастомных кнопок приложения.
/// Используй параметры этого файла для любых кнопок (в том числе "Поздравить", FAB и пр.).
struct AppButtonStyle {
    // Основные параметры (универсальные)
    static let cornerRadius: CGFloat = 16
    static let horizontalPadding: CGFloat = 20
    static let verticalPadding: CGFloat = 12
    static let height: CGFloat = 44
    static let iconSize: CGFloat = 22
    
    // Основная кнопка (Primary)
    struct Primary {
        static let backgroundColor = Color.accentColor
        static let textColor = Color.white
        static let font = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let shadow = Color.black.opacity(0.10)
        static let shadowRadius: CGFloat = 4
    }
    
    // Второстепенная кнопка (Secondary)
    struct Secondary {
        static let backgroundColor = Color.gray.opacity(0.13)
        static let textColor = Color.accentColor
        static let font = Font.system(size: 17, weight: .regular, design: .rounded)
        static let shadow = Color.clear
        static let borderColor = Color.accentColor.opacity(0.19)
        static let borderWidth: CGFloat = 1
    }
    
    // Круглая кнопка (для иконок)
    struct Circular {
        static let diameter: CGFloat = 44
        static let backgroundColor = Color.accentColor.opacity(0.14)
        static let iconColor = Color.accentColor
        static let iconSize: CGFloat = 20
        static let shadow = Color.black.opacity(0.07)
        static let shadowRadius: CGFloat = 2
    }
    
    // Кнопка "Поздравить" (для карточки контакта/праздника)
    struct Congratulate {
        static let backgroundColor = Color.accentColor
        static let textColor = Color.white
        static let font = Font.system(size: 16, weight: .bold, design: .rounded)
        static let horizontalPadding: CGFloat = 30
        static let verticalPadding: CGFloat = 12
        static let cornerRadius: CGFloat = 14
        static let iconSize: CGFloat = 18
        static let shadow = Color.accentColor.opacity(0.19)
        static let shadowRadius: CGFloat = 6
    }
    // Стили для фильтр-кнопок (капсул) в списках и фильтрах
    struct FilterChip {
        static let selectedBackground = Color.accentColor
        static let unselectedBackground = Color(.systemGray6)
        static let selectedText = Color.white
        static let unselectedText = Color.primary
        static let font = Font.subheadline
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 8
        static let cornerRadius: CGFloat = 22
        static let selectedShadow = Color.accentColor.opacity(0.18)
        static let unselectedShadow = Color.clear
        static let shadowRadius: CGFloat = 4
        static let shadowYOffset: CGFloat = 1
    }

    // Стили и параметры для строки поиска (AppSearchBar) и анимации появления
    struct SearchBar {
        static let background = Color(.systemGray6)
        static let cornerRadius: CGFloat = 18
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 8
        static let iconColor = Color.secondary
        static let textColor = Color.primary
        static let font = Font.system(size: 17, weight: .regular, design: .rounded)
        static let shadow = Color.black.opacity(0.05)
        static let shadowRadius: CGFloat = 3
        static let animation: Animation = .spring(response: 0.28, dampingFraction: 0.77, blendDuration: 0.25)
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
