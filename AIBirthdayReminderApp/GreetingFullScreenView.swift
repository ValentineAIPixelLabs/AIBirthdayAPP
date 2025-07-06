import SwiftUI

struct GreetingFullScreenView: View {
    @Binding var isPresented: Bool
    @Binding var greetings: [String]
    let onDelete: (Int) -> Void
    let onSaveGreeting: (String) -> Void
    let contact: Contact?
    let apiKey: String
    let isTestMode: Bool

    @State private var localGreeting: String?
    @State private var isLoading: Bool = false
    @State private var showHistorySheet = false
    @State private var isCopyAlertPresented = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AppBackground()

            VStack(alignment: .leading, spacing: 0) {

                Text("Debug - isLoading: \(isLoading ? "true" : "false"), localGreeting: \(localGreeting ?? "nil"), errorMessage: \(errorMessage ?? "nil")")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()

                // TopBar
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

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        if isLoading {
                            HStack {
                                ProgressView("Генерация поздравления...")
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                        } else if let greeting = localGreeting, !greeting.isEmpty {
                            Text(greeting)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: Color.black.opacity(0.07), radius: 6, y: 2)
                                )
                                .padding(.horizontal, 16)
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .contextMenu {
                                    Button("Скопировать") {
                                        UIPasteboard.general.string = greeting
                                        isCopyAlertPresented = true
                                    }
                                    Button(role: .destructive) {
                                        onDelete(0)
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                        } else if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Text("Нажмите «Сгенерировать», чтобы получить поздравление")
                                .foregroundColor(.secondary)
                                .font(.body)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 16)
                    .animation(.easeInOut, value: localGreeting)
                }
                .padding(.bottom, 0)

                HStack(spacing: 16) {
                    Button(action: handleGenerate) {
                        Label("Сгенерировать", systemImage: "sparkles")
                            .font(.system(size: 17, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isLoading)
                    Button(action: { showHistorySheet = true }) {
                        Label("История", systemImage: "list.bullet.rectangle")
                            .font(.system(size: 17, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .padding(.top, 0)
        }
        .sheet(isPresented: $showHistorySheet) {
            GreetingsHistoryFullScreenView(isPresented: $showHistorySheet, greetings: $greetings)
                .onAppear {
                    debugPrint("Showing history sheet")
                }
        }
        .alert("Текст поздравления скопирован", isPresented: $isCopyAlertPresented) {
            Button("OK", role: .cancel) { }
        }
        .onAppear {
            if isCopyAlertPresented {
                debugPrint("Showing copy alert")
            }
        }
    }

    private func handleGenerate() {
        print("handleGenerate() called")
        errorMessage = nil
        localGreeting = nil
        guard !isLoading else { return }
        guard let contact = contact, !apiKey.isEmpty else {
            errorMessage = "Нет данных контакта или API-ключа."
            return
        }

        if isTestMode {
            localGreeting = "Тестовое поздравление! 🎉"
            onSaveGreeting("Тестовое поздравление! 🎉")
            return
        }

        isLoading = true
        ChatGPTService.shared.generateGreeting(for: contact, apiKey: apiKey) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let greeting):
                    print("Generation succeeded with greeting: \(greeting)")
                    self.localGreeting = greeting
                    self.onSaveGreeting(greeting)
                case .failure(let error):
                    print("Generation failed with error: \(error.localizedDescription)")
                    self.errorMessage = "Ошибка генерации: \(error.localizedDescription)"
                }
                self.isLoading = false
                print("isLoading set to false")
            }
        }
    }
}

// Пример Preview
struct GreetingFullScreenView_Previews: PreviewProvider {
    static var previews: some View {
        GreetingFullScreenView(
            isPresented: .constant(true),
            greetings: .constant([]),
            onDelete: { _ in },
            onSaveGreeting: { _ in },
            contact: nil,
            apiKey: "",
            isTestMode: false
        )
    }
}
