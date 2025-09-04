import SwiftUI
import Foundation

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

@MainActor
struct HolidayCongratsCardView: View {
    let holiday: Holiday
    @ObservedObject var vm: ContactsViewModel
    @EnvironmentObject var store: StoreKitManager

    // История открыток по празднику
    @State private var cardHistory: [CardHistoryItemWithImage] = []

    // Состояния UI
    @State private var showCongratsActionSheet = false
    @State private var showContactPicker = false
    @State private var showCardPopup = false
    @State private var cardPopupImage: UIImage?
    @State private var showCardShareSheet = false
    @State private var allowCardPopupClose = false
    @State private var isLoading = false
    @State private var showStore = false



    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {

                        // История открыток — вертикальная сетка 2 колонки
                        HolidayCardHistorySection(
                            cardHistory: $cardHistory,
                            ownerId: holiday.id,
                            onShowPopup: { image in
                                cardPopupImage = image
                                showCardPopup = true
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 120)
                }
                
            }
        }
        .onAppear {
            cardHistory = CardHistoryManager.getCards(forHoliday: holiday.id)
            Task {
                store.startTransactionListener()
                await store.fetchServerTokens()
                await store.refreshSubscriptionStatus()
            }
        }
        // Оверлей загрузки — системный спиннер
        .overlay(
            Group {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.28).ignoresSafeArea()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .controlSize(.large)
                            .tint(.white)
                            .scaleEffect(1.5)
                    }
                }
            }
        )
        .navigationTitle(holiday.title)
        .navigationBarTitleDisplayMode(.inline)
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
                .accessibilityLabel(appBundle().localizedString(forKey: "store.tokens.balance", value: "Баланс токенов", table: "Localizable"))
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { showCardPopup },
                set: { newValue in
                    DispatchQueue.main.async {
                        showCardPopup = newValue
                        if !newValue {
                            // refresh card history and clear image on close
                            cardHistory = CardHistoryManager.getCards(forHoliday: holiday.id)
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
                                showCardPopup = false
                            }
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                    .onAppear {
                        allowCardPopupClose = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            allowCardPopupClose = true
                        }
                    }
                }
                .interactiveDismissDisabled(true)
                .sheet(isPresented: $showCardShareSheet) {
                    ActivityViewController(activityItems: [image])
                }
            }
        }
        .sheet(isPresented: $showStore) {
            StoreView()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Button(action: { showCongratsActionSheet = true }) {
                    HStack(spacing: 10) {
                        Spacer()
                        Text(appBundle().localizedString(forKey: "card.generate", value: "Сгенерировать открытку", table: "Localizable"))
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 15, weight: .semibold))
                            Text("4")
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
        // Выбор: общая открытка или для контакта
        .confirmationDialog(
            appBundle().localizedString(forKey: "card.sheet.title", value: "Выберите тип открытки", table: "Localizable"),
            isPresented: $showCongratsActionSheet,
            titleVisibility: .visible
        ) {
            Button(appBundle().localizedString(forKey: "card.sheet.general", value: "Общая открытка", table: "Localizable")) {
                handleGenerate(for: nil)
            }
            Button(appBundle().localizedString(forKey: "card.sheet.for_person", value: "Для конкретного человека…", table: "Localizable")) {
                showContactPicker = true
            }
            Button(appBundle().localizedString(forKey: "common.cancel", value: "Отмена", table: "Localizable"), role: .cancel) {}
        }
        .sheet(isPresented: $showContactPicker) {
            ContactSelectSheetView(vm: vm) { contact in
                handleGenerate(for: contact)
            }
        }
    }

    // MARK: - Генерация открытки (обновлено)
    private func handleGenerate(for contact: Contact?) {
        guard !isLoading else { return }
        isLoading = true

        let completion = {
            DispatchQueue.main.async {
                self.cardHistory = CardHistoryManager.getCards(forHoliday: holiday.id)
                if let newCard = cardHistory.sorted(by: { $0.date > $1.date }).first,
                   let image = newCard.image {
                    self.cardPopupImage = image
                    self.showCardPopup = true
                }
                self.isLoading = false
                Task { await store.fetchServerTokens() }
            }
        }

        ChatGPTService.shared.generateCardForHoliday(
            holidayId: holiday.id,
            holidayTitle: holiday.title,
            contact: contact,
            completion: completion
        )
    }

}


// MARK: - История открыток (2-колоночная сетка)
@MainActor
private struct HolidayCardHistorySection: View {
    @Binding var cardHistory: [CardHistoryItemWithImage]
    let ownerId: UUID
    let onShowPopup: (UIImage) -> Void
    @State private var showCopyAnimation: [UUID: Bool] = [:]

    private var placeholderImage: UIImage { UIImage(systemName: "photo") ?? UIImage() }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appBundle().localizedString(forKey: "history.cards.title", value: "История открыток", table: "Localizable"))
                .font(.headline)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

            if cardHistory.isEmpty {
                Text(appBundle().localizedString(forKey: "history.cards.empty", value: "Нет открыток", table: "Localizable"))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(cardHistory, id: \.id) { item in
                        HolidayCardImageItem(
                            image: item.image ?? placeholderImage,
                            date: item.date,
                            onDelete: {
                                CardHistoryManager.deleteCard(item.id)
                                cardHistory = CardHistoryManager.getCards(forHoliday: ownerId)
                            },
                            onCopy: {
                                withAnimation(.spring()) { showCopyAnimation[item.id] = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    withAnimation { showCopyAnimation[item.id] = false }
                                }
                            },
                            showCopyAnimation: showCopyAnimation[item.id] ?? false,
                            onShowPopup: { image in onShowPopup(image) }
                        )
                    }
                }
            }
        }
    }
}
@MainActor
private struct HolidayCardImageItem: View {
    let image: UIImage
    let date: Date?
    let onDelete: () -> Void
    let onCopy: () -> Void
    let showCopyAnimation: Bool
    let onShowPopup: (UIImage) -> Void
    @State private var isShareSheetPresented = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
                    .onTapGesture { onShowPopup(image) }

                if let date {
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
                    Label(appBundle().localizedString(forKey: "common.copy", value: "Копировать", table: "Localizable"), systemImage: "doc.on.doc")
                }
                Button {
                    isShareSheetPresented = true
                } label: {
                    Label(appBundle().localizedString(forKey: "common.share", value: "Поделиться", table: "Localizable"), systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(appBundle().localizedString(forKey: "common.delete", value: "Удалить", table: "Localizable"), systemImage: "trash")
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
