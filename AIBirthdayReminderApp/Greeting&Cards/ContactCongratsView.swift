import UIKit
import SwiftUI
// MARK: - Localization helpers (file-local)
private func appLocale() -> Locale {
    if let code = UserDefaults.standard.string(forKey: "app.language.code") { return Locale(identifier: code) }
    if let code = Bundle.main.preferredLocalizations.first { return Locale(identifier: code) }
    return .current
}
private func appBundle() -> Bundle {
    if let code = UserDefaults.standard.string(forKey: "app.language.code"),
       let path = Bundle.main.path(forResource: code, ofType: "lproj"),
       let bundle = Bundle(path: path) { return bundle }
    return .main
}



struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}




// MARK: - Main View
@MainActor struct ContactCongratsView: View {
    enum LoadingType {
        case image, prompt, text
    }
    @Environment(\.dismiss) private var dismiss
    @Binding var contact: Contact
    @EnvironmentObject var store: StoreKitManager
    @State private var showStore = false
    @State private var cardHistory: [CardHistoryItemWithImage] = []
    @State private var congratsHistory: [CongratsHistoryItem] = []
    @State private var isLoading: Bool = false
    @State private var alertMessage: String? = nil
    @State private var headerVisible: Bool = true
    @State private var selectedMode: String
    @State private var showCongratsPopup = false
    @State private var congratsPopupMessage: String?
    @State private var isRegenerating: Bool = false
    @State private var showShareSheet = false
    @State private var shareText: String?
    // Card popup states
    @State private var showCardPopup = false
    @State private var cardPopupImage: UIImage?
    @State private var cardPopupUrl: URL?
    @State private var showCardShareSheet = false
    @State private var allowCardPopupClose = false

    @State private var preGenCardIDs: Set<UUID> = []

    @State private var fakeProgress: Double = 0
    @State private var progressTimer: Timer? = nil
    @State private var loadingType: LoadingType? = nil

    init(contact: Binding<Contact>, selectedMode: String) {
        self._contact = contact
        self._selectedMode = State(initialValue: selectedMode)
    }


    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                // Scrollable Content
                ScrollView {
                    VStack(spacing: 0) {
                        mainContent()
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.immediately)
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onAppear {
            cardHistory = CardHistoryManager.getCards(for: contact.id)
            congratsHistory = CongratsHistoryManager.getCongrats(for: contact.id)
            CardHistoryManager.logTotalCardImagesSize(for: contact.id)
            Task {
                store.startTransactionListener()
                await store.fetchServerTokens()
                await store.refreshSubscriptionStatus()
            }
        }
        .onDisappear {
            progressTimer?.invalidate()
            progressTimer = nil
        }
        .overlay(
            Group {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.28).ignoresSafeArea()
                        if loadingType == .image {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .controlSize(.large)
                                .tint(.white)
                                .scaleEffect(1.5)
                        } else if loadingType == .prompt {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .controlSize(.large)
                                .tint(.white)
                                .scaleEffect(1.5)
                        } else if loadingType == .text {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .controlSize(.large)
                                .tint(.white)
                                .scaleEffect(1.5)
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
                title: Text(String(localized: "common.error", defaultValue: "Ошибка", bundle: appBundle(), locale: appLocale())),
                message: Text(alertMessage ?? ""),
                dismissButton: .default(Text(String(localized: "common.ok", defaultValue: "OK", bundle: appBundle(), locale: appLocale())))
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showStore = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("\(store.purchasedTokenCount)")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.tint)
                }
                .tint(Color(UIColor.systemBlue))
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "store.tokens.balance", defaultValue: "Баланс токенов", bundle: appBundle(), locale: appLocale()))
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { showCongratsPopup },
                set: { newValue in
                    DispatchQueue.main.async {
                        print("📱 showCongratsPopup setter called → \(newValue)")
                        showCongratsPopup = newValue
                        if !newValue {
                            // refresh text history and clear data on close
                            congratsHistory = CongratsHistoryManager.getCongrats(for: contact.id)
                            congratsPopupMessage = nil
                        }
                    }
                }
            )
        ) {
            if let message = congratsPopupMessage {
                ZStack {
                    AppBackground().ignoresSafeArea()
                    CongratsResultPopup(
                        message: message,
                        onCopy: {
                            UIPasteboard.general.string = message
                        },
                        onShare: {
                            shareText = message
                            showShareSheet = true
                        },
                        onRegenerate: {
                            isRegenerating = true
                            ChatGPTService.shared.generateGreeting(for: contact) { result in
                                DispatchQueue.main.async {
                                    isRegenerating = false
                                    switch result {
                                    case .success(let text):
                                        let newCongrats = CongratsHistoryItem(date: Date(), message: text)
                                        congratsHistory.append(newCongrats)
                                        if let last = congratsHistory.last {
                                            CongratsHistoryManager.addCongrats(item: last, for: contact.id)
                                        }
                                        congratsPopupMessage = text
                                        Task { await store.fetchServerTokens() }
                                    case .failure(let error):
                                        congratsPopupMessage = "Ошибка генерации: \(error.localizedDescription)"
                                    }
                                }
                            }
                        },
                        onClose: {
                            showCongratsPopup = false
                        },
                        regenCost: 1
                    )
                    .transition(.opacity)
                    if isRegenerating {
                        Color.black.opacity(0.28).ignoresSafeArea()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .controlSize(.large)
                            .tint(.white)
                            .scaleEffect(1.5)
                    }
                }
                .onAppear { print("🧩 CongratsPopup content onAppear") }
                .onDisappear { print("🧩 CongratsPopup content onDisappear") }
                .interactiveDismissDisabled(true)
                .sheet(isPresented: $showShareSheet) {
                    if let shareText = shareText {
                        ActivityViewController(activityItems: [shareText])
                    }
                }
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { showCardPopup },
                set: { newValue in
                    DispatchQueue.main.async {
                        print("📱 showCardPopup setter called → \(newValue)")
                        showCardPopup = newValue
                        if !newValue {
                            // refresh card history and clear image on close
                            cardHistory = CardHistoryManager.getCards(for: contact.id)
                            cardPopupImage = nil
                        }
                    }
                }
            )
        ) {
            if let image = cardPopupImage {
                ZStack {
                    AppBackground().ignoresSafeArea()
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
                            if allowCardPopupClose {
                                print("🧩 CardPopup close requested")
                                showCardPopup = false
                            } else {
                                print("⚠️ Early close ignored")
                            }
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                    .onAppear {
                        print("🧩 CardPopup content onAppear (image ready)")
                        allowCardPopupClose = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            allowCardPopupClose = true
                        }
                    }
                    .onDisappear { print("🧩 CardPopup content onDisappear") }
                }
                .interactiveDismissDisabled(true)
                .sheet(isPresented: $showCardShareSheet) {
                    ActivityViewController(activityItems: [image])
                }
            }
        }
        
        .sheet(isPresented: $showStore) {
            PaywallView()
        }
        .navigationTitle({
            let fmt = appBundle().localizedString(forKey: "contact.birthday.title", value: "День рождения: %@", table: "Localizable")
            return String(format: fmt, contact.name)
        }())
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if selectedMode == "text" {
                VStack(spacing: 0) {
                    Button(action: {
                        // JWT авторизация: appleId больше не нужен.
                        loadingType = .text
                        isLoading = true
                        ChatGPTService.shared.generateGreeting(for: contact) { result in
                            DispatchQueue.main.async {
                                isLoading = false
                                loadingType = nil
                                switch result {
                                case .success(let text):
                                    let newCongrats = CongratsHistoryItem(date: Date(), message: text)
                                    congratsHistory.append(newCongrats)
                                    if let last = congratsHistory.last {
                                        CongratsHistoryManager.addCongrats(item: last, for: contact.id)
                                    }
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    congratsPopupMessage = text
                                    showCongratsPopup = true
                                    Task { await store.fetchServerTokens() }
                                case .failure(let error):
                                    alertMessage = error.localizedDescription
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 10) {
                            Spacer()
                            Text(String(localized: "congrats.generate", defaultValue: "Сгенерировать поздравление", bundle: appBundle(), locale: appLocale()))
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            HStack(spacing: 3) {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 15, weight: .semibold))
                                Text("1")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.white.opacity(0.18)))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: AppButtonStyle.Congratulate.cornerRadius, style: .continuous)
                                .fill(AppButtonStyle.primaryFill())
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppButtonStyle.Congratulate.cornerRadius, style: .continuous)
                                        .fill(AppButtonStyle.primaryGloss())
                                )
                                .shadow(color: AppButtonStyle.Congratulate.shadow, radius: AppButtonStyle.Congratulate.shadowRadius, y: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .opacity(isLoading ? 0.6 : 1)
                    .disabled(isLoading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                }
            }
        }
        .toolbar(.visible, for: .tabBar)
    }

    // MARK: - Main Content Extraction
    @ViewBuilder
    private func mainContent() -> some View {
        VStack(spacing: 20) {
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
                    isLoading: $isLoading,
                    onGeneratePrompt: generateCreativePrompt,
                    onRemoveReferenceImage: { referenceImage = nil },
                    onGenerateCard: handleGenerate
                )
            }

     

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
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        congratsPopupMessage = message
                        showCongratsPopup = true
                    }
                )
                // Здесь появятся настройки генерации поздравления и popup результата
            }
            if selectedMode == "card" {
                CardHistorySection(cardHistory: $cardHistory, contactId: contact.id, onShowPopup: { image in
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    print("🖼 History tap image size: \(Int(image.size.width))x\(Int(image.size.height))")
                    cardPopupImage = image
                    showCardPopup = true
                })
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 32)
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
        alertMessage = nil
        guard !isLoading else { return }
        print("🎬 handleGenerate start: isLoading=\(isLoading), showCardPopup=\(showCardPopup), showCardShareSheet=\(showCardShareSheet)")
        print("🧾 Params: promptLen=\(prompt.count), hasReference=\(referenceImage != nil), style=\(selectedCardStyle), aspect=\(selectedAspectRatio.apiValue), quality=\(selectedQuality)")
        // Snapshot existing card IDs before generation
        preGenCardIDs = Set(cardHistory.map { $0.id })
        // Pre-dismiss any potential presenters to avoid "present while presenting" race
        showImagePicker = false
        showStore = false
        showShareSheet = false
        showCardShareSheet = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        // JWT авторизация: appleId больше не нужен.

        loadingType = .image
        isLoading = true

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
                print("🧵 On main thread: \(Thread.isMainThread)")
                // Stop loader BEFORE presenting popup to avoid phantom taps
                isLoading = false
                loadingType = nil
                progressTimer?.invalidate()
                fakeProgress = 1
                resetCardGenerationSettings()
                let newItem = cardHistory.first(where: { !preGenCardIDs.contains($0.id) })
                let pick: CardHistoryItemWithImage? = newItem ?? cardHistory.sorted(by: { $0.date > $1.date }).first

                if let item = pick, let image = item.image {
                    print("🖼 Picked card id: \(item.id), date: \(String(describing: item.date))")
                    print("🖼 Latest image size: \(Int(image.size.width))x\(Int(image.size.height))")
                    cardPopupImage = image
                    allowCardPopupClose = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    DispatchQueue.main.async {
                        showCardPopup = true
                        print("🔔 showCardPopup set to TRUE (from handleGenerate)")
                    }
                } else {
                    print("⚠️ Could not pick a card image to present (either empty history or image missing)")
                }
               
                Task { await store.fetchServerTokens() }
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
        // JWT авторизация: appleId больше не нужен.
        loadingType = .prompt
        isLoading = true
        ChatGPTService.shared.generateCreativePrompt(for: contact) { result in
            DispatchQueue.main.async {
                isLoading = false
                loadingType = nil
                switch result {
                case .success(let creativePrompt):
                    prompt = creativePrompt
                    Task { await store.fetchServerTokens() }
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
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "history.congrats.title", defaultValue: "История поздравлений", bundle: appBundle(), locale: appLocale()))
                .font(.headline)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

            if congratsHistory.isEmpty {
                Text(String(localized: "history.congrats.empty", defaultValue: "Нет поздравлений", bundle: appBundle(), locale: appLocale()))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(congratsHistory) { item in
                        CongratsHistoryItemView(
                            item: item,
                            onDelete: { onDelete(item) },
                            onShowPopup: { onShowPopup(item.message) }
                        )
                    }
                }
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

    // --- Preview helpers for char limiting ---
    private let maxPreviewChars = 140
    private var previewText: String {
        let trimmed = item.message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > maxPreviewChars {
            return String(trimmed.prefix(maxPreviewChars)) + "…"
        } else {
            return trimmed
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(previewText)
                .font(.body)
                .foregroundColor(.primary)
            Text(item.date, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
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
                Label(String(localized: "common.copy", defaultValue: "Копировать", bundle: appBundle(), locale: appLocale()), systemImage: "doc.on.doc")
            }
            Button {
                sharingText = item.message
                isShareSheetPresented = true
            } label: {
                Label(String(localized: "common.share", defaultValue: "Поделиться", bundle: appBundle(), locale: appLocale()), systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(String(localized: "common.delete", defaultValue: "Удалить", bundle: appBundle(), locale: appLocale()), systemImage: "trash")
            }
        }
        .alert(isPresented: Binding<Bool>(
            get: { alertMessage != nil },
            set: { _ in alertMessage = nil }
        )) {
            Alert(
                title: Text(String(localized: "common.error", defaultValue: "Ошибка", bundle: appBundle(), locale: appLocale())),
                message: Text(alertMessage ?? ""),
                dismissButton: .default(Text(String(localized: "common.ok", defaultValue: "OK", bundle: appBundle(), locale: appLocale())))
            )
        }
        .sheet(isPresented: $isShareSheetPresented) {
            if let sharingText = sharingText {
                ActivityViewController(activityItems: [sharingText])
            }
        }
    }
}


// MARK: - CardHistorySection (Vertical Grid Cards)
struct CardHistorySection: View {
    @Binding var cardHistory: [CardHistoryItemWithImage]
    let contactId: UUID
    let onShowPopup: (UIImage) -> Void
    @State private var showCopyAnimation: [UUID: Bool] = [:]

    // --- Grid parameters ---
    private var gridSpacing: CGFloat { 14 }
    private var cardSide: CGFloat {
        (UIScreen.main.bounds.width - 16*2 - gridSpacing) / 2
    }
    private var columns: [GridItem] {
        [
            GridItem(.fixed(cardSide), spacing: gridSpacing),
            GridItem(.fixed(cardSide), spacing: 0)
        ]
    }

    private var placeholderImage: UIImage {
        UIImage(systemName: "photo") ?? UIImage()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "history.cards.title", defaultValue: "История открыток", bundle: appBundle(), locale: appLocale()))
                .font(.headline)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

            if cardHistory.isEmpty {
                Text(String(localized: "history.cards.empty", defaultValue: "Нет открыток", bundle: appBundle(), locale: appLocale()))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(cardHistory, id: \.id) { item in
                        CardImageItem(
                            image: item.image ?? placeholderImage,
                            date: item.date,
                            onDelete: {
                                CardHistoryManager.deleteCard(item.id)
                                cardHistory = CardHistoryManager.getCards(for: contactId)
                            },
                            onCopy: {
                                withAnimation(.spring()) {
                                    showCopyAnimation[item.id] = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    withAnimation {
                                        showCopyAnimation[item.id] = false
                                    }
                                }
                            },
                            showCopyAnimation: showCopyAnimation[item.id] ?? false,
                            onShowPopup: { image in onShowPopup(image) },
                            cardSide: cardSide
                        )
                    }
                }
            }
        }
    }
}

struct CardImageItem: View {
    let image: UIImage
    let date: Date?
    let onDelete: () -> Void
    let onCopy: () -> Void
    let showCopyAnimation: Bool
    let onShowPopup: (UIImage) -> Void
    var cardSide: CGFloat = 120
    @State private var isShareSheetPresented = false
    @State private var showCopyAnimationState = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cardSide, height: cardSide)
                    .clipped()
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
                    .onTapGesture {
                        onShowPopup(image)
                    }

                if let date = date {
                    Text(date, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .contextMenu {
                Button {
                    UIPasteboard.general.image = image
                    onCopy()
                } label: {
                    Label(String(localized: "common.copy", defaultValue: "Копировать", bundle: appBundle(), locale: appLocale()), systemImage: "doc.on.doc")
                }
                Button {
                    isShareSheetPresented = true
                } label: {
                    Label(String(localized: "common.share", defaultValue: "Поделиться", bundle: appBundle(), locale: appLocale()), systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(String(localized: "common.delete", defaultValue: "Удалить", bundle: appBundle(), locale: appLocale()), systemImage: "trash")
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
    let onRegenerate: () -> Void
    let onClose: () -> Void
    let regenCost: Int
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Spacer().frame(height: 22)
                Text(String(localized: "popup.congrats.title", defaultValue: "Поздравление", bundle: appBundle(), locale: appLocale()))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .padding(.bottom, 6)

                // Centered content area (vertically centers when short, scrolls when long)
                GeometryReader { geo in
                    ScrollView {
                        VStack {
                            Text(message)
                                .font(.title3)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(6)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: (hSize == .compact ? 20 : 28)) {
                    CircleIconButton(systemName: "arrow.clockwise", action: onRegenerate, badgeText: "\(regenCost)")
                        .accessibilityLabel({
                            let fmt = appBundle().localizedString(forKey: "accessibility.regenerate_cost", value: "Перегенерировать. Стоимость: %d", table: "Localizable")
                            return String(format: fmt, regenCost)
                        }())
                    CircleIconButton(systemName: "doc.on.doc", action: onCopy)
                        .accessibilityLabel(String(localized: "common.copy", defaultValue: "Копировать", bundle: appBundle(), locale: appLocale()))
                    CircleIconButton(systemName: "square.and.arrow.up", action: onShare)
                        .accessibilityLabel(String(localized: "common.share", defaultValue: "Поделиться", bundle: appBundle(), locale: appLocale()))
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

struct CardResultPopup: View {
    let image: UIImage
    let onCopy: () -> Void
    let onShare: () -> Void
    let onSave: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Spacer().frame(height: 22)
                Text(String(localized: "card.title", defaultValue: "Открытка", bundle: appBundle(), locale: appLocale()))
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
    var badgeText: String? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.accentColor)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color(.systemGray6)))
                    .shadow(color: Color(.black).opacity(0.10), radius: 4, y: 2)
            }
            .buttonStyle(.plain)

            if let badgeText {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12, weight: .semibold))
                    Text(badgeText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.black.opacity(0.35)))
                .offset(x: 4, y: 4)
            }
        }
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
    @Binding var isLoading: Bool
    var onGeneratePrompt: () -> Void
    var onRemoveReferenceImage: () -> Void
    var onGenerateCard: () -> Void
    
    @State private var showAddMenu = false

    // Dynamic token price for image generation (parity with backend)
    private func imageTokenPrice() -> Int {
        // Base cost per 1024x1024 tile by quality
        let base: Int
        switch selectedQuality {
        case .low:    base = 1
        case .medium: base = 4
        case .high:   base = 17
        }
        // Parse size like "1024x1536"
        let comps = selectedAspectRatio.apiValue.split(separator: "x")
        var multiplier: Double = 1
        if comps.count == 2, let w = Double(comps[0]), let h = Double(comps[1]) {
            let area = w * h
            let tile = 1024.0 * 1024.0
            let rawMul = area / tile
            // round up to hundredths, minimum 1
            multiplier = max(1, ceil(rawMul * 100) / 100)
        }
        var cost = Int(ceil(Double(base) * multiplier))
        // +1 token if reference image is supplied
        if referenceImage != nil { cost += 1 }
        return max(1, cost)
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 14) {
                // Composer bar: glass-like prompt field with add/idea buttons and char counter
                PromptComposerBar(
                    text: $prompt,
                    placeholder: String(localized: "prompt.placeholder", defaultValue: "Опишите идею открытки или нажмите на кнопку «Идея открытки» для автоматической генерации", bundle: appBundle(), locale: appLocale()),
                    charLimit: promptCharLimit,
                    onAddTapped: { showAddMenu = true },
                    onIdeaTapped: { onGeneratePrompt() }
                )
                .confirmationDialog(String(localized: "common.add", defaultValue: "Добавить", bundle: appBundle(), locale: appLocale()), isPresented: $showAddMenu, titleVisibility: .visible) {
                    Button(String(localized: "gallery.pick_reference", defaultValue: "Выбрать референс из галереи", bundle: appBundle(), locale: appLocale())) { showImagePicker = true }
                    if referenceImage != nil {
                        Button(String(localized: "reference.remove", defaultValue: "Удалить референс", bundle: appBundle(), locale: appLocale()), role: .destructive) { onRemoveReferenceImage() }
                    }
                    Button(String(localized: "common.cancel", defaultValue: "Отмена", bundle: appBundle(), locale: appLocale()), role: .cancel) {}
                }

                // Optional preview of reference
                if let image = referenceImage {
                    HStack(spacing: 8) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipped()
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
                        Button(String(localized: "common.delete", defaultValue: "Удалить", bundle: appBundle(), locale: appLocale()), role: .destructive) { onRemoveReferenceImage() }
                            .buttonStyle(.plain)
                        Spacer()
                    }
                }

                // Unified parameters row: Style, Aspect Ratio & Quality (pill menus in one line)
                HStack(spacing: 8) {
                    StyleMenuPill(selected: $selectedCardStyle)
                    AspectRatioMenuPill(selected: $selectedAspectRatio)
                    QualityMenuPill(selected: $selectedQuality)
                }

                // Generate card CTA with token price
                PrimaryCTAButton(title: String(localized: "card.generate", defaultValue: "Сгенерировать открытку", bundle: appBundle(), locale: appLocale()), systemImage: "photo.on.rectangle.angled", price: imageTokenPrice(), isLoading: isLoading, action: onGenerateCard)
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

// MARK: - Pill Menus (Aspect Ratio & Quality)
private struct AspectRatioMenuPill: View {
    @Binding var selected: CardAspectRatio
    var body: some View {
        Menu {
            Picker("Aspect ratio", selection: $selected) {
                ForEach(CardAspectRatio.allCases) { ratio in
                    Label(ratio.displayName, systemImage: ratio.symbolName).tag(ratio)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selected.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                Text(selected.displayName)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minHeight: 34)
            .background(.thinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
        }
    }
}

private struct QualityMenuPill: View {
    @Binding var selected: CardQuality
    var body: some View {
        Menu {
            Picker(String(localized: "quality.title", defaultValue: "Качество", bundle: appBundle(), locale: appLocale()), selection: $selected) {
                ForEach(CardQuality.allCases) { q in
                    Text(q.displayName).tag(q)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                Text(selected.displayName)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minHeight: 34)
            .background(.thinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
        }
    }
}

private struct StyleMenuPill: View {
    @Binding var selected: CardVisualStyle
    var body: some View {
        Menu {
            Picker(String(localized: "style.title", defaultValue: "Стиль открытки", bundle: appBundle(), locale: appLocale()), selection: $selected) {
                ForEach(CardVisualStyle.allCases) { style in
                    Text(style.localizedName).tag(style)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(selected.localizedName)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minHeight: 34)
            .background(.thinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
        }
    }
}

// MARK: - Prompt Composer Bar (glass-like)
private struct PromptComposerBar: View {
    @Binding var text: String
    var placeholder: String
    var charLimit: Int
    var onAddTapped: () -> Void
    var onIdeaTapped: () -> Void

    private let fieldHeight: CGFloat = 120 // +~1 строка к прежним ~90
    private let cornerRadius: CGFloat = 20
    private let showCharCounter: Bool = false
    @State private var editorHeight: CGFloat = 0
    private let minEditorHeight: CGFloat = 64

    var body: some View {
        VStack(spacing: 0) {
            // Top: Text field area (UIKit-backed for precise insets & placeholder alignment)
            InsetTextView(
                text: $text,
                placeholder: placeholder,
                charLimit: charLimit,
                insets: UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14),
                onHeightChange: { h in
                    let newH = max(h, minEditorHeight)
                    if abs(editorHeight - newH) > 0.5 { editorHeight = newH }
                }
            )
            .frame(height: max(editorHeight, minEditorHeight), alignment: .leading)
            .background(Color.clear)

            // Bottom: buttons area
            HStack(spacing: 12) {
                Button(action: onAddTapped) {
                    Label("", systemImage: "photo.badge.plus")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.thinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                }
                .buttonStyle(.plain)

                Button(action: onIdeaTapped) {
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 15, weight: .semibold))
                        Text(String(localized: "idea.card", defaultValue: "Идея открытки", bundle: appBundle(), locale: appLocale()))
                            .font(.callout.weight(.semibold))
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 13, weight: .semibold))
                            Text("1")
                                .font(.footnote.weight(.bold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.18)))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.thinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
        )
        .overlay(alignment: .bottomTrailing) {
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: {
                    withAnimation(.easeOut(duration: 0.15)) {
                        text = ""
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 11)
                        .background(.thinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
                .padding(.trailing, 16)
                .accessibilityLabel(String(localized: "accessibility.clear_text", defaultValue: "Очистить текст", bundle: appBundle(), locale: appLocale()))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showCharCounter {
                Text("\(text.count)/\(charLimit)")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(text.count > charLimit ? .red : .secondary)
                    .padding(.trailing, 12)
                    .padding(.bottom, 8)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - UITextView with insets & placeholder matching cursor baseline
private struct InsetTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var charLimit: Int
    var insets: UIEdgeInsets
    var onHeightChange: ((CGFloat) -> Void)? = nil

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.isScrollEnabled = false
        tv.textContainerInset = insets
        tv.textContainer.lineFragmentPadding = 0
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.adjustsFontForContentSizeCategory = true
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        // Placeholder label
        let ph = UILabel()
        ph.text = placeholder
        ph.textColor = .secondaryLabel
        ph.numberOfLines = 0
        ph.lineBreakMode = .byWordWrapping
        ph.font = tv.font // keep baseline & size identical to caret
        ph.translatesAutoresizingMaskIntoConstraints = false
        ph.isUserInteractionEnabled = false
        ph.tag = 999_001 // lookup tag
        tv.addSubview(ph)

        NSLayoutConstraint.activate([
            ph.topAnchor.constraint(equalTo: tv.topAnchor, constant: insets.top),
            ph.leadingAnchor.constraint(equalTo: tv.leadingAnchor, constant: insets.left),
            ph.trailingAnchor.constraint(equalTo: tv.trailingAnchor, constant: -insets.right),
            ph.bottomAnchor.constraint(lessThanOrEqualTo: tv.bottomAnchor, constant: -insets.bottom)
        ])

        ph.isHidden = !text.isEmpty
        // Report initial height after layout
        DispatchQueue.main.async {
            tv.layoutIfNeeded()
            let width = tv.bounds.width
            let targetWidth = max(0, width - insets.left - insets.right)
            ph.preferredMaxLayoutWidth = targetWidth
            let phSize = ph.sizeThatFits(CGSize(width: targetWidth, height: .greatestFiniteMagnitude))
            let textHeight = tv.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
            let height = max(textHeight, phSize.height + insets.top + insets.bottom)
            self.onHeightChange?(height)
        }
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.textContainerInset = insets
        uiView.textContainer.lineFragmentPadding = 0
        uiView.font = UIFont.preferredFont(forTextStyle: .body)
        uiView.layoutIfNeeded()
        let width = uiView.bounds.width
        let targetWidth = max(0, width - insets.left - insets.right)
        var phHeight: CGFloat = 0
        if let ph = uiView.viewWithTag(999_001) as? UILabel {
            ph.text = placeholder
            ph.font = uiView.font
            ph.isHidden = !text.isEmpty
            ph.preferredMaxLayoutWidth = targetWidth
            let size = ph.sizeThatFits(CGSize(width: targetWidth, height: .greatestFiniteMagnitude))
            phHeight = size.height
        }
        let textHeight = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        let height = max(textHeight, phHeight + insets.top + insets.bottom)
        DispatchQueue.main.async { self.onHeightChange?(height) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: InsetTextView
        init(_ parent: InsetTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            // enforce char limit (soft trim)
            if textView.text.count > parent.charLimit {
                let limited = String(textView.text.prefix(parent.charLimit))
                textView.text = limited
            }
            parent.text = textView.text
            if let ph = textView.viewWithTag(999_001) as? UILabel {
                ph.isHidden = !textView.text.isEmpty
            }
            textView.layoutIfNeeded()
            let width = textView.bounds.width
            let targetWidth = max(0, width - parent.insets.left - parent.insets.right)
            var phHeight: CGFloat = 0
            if let ph = textView.viewWithTag(999_001) as? UILabel {
                ph.preferredMaxLayoutWidth = targetWidth
                let size = ph.sizeThatFits(CGSize(width: targetWidth, height: .greatestFiniteMagnitude))
                phHeight = size.height
            }
            let textHeight = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
            let height = max(textHeight, phHeight + parent.insets.top + parent.insets.bottom)
            DispatchQueue.main.async { [weak self] in self?.parent.onHeightChange?(height) }
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
    var localizedName: String {
        let b = appBundle()
        switch self {
        case .none:
            return b.localizedString(forKey: "style.none", value: "Без стиля", table: "Localizable")
        case .realistic:
            return b.localizedString(forKey: "style.realistic", value: "Реалистичный", table: "Localizable")
        case .vanGogh:
            return b.localizedString(forKey: "style.van_gogh", value: "Ван Гог", table: "Localizable")
        case .watercolor:
            return b.localizedString(forKey: "style.watercolor", value: "Акварель", table: "Localizable")
        case .anime:
            return b.localizedString(forKey: "style.anime", value: "Аниме", table: "Localizable")
        case .retro:
            return b.localizedString(forKey: "style.retro", value: "Ретро / Винтаж", table: "Localizable")
        case .minimal:
            return b.localizedString(forKey: "style.minimal", value: "Минимализм", table: "Localizable")
        case .pixel:
            return b.localizedString(forKey: "style.pixel", value: "Пиксель-арт", table: "Localizable")
        case .popArt:
            return b.localizedString(forKey: "style.pop_art", value: "Комикс / Pop Art", table: "Localizable")
        case .fantasy:
            return b.localizedString(forKey: "style.fantasy", value: "Фэнтези", table: "Localizable")
        }
    }
}

enum CardAspectRatio: String, CaseIterable, Identifiable {
    case square = "1024x1024"
    case landscape = "1536x1024"
    case portrait = "1024x1536"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .square: return "1:1"
        case .landscape: return "3:2"
        case .portrait: return "2:3"
        }
    }
    var apiValue: String { self.rawValue }
    var symbolName: String {
        switch self {
        case .square: return "square"
        case .landscape: return "rectangle"
        case .portrait: return "rectangle.portrait"
        }
    }
}

enum CardQuality: String, CaseIterable, Identifiable {
    case low = "Низкое"
    case medium = "Среднее"
    case high = "Высокое"
    var id: String { rawValue }
    var displayName: String {
        let b = appBundle()
        switch self {
        case .low:    return b.localizedString(forKey: "quality.low", value: "Низкое", table: "Localizable")
        case .medium: return b.localizedString(forKey: "quality.medium", value: "Среднее", table: "Localizable")
        case .high:   return b.localizedString(forKey: "quality.high", value: "Высокое", table: "Localizable")
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
