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

    init(contact: Binding<Contact>, cardStore: CardHistoryStore, congratsHistoryStore: CongratsHistoryStore, selectedMode: String) {
        self._contact = contact
        _cardStore = StateObject(wrappedValue: cardStore)
        _congratsHistoryStore = StateObject(wrappedValue: congratsHistoryStore)
        self.selectedMode = selectedMode
        _selectedMode = State(initialValue: selectedMode)
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

                        
                            generateButtons()

                            // History Sections
                            VStack(spacing: 24) {
                                if selectedMode == "text" {
                                    ContactCongratsHistorySection(
                                        congratsHistory: congratsHistory,
                                        onDelete: { item in
                                            if let idx = congratsHistory.firstIndex(where: { $0.id == item.id }) {
                                                congratsHistory.remove(at: idx)
                                                congratsHistoryStore.saveHistory(congratsHistory)
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
                                    CardHistorySection(cardStore: cardStore, onShowPopup: { url, image in
                                        cardPopupUrl = url
                                        cardPopupImage = image
                                        showCardPopup = true
                                    })
                                    // Здесь появятся настройки генерации открытки и popup результата
                                }
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
                                congratsHistoryStore.saveHistory(congratsHistory)
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
    let onShowPopup: (URL, UIImage) -> Void
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
                                        showCopyAnimation: showCopyAnimation[idx] ?? false,
                                        onShowPopup: { image in onShowPopup(url, image) }
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
    let onShowPopup: (UIImage) -> Void
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
                            .onTapGesture {
                                if let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) {
                                    onShowPopup(uiImage)
                                }
                            }
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
