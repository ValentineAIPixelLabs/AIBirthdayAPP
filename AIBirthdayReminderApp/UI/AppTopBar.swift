import SwiftUI

struct AppTopBar: View {
    let title: String
    let leftButtons: [AnyView]
    let rightButtons: [AnyView]
    
    // Centralized background material for the top bar
    //static let barBackgroundMaterial: Material = .ultraThinMaterial
    
    var body: some View {
        HStack {
            // Левая часть (например, кнопка "Назад" или меню)
            HStack(spacing: AppHeaderStyle.buttonSpacing) {
                ForEach(leftButtons.indices, id: \.self) { i in
                    leftButtons[i]
                }
            }
            // Заголовок
            Spacer(minLength: 8)
            Text(title)
                .font(.title2).bold()
                .foregroundColor(.primary)
            Spacer(minLength: 8)
            // Правая часть (основные action-кнопки)
            HStack(spacing: AppHeaderStyle.buttonSpacing) {
                ForEach(rightButtons.indices, id: \.self) { i in
                    rightButtons[i]
                }
            }
        }
        .frame(height: AppHeaderStyle.headerHeight)
        .padding(.top, AppHeaderStyle.topPadding)
        .padding(.horizontal, AppHeaderStyle.horizontalPadding)
        //.background(Self.barBackgroundMaterial)
       // .background(Color.white.opacity(0.20))
    }
}
