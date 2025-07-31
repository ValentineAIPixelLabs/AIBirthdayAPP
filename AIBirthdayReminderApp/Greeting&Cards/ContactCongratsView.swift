import UIKit
import SwiftUI


struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Congrats Style Enum
enum CongratsStyle: String, CaseIterable, Identifiable {
    case classic = "Классика"
    case funny = "Смешное"
    case poetic = "Поэтичное"
    var id: String { rawValue }
}

// MARK: - ScrollOffsetPreferenceKey
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Main View
struct ContactCongratsView: View {
    enum LoadingType {
        case image, prompt
    }
    @Environment(\.dismiss) private var dismiss
    @Binding var contact: Contact
    @State private var cardHistory: [CardHistoryItemWithImage] = []
    @State private var congratsHistory: [CongratsHistoryItem] = []
    @State private var selectedStyle: CongratsStyle = .classic
    @State private var isLoading: Bool = false
    @State private var alertMessage: String? = nil
    @State private var headerVisible: Bool = true
    @State private var selectedMode: String
    @State private var showCongratsPopup = false
    @State private var congratsPopupMessage: String?
    @State private var showShareSheet = false
    @State private var shareText: String?
    // Card popup states
    @State private var showCardPopup = false
    @State private var cardPopupImage: UIImage?
    @State private var cardPopupUrl: URL?
    @State private var showCardShareSheet = false

    @State private var fakeProgress: Double = 0
    @State private var progressTimer: Timer? = nil
    @State private var loadingType: LoadingType? = nil

    init(contact: Binding<Contact>, selectedMode: String) {
        self._contact = contact
        self.selectedMode = selectedMode
        _selectedMode = State(initialValue: selectedMode)
    }


    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                // Fixed Top Bar
            AppTopBar(
                title: "",
                leftButtons: [
                    AnyView(
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.backward")
                                .font(.system(size: 22, weight: .bold))
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color(.systemGray6)))
                                .shadow(radius: 2)
                        }
                    )
                ],
                rightButtons: [
                    AnyView(
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 15, weight: .semibold))
                            Text("100")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color(.systemGray6)))
                        .shadow(radius: 2)
                    )
                ]
            )
                // Scrollable Content
                ScrollView {
                    VStack(spacing: 0) {
                        mainContent()
                    }
                    .padding(.top, 8)
                }
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .gesture(
            DragGesture().onChanged { _ in
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        )
        .onAppear {
            cardHistory = CardHistoryManager.getCards(for: contact.id)
            congratsHistory = CongratsHistoryManager.getCongrats(for: contact.id)
            CardHistoryManager.logTotalCardImagesSize(for: contact.id)
        }
        .overlay(
            Group {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.2).ignoresSafeArea()
                        if loadingType == .image {
                            VStack(spacing: 16) {
                                ProgressView(value: fakeProgress)
                                    .progressViewStyle(LinearProgressViewStyle())
                                    .frame(width: 200)
                                Text("Генерация открытки... \(Int(fakeProgress * 100))%")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(14)
                        } else if loadingType == .prompt {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Генерируем идею открытки...")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(14)
                        }
                    }
                }
            }
        )
        .alert(isPresented: Binding<Bool>(
            get: { alertMessage != nil },
            set: { _ in alertMessage = nil }
        )) {
            Alert(
                title: Text("Ошибка"),
                message: Text(alertMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        // Popup overlay for CongratsResultPopup
        .overlay(
            Group {
                if showCongratsPopup, let message = congratsPopupMessage {
                    Color.black.opacity(0.18).ignoresSafeArea()
                        .onTapGesture { showCongratsPopup = false }
                    CongratsResultPopup(
                        message: message,
                        onCopy: {
                            UIPasteboard.general.string = message
                        },
                        onShare: {
                            shareText = message
                            showShareSheet = true
                        },
                        onClose: {
                            showCongratsPopup = false
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(99)
                }
            }
        )
        .sheet(isPresented: $showShareSheet) {
            if let shareText = shareText {
                ActivityViewController(activityItems: [shareText])
            }
        }
        // Popup overlay for CardResultPopup
        .overlay(
            Group {
                if showCardPopup, let image = cardPopupImage {
                    ZStack {
                        Color.black.opacity(0.18).ignoresSafeArea()
                            .onTapGesture { showCardPopup = false }
                        CardResultPopup(
                            image: image,
                            onCopy: {
                                UIPasteboard.general.image = image
                            },
                            onShare: {
                                showCardShareSheet = true
                            },
                            onSave: {
                                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                            },
                            onClose: {
                                showCardPopup = false
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).ignoresSafeArea())
                        .transition(.opacity)
                        .zIndex(99)
                    }
                }
            }
        )
        .sheet(isPresented: $showCardShareSheet) {
            if let image = cardPopupImage {
                ActivityViewController(activityItems: [image])
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Main Content Extraction
    @ViewBuilder
    private func mainContent() -> some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                contactBlock(contact: contact)
            }
            .frame(maxWidth: 500)
            .padding(.horizontal, 16)
            .padding(.top, 15)

            // --- Новый UI только для режима "card" ---
            if selectedMode == "card" {
                CardGenerationSection(
                    referenceImage: $referenceImage,
                    showImagePicker: $showImagePicker,
                    prompt: $prompt,
                    promptCharLimit: promptCharLimit,
                    selectedCardStyle: $selectedCardStyle,
                    selectedAspectRatio: $selectedAspectRatio,
                    selectedQuality: $selectedQuality,
                    onGeneratePrompt: generateCreativePrompt,
                    onRemoveReferenceImage: {
                        referenceImage = nil
                    }
                )
            }

            generateButtons()

            // History Sections
            historySection()
        }
    }

    // MARK: - History Section Extraction
    @ViewBuilder
    private func historySection() -> some View {
        VStack(spacing: 24) {
            if selectedMode == "text" {
                ContactCongratsHistorySection(
                    congratsHistory: congratsHistory,
                    onDelete: { item in
                        if let idx = congratsHistory.firstIndex(where: { $0.id == item.id }) {
                            congratsHistory.remove(at: idx)
                            CongratsHistoryManager.deleteCongrats(item.id)
                            congratsHistory = CongratsHistoryManager.getCongrats(for: contact.id)
                        }
                    },
                    onShowPopup: { message in
                        congratsPopupMessage = message
                        showCongratsPopup = true
                    }
                )
                // Здесь появятся настройки генерации поздравления и popup результата
            }
            if selectedMode == "card" {
                CardHistorySection(cardHistory: $cardHistory, contactId: contact.id, onShowPopup: { image in
                    cardPopupImage = image
                    showCardPopup = true
                })
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 32)
    }


    // MARK: - Generate Buttons
    private func generateButtons() -> some View {
        HStack(spacing: 16) {
            if selectedMode == "text" {
                Button(action: {
                    isLoading = true
                    let apiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
                    ChatGPTService.shared.generateGreeting(for: contact, apiKey: apiKey) { result in
                        DispatchQueue.main.async {
                            isLoading = false
                            switch result {
                            case .success(let text):
                                let newCongrats = CongratsHistoryItem(date: Date(), message: text)
                                congratsHistory.append(newCongrats)
                                if let last = congratsHistory.last {
                                    CongratsHistoryManager.addCongrats(item: last, for: contact.id)
                                }
                                congratsPopupMessage = text
                                showCongratsPopup = true
                            case .failure(let error):
                                alertMessage = error.localizedDescription
                            }
                        }
                    }
                }) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 24)
                        Text("Сгенерировать\nпоздравление")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .padding(.vertical, 6)
                    .padding(.leading, 12)
                    .background(
                        RoundedRectangle(cornerRadius: AppButtonStyle.Congratulate.cornerRadius, style: .continuous)
                            .fill(AppButtonStyle.Congratulate.backgroundColor)
                            .shadow(color: AppButtonStyle.Congratulate.shadow, radius: AppButtonStyle.Congratulate.shadowRadius, y: 2)
                    )
                }
                .buttonStyle(.plain)
                .opacity(isLoading ? 0.6 : 1)
                .disabled(isLoading)
            } else if selectedMode == "card" {
                Button(action: handleGenerate) {
                    HStack(spacing: 10) {
                        Spacer()
                        Text("Сгенерировать открытку")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(maxHeight: .infinity)
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 15, weight: .semibold))
                            Text("25")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(.systemYellow).opacity(0.14)))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: AppButtonStyle.Congratulate.cornerRadius, style: .continuous)
                            .fill(AppButtonStyle.Congratulate.backgroundColor)
                            .shadow(color: AppButtonStyle.Congratulate.shadow, radius: AppButtonStyle.Congratulate.shadowRadius, y: 2)
                    )
                }
                .buttonStyle(.plain)
                .opacity(
                    isLoading ||
                    prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    prompt.count > promptCharLimit
                    ? 0.6 : 1
                )
                .disabled(
                    isLoading ||
                    prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    prompt.count > promptCharLimit
                )
            }
        }
        .padding(.horizontal)
    }
        
    // MARK: - Card Generation State & Handlers
    @State private var referenceImage: UIImage? = nil
    @State private var showImagePicker: Bool = false
    @State private var prompt: String = ""
    private let promptCharLimit: Int = 1000
    @State private var selectedCardStyle: CardVisualStyle = .none
    @State private var selectedAspectRatio: CardAspectRatio = .square
    @State private var selectedQuality: CardQuality = .medium

    private func handleGenerate() {
        // Заглушка: логика передачи referenceImage, prompt, selectedCardStyle, selectedAspectRatio, selectedQuality
        alertMessage = nil
        guard !isLoading else { return }
        let apiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        guard !apiKey.isEmpty else {
            alertMessage = "Нет данных контакта или API-ключа."
            resetCardGenerationSettings()
            return
        }
        loadingType = .image
        // Start fake progress
        let maxSeconds = 120.0 // 2 минуты
        let tick: Double = 0.6
        fakeProgress = 0
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: tick, repeats: true) { _ in
            withAnimation {
                let step = (0.98 * tick) / maxSeconds
                if fakeProgress < 0.98 {
                    fakeProgress += step
                }
            }
        }
        isLoading = true
        // Заглушка: можно передать параметры в сервис генерации открыток
        ChatGPTService.shared.generateCard(
            for: contact,
            prompt: {
                let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                let styleSuffix = selectedCardStyle.promptSuffix
                if !styleSuffix.isEmpty {
                    return trimmedPrompt.isEmpty ? styleSuffix : "\(trimmedPrompt)\n\n\(styleSuffix)"
                } else {
                    return trimmedPrompt
                }
            }(),
            apiKey: apiKey,
            quality: {
                switch selectedQuality {
                    case .low: return "low"
                    case .medium: return "medium"
                    case .high: return "high"
                }
            }(),
            referenceImage: referenceImage,
            size: selectedAspectRatio.apiValue
        ) {
            print("📥 Открытка успешно сохранена, загружаем историю")
            DispatchQueue.main.async {
                cardHistory = CardHistoryManager.getCards(for: contact.id)
                print("📊 История открыток после генерации: \(cardHistory.count) шт.")
                if let latest = cardHistory.first, let image = latest.image {
                    cardPopupImage = image
                    showCardPopup = true
                }
                isLoading = false
                loadingType = nil
                progressTimer?.invalidate()
                fakeProgress = 1
                resetCardGenerationSettings()
            }
        }
    }

    // MARK: - Card Generation Settings Reset
    private func resetCardGenerationSettings() {
        prompt = ""
        referenceImage = nil
        selectedCardStyle = .none
        selectedAspectRatio = .square
        selectedQuality = .medium
        showImagePicker = false
        fakeProgress = 0
        progressTimer?.invalidate()
    }

    private func generateCreativePrompt() {
        let apiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        guard !apiKey.isEmpty else {
            alertMessage = "Не найден API-ключ для генерации промта."
            return
        }
        loadingType = .prompt
        isLoading = true
        ChatGPTService.shared.generateCreativePrompt(for: contact, apiKey: apiKey) { result in
            DispatchQueue.main.async {
                isLoading = false
                loadingType = nil
                switch result {
                case .success(let creativePrompt):
                    prompt = creativePrompt
                case .failure(let error):
                    alertMessage = "Ошибка генерации промта: \(error.localizedDescription)"
                }
            }
        }
    }


   
}

// MARK: - ContactCongratsHistorySection
private struct ContactCongratsHistorySection: View {
    let congratsHistory: [CongratsHistoryItem]
    let onDelete: (CongratsHistoryItem) -> Void
    let onShowPopup: (String) -> Void

    var body: some View {
        Section {
            CardPresetView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Поздравления")
                        .font(.headline)
                        .padding(.bottom, 4)
                    if congratsHistory.isEmpty {
                        Text("Нет поздравлений")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    } else {
                        ForEach(congratsHistory) { item in
                            CongratsHistoryItemView(
                                item: item,
                                onDelete: { onDelete(item) },
                                onShowPopup: { onShowPopup(item.message) }
                            )
                        }
                    }
                }
                .padding()
            }
        }
    }
}

private struct CongratsHistoryItemView: View {
    let item: CongratsHistoryItem
    let onDelete: () -> Void
    let onShowPopup: () -> Void
    @State private var alertMessage: String? = nil
    @State private var isShareSheetPresented = false
    @State private var sharingText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.message)
                .font(.body)
                .foregroundColor(.primary)
            Text(item.date, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        .padding()
        .onTapGesture {
            onShowPopup()
        }
        .background(
            RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                .fill(CardStyle.backgroundColor)
                .shadow(color: CardStyle.shadowColor, radius: CardStyle.shadowRadius, y: CardStyle.shadowYOffset)
                .overlay(
                    RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                        .stroke(CardStyle.borderColor, lineWidth: 0.7)
                )
        )
        .contextMenu {
            Button {
                UIPasteboard.general.string = item.message
            } label: {
                Label("Копировать", systemImage: "doc.on.doc")
            }
            Button {
                sharingText = item.message
                isShareSheetPresented = true
            } label: {
                Label("Поделиться", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
        .alert(isPresented: Binding<Bool>(
            get: { alertMessage != nil },
            set: { _ in alertMessage = nil }
        )) {
            Alert(
                title: Text("Ошибка"),
                message: Text(alertMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $isShareSheetPresented) {
            if let sharingText = sharingText {
                ActivityViewController(activityItems: [sharingText])
            }
        }
        Divider()
    }
}
// MARK: - Contact Block
private func contactBlock(contact: Contact) -> some View {
    Group {
            HStack(alignment: .top, spacing: 12) {
                Text("День рождения: " + contact.name)
                    .font(CardStyle.Detail.font)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, CardStyle.Detail.verticalPadding)
            .padding(.horizontal, CardStyle.Detail.innerHorizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                    .fill(CardStyle.backgroundColor)
                    .shadow(color: CardStyle.shadowColor, radius: CardStyle.shadowRadius, y: CardStyle.shadowYOffset)
                    .overlay(
                        RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                            .stroke(CardStyle.borderColor, lineWidth: 0.7)
                    )
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        
    }
}

// MARK: - CardHistorySection (Horizontal Scroll Cards)
struct CardHistorySection: View {
    @Binding var cardHistory: [CardHistoryItemWithImage]
    let contactId: UUID
    let onShowPopup: (UIImage) -> Void
    @State private var showCopyAnimation: [Int: Bool] = [:]

    private var placeholderImage: UIImage {
        UIImage(systemName: "photo") ?? UIImage()
    }
    var body: some View {
        Section {
            CardPresetView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Открытки")
                        .font(.headline)
                        .padding(.bottom, 4)
                    if cardHistory.isEmpty {
                        Text("Нет открыток")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(Array(cardHistory.enumerated()), id: \.offset) { idx, item in
                                    CardImageItem(
                                        image: item.image ?? placeholderImage,
                                        onDelete: {
                                            CardHistoryManager.deleteCard(item.id)
                                            cardHistory = CardHistoryManager.getCards(for: contactId)
                                        },
                                        onCopy: {
                                            withAnimation(.spring()) {
                                                showCopyAnimation[idx] = true
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                                withAnimation {
                                                    showCopyAnimation[idx] = false
                                                }
                                            }
                                        },
                                        showCopyAnimation: showCopyAnimation[idx] ?? false,
                                        onShowPopup: { image in onShowPopup(image) }
                                    )
                                    .frame(width: 180)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

struct CardImageItem: View {
    let image: UIImage
    let onDelete: () -> Void
    let onCopy: () -> Void
    let showCopyAnimation: Bool
    let onShowPopup: (UIImage) -> Void
    @State private var isShareSheetPresented = false
    @State private var showCopyAnimationState = false

    // For demonstration, you could add a date property if needed
    // let date: Date?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 110)
                    .clipped()
                    .cornerRadius(14)
                    .shadow(radius: 3)
                    .onTapGesture {
                        onShowPopup(image)
                    }
                // If you want to display a date, add here (e.g., if you pass it in)
                // if let date = date {
                //     Text(date, style: .date)
                //         .font(.caption2)
                //         .foregroundColor(.secondary)
                // }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                    .fill(CardStyle.backgroundColor)
                    .shadow(color: CardStyle.shadowColor, radius: CardStyle.shadowRadius, y: CardStyle.shadowYOffset)
                    .overlay(
                        RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                            .stroke(CardStyle.borderColor, lineWidth: 0.7)
                    )
            )
            .contextMenu {
                Button {
                    UIPasteboard.general.image = image
                    onCopy()
                } label: {
                    Label("Копировать", systemImage: "doc.on.doc")
                }
                Button {
                    isShareSheetPresented = true
                } label: {
                    Label("Поделиться", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Удалить", systemImage: "trash")
                }
            }
            .sheet(isPresented: $isShareSheetPresented) {
                ActivityViewController(activityItems: [image])
            }
            if showCopyAnimation {
                Image(systemName: "doc.on.doc.fill")
                    .foregroundColor(.accentColor)
                    .padding(8)
                    .background(Color(.systemBackground).opacity(0.9))
                    .clipShape(Circle())
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}
struct CongratsResultPopup: View {
    let message: String
    let onCopy: () -> Void
    let onShare: () -> Void
    let onClose: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                VStack(spacing: 0) {
                    // Верхний бар с крестиком и заголовком
                    HStack {
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 28, weight: .regular))
                                .foregroundColor(.secondary)
                                .padding(4)
                        }
                        Spacer()
                    }
                    .padding(.top, geo.safeAreaInsets.top)
                    .padding(.leading, 2)

                    Text("Поздравление")
                        .font(.title2.bold())
                        .padding(.top, 2)
                        .padding(.bottom, 2)

                    Spacer(minLength: 0)

                    Text(message)
                        .font(.title3)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Spacer(minLength: 0)

                    HStack(spacing: 36) {
                        CircleIconButton(systemName: "doc.on.doc", action: onCopy)
                        CircleIconButton(systemName: "square.and.arrow.up", action: onShare)
                    }
                    .padding(.bottom, geo.safeAreaInsets.bottom)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct CardResultPopup: View {
    let image: UIImage
    let onCopy: () -> Void
    let onShare: () -> Void
    let onSave: () -> Void
    let onClose: () -> Void

    var body: some View {
        
        ZStack(alignment: .topLeading) {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: 22)
                Text("Открытка")
                    .font(.headline)
                    .padding(.bottom, 6)
                ZoomableImage(image: image)
                    //.frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.height * 0.65)
                    //.clipped()
                Spacer()
                HStack(spacing: 28) {
                    CircleIconButton(systemName: "doc.on.doc", action: onCopy)
                    CircleIconButton(systemName: "square.and.arrow.up", action: onShare)
                    CircleIconButton(systemName: "square.and.arrow.down", action: onSave)
                }
                .padding(.bottom, 48)
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(20)
                    .contentShape(Rectangle())
            }
        }
    }
}

private struct CircleIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color(.systemGray6)))
                .shadow(color: Color(.black).opacity(0.10), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ZoomableImage
struct ZoomableImage: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.bouncesZoom = true
        scrollView.delegate = context.coordinator
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return imageView
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            // Плавный возврат к масштабу 1.0, если был zoom
            if abs(scale - 1.0) > 0.01 {
                UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
                    scrollView.setZoomScale(1.0, animated: false)
                }
            }
        }
    }
}

// MARK: - Card Generation UI Section
private struct CardGenerationSection: View {
    @Binding var referenceImage: UIImage?
    @Binding var showImagePicker: Bool
    @Binding var prompt: String
    let promptCharLimit: Int
    @Binding var selectedCardStyle: CardVisualStyle
    @Binding var selectedAspectRatio: CardAspectRatio
    @Binding var selectedQuality: CardQuality
    var onGeneratePrompt: () -> Void
    var onRemoveReferenceImage: () -> Void

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 14) {
                // Reference Image Section
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reference")
                        .font(.subheadline.weight(.medium))
                    HStack(spacing: 12) {
                        if let image = referenceImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 74, height: 74)
                                .clipped()
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.18), lineWidth: 1))
                            Button(action: onRemoveReferenceImage) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: { showImagePicker = true }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 26, weight: .regular))
                                        .foregroundColor(.accentColor)
                                    Text("Загрузить")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                }
                                .frame(width: 74, height: 74)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Новый блок: внешний вид поля и кнопки согласно инструкции
                VStack(alignment: .leading, spacing: 12) {
                    Text("Промт для открытки")
                        .font(.subheadline.weight(.medium))

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $prompt)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .frame(minHeight: 100, maxHeight: 120)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                        .stroke(lineWidth: 0)
                                    )
                            )
                            .cornerRadius(12)
                        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Подробно опишите идею открытки или нажмите кнопку «Идея открытки»")
                                .foregroundColor(.secondary)
                                .font(.body)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 18)
                                .allowsHitTesting(false)
                        }
                    }

                    Button(action: onGeneratePrompt) {
                        VStack(spacing: 2) {
                            Text("Идея открытки")
                                .font(.callout.bold())
                                .foregroundColor(.black)
                            Text("по данным контакта")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray5))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 0)
                .padding(.horizontal, 0)
                .background(
                    Color.clear
                        .contentShape(Rectangle())
                )
                HStack {
                    Spacer()
                    Text("\(prompt.count)/\(promptCharLimit)")
                        .font(.caption2)
                        .foregroundColor(prompt.count > promptCharLimit ? .red : .secondary)
                }

                // Card Style Picker
                VStack(alignment: .leading, spacing: 2) {
                    Text("Стиль открытки")
                        .font(.subheadline.weight(.medium))
                    Picker("Стиль", selection: $selectedCardStyle) {
                        ForEach(CardVisualStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                // Aspect Ratio Picker
                VStack(alignment: .leading, spacing: 2) {
                    Text("Размер")
                        .font(.subheadline.weight(.medium))
                    Picker("Формат", selection: $selectedAspectRatio) {
                        ForEach(CardAspectRatio.allCases) { ratio in
                            Text(ratio.displayName).tag(ratio)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                // Quality Picker
                VStack(alignment: .leading, spacing: 2) {
                    Text("Качество")
                        .font(.subheadline.weight(.medium))
                    Picker("Качество", selection: $selectedQuality) {
                        ForEach(CardQuality.allCases) { q in
                            Text(q.displayName).tag(q)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .sheet(isPresented: $showImagePicker) {
                ImagePicker { image in
                    referenceImage = image
                }
            }
        }
    }
}

// MARK: - Card Generation Option Enums
enum CardVisualStyle: String, CaseIterable, Identifiable {
    case none = "Без стиля"
    case realistic = "Реалистичный"
    case vanGogh = "Ван Гог"
    case watercolor = "Акварель"
    case anime = "Аниме"
    case retro = "Ретро / Винтаж"
    case minimal = "Минимализм"
    case pixel = "Пиксель-арт"
    case popArt = "Комикс / Pop Art"
    case fantasy = "Фэнтези"
    var id: String { rawValue }
}

enum CardAspectRatio: String, CaseIterable, Identifiable {
    case square = "1024x1024"
    case landscape = "1536x1024"
    case portrait = "1024x1536"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .square: return "1024x1024"
        case .landscape: return "1536x1024"
        case .portrait: return "1024x1536"
        }
    }
    var apiValue: String {
        return self.rawValue
    }
}

enum CardQuality: String, CaseIterable, Identifiable {
    case low = "Низкое"
    case medium = "Среднее"
    case high = "Высокое"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .low: return "Низкое"
        case .medium: return "Среднее"
        case .high: return "Высокое"
        }
    }
}
extension CardVisualStyle {
    var promptSuffix: String {
        switch self {
        case .none:
            return ""
        case .realistic:
            return "in a highly realistic, photorealistic style"
        case .vanGogh:
            return "in the style of Vincent van Gogh, expressive brush strokes, swirling vivid colors"
        case .watercolor:
            return "in delicate watercolor style, soft color washes and gradients, with paper texture"
        case .anime:
            return "in bright anime style, sharp lines, big expressive eyes, colorful"
        case .retro:
            return "in retro vintage postcard style, muted colors, old paper texture, ornamental frame"
        case .minimal:
            return "in minimalistic style, simple clean shapes, lots of white space, pastel colors"
        case .pixel:
            return "in pixel art style, 16-bit or 32-bit, nostalgic video game feel"
        case .popArt:
            return "in pop art comic style, bold outlines, halftone dots, bright contrasting colors"
        case .fantasy:
            return "in fantasy illustration style, magical atmosphere, glowing effects, detailed art"
        }
    }
}
