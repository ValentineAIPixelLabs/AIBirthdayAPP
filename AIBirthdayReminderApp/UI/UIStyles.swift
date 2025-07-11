import SwiftUI

// Этот файл теперь содержит только ActionButtonStyle и вспомогательные view без дублирования стилей карточек. Все параметры карточек вынесены в CardStyle.swift.

struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.10 : 1)
            .opacity(configuration.isPressed ? 0.84 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

// MARK: - CardPresetView: универсальный контейнер карточки с эффектом стекла
struct CardPresetView<Content: View>: View {
    let content: () -> Content
    
    var body: some View {
        content()
    }
}
