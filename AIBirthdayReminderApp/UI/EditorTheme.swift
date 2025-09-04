import SwiftUI

/// Общая тема для экранов редактирования (контакта и праздника).
enum EditorTheme {
    // Высота шапки с аватаром
    static let headerHeight: CGFloat = 140
    // Тонкая подстройка отступов секции с аватаром внутри Form,
    // чтобы визуально совпасть с EditContactView.
    static let sectionHeaderTopPadding: CGFloat = 0
    static let sectionHeaderBottomPadding: CGFloat = 8
    static let detailHeaderTop: CGFloat = 20
    static let detailHeaderSpacing: CGFloat = 10
    static let detailHorizontalPadding: CGFloat = 16

    // Единая ширина контентной колонки на деталях
    static let detailMaxWidth: CGFloat = 500
    // Паддинги верхней панели (кнопки Назад/Править)
    static let topBarTopPadding: CGFloat = 8
    static let topBarHorizontalPadding: CGFloat = 16

    // Единые инкеты и фон рядов (когда нужно)
    static let rowInsets = EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
    static var rowBackground: Color { Color(.secondarySystemGroupedBackground) }

    // Фон экрана редактора. Держим нейтральный системный,
    // как в EditContactView (без выраженного градиента).
    @ViewBuilder
    static var background: some View {
        LinearGradient(
            colors: [Color(.systemGroupedBackground), Color(.systemGroupedBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // Вычисление верхнего отступа контента на деталях с учётом safe area и кнопок топ-бара
    static func detailContentTopPadding(safeTop: CGFloat) -> CGFloat {
        safeTop + topBarTopPadding + AppButtonStyle.Circular.diameter + detailHeaderTop
    }

    static func detailContentTopPadding(for geo: GeometryProxy) -> CGFloat {
        detailContentTopPadding(safeTop: geo.safeAreaInsets.top)
    }
}
