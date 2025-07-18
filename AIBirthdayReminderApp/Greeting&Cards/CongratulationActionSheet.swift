import SwiftUI

struct CongratulationActionSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onGenerateText: () -> Void
    var onGenerateCard: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // УДАЛИЛИ Capsule (теперь будет только системная полоса)

            Text("Что вы хотите сгенерировать?")
                .font(.headline)
                .padding(.top, 10)

            Button(action: {
                onGenerateText()
            }) {
                HStack {
                    Image(systemName: "text.bubble.fill")
                    Text("Сгенерировать поздравление")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }

            Button(action: {
                onGenerateCard()
            }) {
                HStack {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                    Text("Сгенерировать открытку")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.pink.opacity(0.1))
                .cornerRadius(12)
            }

            Spacer()
        }
        .padding()
        .presentationDetents([.medium, .fraction(0.4)])
    }
}
