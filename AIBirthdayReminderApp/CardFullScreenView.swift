import SwiftUI

struct CardFullScreenView: View {
    @Binding var isPresented: Bool
    @Binding var cards: [URL]
    let onDelete: (Int) -> Void
    let onSaveCard: (URL) -> Void
    let contact: Contact?
    let apiKey: String
    let isTestMode: Bool

    @State private var localImageURL: URL?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showHistorySheet = false
    @State private var showCopyAnimation = false
    @State private var isCopyAlertPresented = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack {
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

                Spacer()

                if isLoading {
                    ProgressView("Генерация открытки...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let url = localImageURL {
                    ScrollView {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            case .success(let image):
                                VStack {
                                    ZStack {
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                            .background(
                                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                    .fill(.ultraThinMaterial)
                                                    .shadow(color: Color.black.opacity(0.07), radius: 8, y: 2)
                                            )
                                            .padding()
                                            .gesture(
                                                LongPressGesture()
                                                    .onEnded { _ in
                                                        withAnimation {
                                                            copyImage(url: url, image: image)
                                                        }
                                                    }
                                            )
                                        if showCopyAnimation {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 60))
                                                .foregroundColor(.green)
                                                .transition(.scale.combined(with: .opacity))
                                        }
                                    }
                                    // --- Кнопки "Скопировать" и "Поделиться"
                                    Button(action: {
                                        copyImage(url: url, image: image)
                                    }) {
                                        Label("Скопировать", systemImage: "doc.on.doc")
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.blue.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                    .padding(.horizontal)

                                    Button(action: {
                                        shareImage(url: url)
                                    }) {
                                        Label("Поделиться", systemImage: "square.and.arrow.up")
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.green.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                    .padding(.horizontal)
                                    .padding(.bottom)
                                }
                            case .failure:
                                Text("Ошибка загрузки изображения")
                                    .foregroundColor(.red)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .padding()
                    }
                    .padding(.top, 32)
                } else {
                    Text("Нажмите «Сгенерировать», чтобы получить открытку")
                        .foregroundColor(.secondary)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Spacer()

                HStack(spacing: 16) {
                    Button(action: handleGenerate) {
                        Label("Сгенерировать", systemImage: "wand.and.stars")
                            .font(.system(size: 17, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isLoading)
                    Button(action: { showHistorySheet = true }) {
                        Label("История", systemImage: "photo.stack")
                            .font(.system(size: 17, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }

            if showCopyAnimation {
                VStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                        .padding(.bottom, 40)
                }
                .animation(.easeInOut, value: showCopyAnimation)
            }
        }
        .sheet(isPresented: $showHistorySheet) {
            if let contact {
                CardsHistoryFullScreenView(isPresented: $showHistorySheet, contactId: contact.id)
            }
        }
        .alert("Открытка скопирована", isPresented: $isCopyAlertPresented) {
            Button("OK", role: .cancel) {}
        }
    }

    private func handleGenerate() {
        errorMessage = nil
        localImageURL = nil
        guard !isLoading else { return }
        guard let contact = contact, !apiKey.isEmpty else {
            errorMessage = "Нет данных контакта или API-ключа."
            return
        }

        if isTestMode {
            if let testImage = UIImage(systemName: "photo") {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_card.png")
                try? testImage.pngData()?.write(to: tempURL)
                localImageURL = tempURL
                onSaveCard(tempURL)
            }
            return
        }

        isLoading = true
        ChatGPTService.shared.generateCard(for: contact, apiKey: apiKey) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    self.localImageURL = url
                    self.onSaveCard(url)
                case .failure(let error):
                    self.errorMessage = "Ошибка генерации открытки: \(error.localizedDescription)"
                }
                self.isLoading = false
            }
        }
    }

    private func copyImage(url: URL, image: Image) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let uiImage = UIImage(data: data) {
                UIPasteboard.general.image = uiImage
                DispatchQueue.main.async {
                    withAnimation {
                        showCopyAnimation = true
                        isCopyAlertPresented = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            showCopyAnimation = false
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    withAnimation {
                        showCopyAnimation = true
                        isCopyAlertPresented = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            showCopyAnimation = false
                        }
                    }
                }
            }
        }.resume()
    }

    private func shareImage(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true, completion: nil)
        }
    }
}
