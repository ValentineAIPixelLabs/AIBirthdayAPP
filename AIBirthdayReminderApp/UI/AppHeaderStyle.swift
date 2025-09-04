import Foundation
import SwiftUI

/// Стилизация top bar (верхней панели) на экранах приложения.
struct AppHeaderStyle {
    /// Отступ сверху (от safeArea)
    static let topPadding: CGFloat = 5
    /// Расстояние между action-кнопками в верхней шапке на всех экранах.
    static let buttonSpacing: CGFloat = 12
    /// Основная (рекомендуемая) высота top bar во всех экранах
    static let headerHeight: CGFloat = 56
    /// Горизонтальный паддинг top bar
    static let horizontalPadding: CGFloat = 16
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

    /// Минимальный размер тач-таргета для кнопок в топбаре (HIG)
    static let minHitSize: CGFloat = 44
    /// Порог прокрутки, после которого показываем разделитель под топбаром
    static let scrollSeparatorThreshold: CGFloat = 2
    /// Прозрачность разделителя под топбаром в зависимости от прокрутки
    static func separatorOpacity(scrollOffset: CGFloat) -> Double {
        return scrollOffset > scrollSeparatorThreshold ? 1.0 : 0.0
    }
}

/// Универсальный контейнер верхней панели, соответствующий HIG 2025:
/// - Материал: ultraThinMaterial
/// - Разделитель при скролле
/// - Доступность: роль "header", крупные тач-таргеты
struct AppHeaderTopBar<Content: View>: View {
    let isScrolled: Bool
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(Color.clear)
                .background(AppHeaderStyle.backgroundMaterial)
                .overlay(Divider().opacity(isScrolled ? 1 : 0), alignment: .bottom)
            
            HStack(spacing: AppHeaderStyle.buttonSpacing) {
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, AppHeaderStyle.horizontalPadding)
            .frame(height: AppHeaderStyle.headerHeight)
            .contentShape(Rectangle())
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isHeader)
        }
    }
}

extension View {
    /// Применяет материал к системной навбару (на случай экранов на NavigationStack)
    func appNavigationBarMaterial() -> some View {
        self
            .toolbarBackground(AppHeaderStyle.backgroundMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
    
    /// Гарантирует минимальный размер тач-таргета для элементов управления в топбаре
    func appMinHitTarget() -> some View {
        self
            .frame(minWidth: AppHeaderStyle.minHitSize, minHeight: AppHeaderStyle.minHitSize)
            .contentShape(Rectangle())
    }
}
