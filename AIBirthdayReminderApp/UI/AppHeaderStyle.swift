//
//  AppHeaderStyle.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 10.07.2025.
//

import Foundation
import SwiftUI

/// Стилизация top bar (верхней панели) на экранах приложения.
struct AppHeaderStyle {
    /// Отступ сверху (от safeArea)
    static let topPadding: CGFloat = 5
    /// Расстояние между action-кнопками в верхней шапке на всех экранах.
    static let buttonSpacing: CGFloat = 12
    /// Основная (рекомендуемая) высота top bar во всех экранах
    static let headerHeight: CGFloat = 60
    /// Горизонтальный паддинг top bar
    static let horizontalPadding: CGFloat = 20
    /// Фон top bar и под фильтрами/чипами идентичен TabBar
    static let backgroundMaterial: Material = .ultraThinMaterial
    /// Вертикальный отступ между TopBar и фильтрами/чипами на всех экранах
    static let filterChipsTopPadding: CGFloat = 12
    /// Вертикальный отступ снизу под фильтрами/чипами на всех экранах
    static let filterChipsBottomPadding: CGFloat = 12
    /// Вертикальный паддинг между областью с фильтрами/чипсами и началом списка карточек (унифицированный для всех экранов)
    static let listTopPaddingAfterChips: CGFloat = 16
    /// Вертикальный паддинг между областью фильтров/чипсов и текстом месяца над списком карточек
    static let monthLabelTopPadding: CGFloat = 10
}
