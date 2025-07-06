import SwiftUI

struct GreetingsHistoryFullScreenView: View {
    @Binding var isPresented: Bool
    @Binding var greetings: [String]

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(greetings.enumerated()), id: \.offset) { idx, greeting in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(greeting)
                                .font(.body)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(18)
                        .shadow(color: Color.black.opacity(0.07), radius: 6, y: 2)
                        .contextMenu {
                            Button("Скопировать") {
                                UIPasteboard.general.string = greeting
                            }
                            Button("Удалить", role: .destructive) {
                                greetings.remove(at: idx)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                }
                .padding(.top, 80)
                .padding(.bottom, 20)
            }
        }
        .overlay(alignment: .topLeading) {
            HStack {
                Button(action: { isPresented = false }) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
        }
    }
}
