import SwiftUI

struct MonogramPickerView: View {
    @Binding var selectedMonogram: String?
    @Binding var color: Color

    @Environment(\.dismiss) var dismiss
    @State private var monogramInput: String = ""

    let colors: [Color] = [.blue, .red, .orange, .purple, .green, .gray, .mint, .cyan]

    var body: some View {
        VStack(spacing: 18) {
            Text("Выберите монограмму")
                .font(.title3.bold())
            TextField("A", text: $monogramInput)
                .font(.system(size: 44, weight: .bold))
                .multilineTextAlignment(.center)
                .frame(width: 80)
                .onChange(of: monogramInput) { _ in
                    // Берём только первую букву и делаем заглавной
                    if let first = monogramInput.first {
                        let capital = String(first).uppercased()
                        monogramInput = capital
                        selectedMonogram = capital
                    } else {
                        monogramInput = ""
                        selectedMonogram = nil
                    }
                }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(colors, id: \.self) { col in
                        Circle()
                            .fill(col)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(color == col ? 0.7 : 0), lineWidth: 3)
                            )
                            .onTapGesture { color = col }
                    }
                }
            }
            Button("Готово") {
                if !monogramInput.isEmpty {
                    selectedMonogram = String(monogramInput.first!).uppercased()
                }
                dismiss()
            }
            .disabled(monogramInput.isEmpty)
        }
        .padding(40)
    }
}
