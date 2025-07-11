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
    @Environment(\.dismiss) private var dismiss
    @Binding var contact: Contact
    @StateObject private var cardStore: CardHistoryStore
    @StateObject private var congratsHistoryStore: CongratsHistoryStore
    @State private var congratsHistory: [CongratsHistoryItem] = []
    @State private var selectedStyle: CongratsStyle = .classic
    @State private var isLoading: Bool = false
    @State private var alertMessage: String? = nil
    @State private var headerVisible: Bool = true

    init(contact: Binding<Contact>, cardStore: CardHistoryStore, congratsHistoryStore: CongratsHistoryStore) {
        self._contact = contact
        _cardStore = StateObject(wrappedValue: cardStore)
        _congratsHistoryStore = StateObject(wrappedValue: congratsHistoryStore)
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("scroll")).minY)
                }
                .frame(height: 0)
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        if headerVisible {
                            topButtons(geo: geo)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        VStack(spacing: 20) {
                            // Header
                            VStack(spacing: 8) {
                                contactBlock(contact: contact)
                                
                            }
                            .frame(maxWidth: 500)
                            .padding(.horizontal, 16)
                            .padding(.top, 15)

                            // Style Picker
                            /*  Picker("Стиль поздравления", selection: $selectedStyle) {
                                ForEach(CongratsStyle.allCases) { style in
                                    Text(style.rawValue).tag(style)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal)*/

                            // Generate Buttons
                            generateButtons()

                            // History Sections
                            VStack(spacing: 24) {
                                ContactCongratsHistorySection(
                                    congratsHistory: congratsHistory,
                                    onDelete: { item in
                                        if let idx = congratsHistory.firstIndex(where: { $0.id == item.id }) {
                                            congratsHistory.remove(at: idx)
                                            congratsHistoryStore.saveHistory(congratsHistory)
                                        }
                                    }
                                )
                                CardHistorySection(cardStore: cardStore)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 32)
                        }
                    }
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                withAnimation(.easeInOut(duration: 0.18)) {
                    headerVisible = offset > -32
                }
            }
        }
        .onAppear {
            congratsHistory = congratsHistoryStore.loadHistory()
        }
        .overlay(
            Group {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.2).ignoresSafeArea()
                        ProgressView("Генерация...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(14)
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
    }

    // MARK: - Top Buttons
    private func topButtons(geo: GeometryProxy) -> some View {
        HStack {
            // Левая кнопка "Назад"
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.backward")
                    .frame(width: AppButtonStyle.Circular.diameter, height: AppButtonStyle.Circular.diameter)
                    .background(Circle().fill(AppButtonStyle.Circular.backgroundColor))
                    .shadow(color: AppButtonStyle.Circular.shadow, radius: AppButtonStyle.Circular.shadowRadius)
                    .foregroundColor(AppButtonStyle.Circular.iconColor)
                    .font(.system(size: AppButtonStyle.Circular.iconSize, weight: .semibold))
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, geo.safeAreaInsets.top + 8)
    }

    // MARK: - Generate Buttons
    private func generateButtons() -> some View {
        HStack(spacing: 16) {
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
                            congratsHistoryStore.saveHistory(congratsHistory)
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

            Button(action: handleGenerate) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 24)
                    Text("Сгенерировать\nоткрытку")
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
        }
        .padding(.horizontal)
    }
        // это из кода cardfullscreenview
    private func handleGenerate() {
        alertMessage = nil
        guard !isLoading else { return }
        let apiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        guard !apiKey.isEmpty else {
            alertMessage = "Нет данных контакта или API-ключа."
            return
        }

        isLoading = true
        ChatGPTService.shared.generateCard(for: contact, apiKey: apiKey) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    // После успешной генерации — только обновляем список
                    cardStore.loadSavedCards()
                case .failure(let error):
                    self.alertMessage = "Ошибка генерации открытки: \(error.localizedDescription)"
                }
                self.isLoading = false
            }
        }
    }


   
}

// MARK: - ContactCongratsHistorySection
private struct ContactCongratsHistorySection: View {
    let congratsHistory: [CongratsHistoryItem]
    let onDelete: (CongratsHistoryItem) -> Void

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
                                onDelete: { onDelete(item) }
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
                Text("Кому: " + contact.name)
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
    @ObservedObject var cardStore: CardHistoryStore
    @State private var showCopyAnimation: [Int: Bool] = [:]

    var body: some View {
        Section {
            CardPresetView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Открытки")
                        .font(.headline)
                        .padding(.bottom, 4)
                    if cardStore.savedCards.isEmpty {
                        Text("Нет открыток")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(Array(cardStore.savedCards.enumerated()), id: \.offset) { idx, url in
                                    CardImageItem(
                                        url: url,
                                        onDelete: { cardStore.deleteCard(at: idx) },
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
                                        showCopyAnimation: showCopyAnimation[idx] ?? false
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
    let url: URL
    let onDelete: () -> Void
    let onCopy: () -> Void
    let showCopyAnimation: Bool
    @State private var isShareSheetPresented = false

    private func getCreationDate() -> Date? {
        let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey])
        return resourceValues?.creationDate
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(height: 120)
                            .frame(maxWidth: .infinity)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 160, height: 110)
                            .clipped()
                            .cornerRadius(14)
                            .shadow(radius: 3)
                    case .failure(_):
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 100)
                            .foregroundColor(.accentColor)
                    @unknown default:
                        EmptyView()
                    }
                }
                if let date = getCreationDate() {
                    Text(date, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
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
                    if let data = try? Data(contentsOf: url),
                       let uiImage = UIImage(data: data) {
                        UIPasteboard.general.image = uiImage
                        onCopy()
                    }
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
                ActivityViewController(activityItems: [url])
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


