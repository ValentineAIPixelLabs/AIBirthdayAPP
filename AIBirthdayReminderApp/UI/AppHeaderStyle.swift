//
//  AppHeaderStyle.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 10.07.2025.
//

import Foundation
import SwiftUI

/// Централизованные стили и размеры для верхней «шапки» (header) на экранах приложения.
struct AppHeaderStyle {
    /// Минимальная высота header
    static let minHeight: CGFloat = 84
    /// Максимальная высота header (например, для анимаций)
    static let maxHeight: CGFloat = 144
    /// Отступ сверху (от safeArea)
    static let topPadding: CGFloat = 5
    /// Внутренний вертикальный паддинг между аватаркой/заголовком и границей шапки
    static let verticalPadding: CGFloat = 16
    /// Радиус скругления для header (если нужен эффект карточки)
    static let cornerRadius: CGFloat = 28
    /// Расстояние между action-кнопками в верхней шапке на всех экранах.
    static let buttonSpacing: CGFloat = 12
}
