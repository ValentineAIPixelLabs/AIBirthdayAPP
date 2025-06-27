import SwiftUI

struct UIConstants {
    static let cornerRadius: CGFloat = 20
    static let cardShadowColor = Color.black.opacity(0.13)
    static let cardShadowRadius: CGFloat = 10
    static let cardShadowX: CGFloat = 0
    static let cardShadowY: CGFloat = 4
    static let cardStrokeColor = Color.white.opacity(0.18)
    static let cardStrokeLineWidth: CGFloat = 1.2
}

// MARK: - Card Style для карточек и кнопок
extension View {
    func cardStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: UIConstants.cornerRadius, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: UIConstants.cornerRadius, style: .continuous)
                            .stroke(UIConstants.cardStrokeColor, lineWidth: UIConstants.cardStrokeLineWidth)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: UIConstants.cornerRadius, style: .continuous))
            .shadow(color: UIConstants.cardShadowColor, radius: UIConstants.cardShadowRadius, x: UIConstants.cardShadowX, y: UIConstants.cardShadowY)
    }
}

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
        HStack(alignment: .center, spacing: 16) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(UIConstants.cornerRadius)
        .shadow(color: UIConstants.cardShadowColor.opacity(0.6), radius: UIConstants.cardShadowRadius, x: UIConstants.cardShadowX, y: UIConstants.cardShadowY)
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .transition(.opacity.combined(with: .scale))
        .animation(.easeInOut(duration: 0.12), value: UUID())
    }
}
