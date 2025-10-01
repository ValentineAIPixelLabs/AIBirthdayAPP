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

@MainActor struct HolidayCongratsTextView: View {
    let holiday: Holiday
    @ObservedObject var vm: ContactsViewModel
    @EnvironmentObject var store: StoreKitManager

    // История поздравлений по празднику
    @State private var history: [CongratsHistoryItem] = []

    // UI state
    @State private var showCongratsActionSheet = false
    @State private var showContactPicker = false
    @State private var showShareSheet = false
    @State private var selectedCongrats: String?
    @State private var isGenerating = false
    @State private var showCongratsPopup = false
    @State private var showStore = false
    @State private var isRegenerating = false


    @Environment(\.dismiss) private var dismiss
    // работает

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        holidayHeader


                        // История поздравлений — стиль как в ContactCongratsView
                        HolidayCongratsHistorySection(
                            history: history,
                            onDelete: { item in
                                DispatchQueue.main.async {
                                    CongratsHistoryManager.deleteCongrats(item.id)
                                    history = CongratsHistoryManager.getCongrats(forHoliday: holiday.id)
                                }
                            },
                            onShowPopup: { message in
                                DispatchQueue.main.async {
                                    selectedCongrats = message
                                    showCongratsPopup = true
                                }
                            }
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }
            // Индикатор генерации
            .overlay(
                Group {
                    if isGenerating {
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
            .onAppear {
                history = CongratsHistoryManager.getCongrats(forHoliday: holiday.id)
                Task {
                    await store.fetchServerTokens()
                    await store.refreshSubscriptionStatus()
                }
            }

            // Полноэкранный попап результата — как в ContactCongratsView
            if showCongratsPopup, let selected = selectedCongrats {
                Color.clear
                    .fullScreenCover(isPresented: Binding(
                        get: { showCongratsPopup },
                        set: { newValue in
                            DispatchQueue.main.async { showCongratsPopup = newValue }
                        }
                    )) {
                        ZStack {
                            AppBackground().ignoresSafeArea()
                            CongratsResultPopup(
                                message: selected,
                                onCopy: { UIPasteboard.general.string = selected },
                                onShare: {
                                    // Закрываем попап и вызываем системный ShareSheet
                                    showCongratsPopup = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        showShareSheet = true
                                    }
                                },
                                onRegenerate: {
                                    isRegenerating = true
                                    ChatGPTService.shared.generateHolidayGreeting(for: holiday.title) { result in
                                        DispatchQueue.main.async {
                                            isRegenerating = false
                                            switch result {
                                            case .success(let text):
                                                let item = CongratsHistoryItem(id: UUID(), date: Date(), message: text)
                                                history.insert(item, at: 0)
                                                CongratsHistoryManager.addCongratsForHoliday(item: item, holidayId: holiday.id)
                                                selectedCongrats = text
                                                Task { await store.fetchServerTokens() }
                                            case .failure(let error):
                                                let fmt1 = appBundle().localizedString(forKey: "error.generation_prefix", value: "Ошибка генерации: %@", table: "Localizable")
                                                selectedCongrats = String(format: fmt1, error.localizedDescription)
                                            }
                                        }
                                    }
                                },
                                onClose: { showCongratsPopup = false },
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
                    }
            }
        }
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Button(action: { showCongratsActionSheet = true }) {
                    HStack(spacing: 10) {
                        Spacer()
                        Text(appBundle().localizedString(forKey: "congrats.generate",
                                                         value: "Сгенерировать поздравление",
                                                         table: "Localizable"))
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
                .opacity(isGenerating ? 0.6 : 1)
                .disabled(isGenerating)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let selected = selectedCongrats {
                ActivityViewController(activityItems: [selected])
            }
        }
        .sheet(isPresented: $showStore) {
            PaywallView()
        }
        .confirmationDialog(
            appBundle().localizedString(forKey: "congrats.sheet.title",
                                        value: "Выберите тип поздравления",
                                        table: "Localizable"),
            isPresented: $showCongratsActionSheet,
            titleVisibility: .visible
        ) {
            Button(appBundle().localizedString(forKey: "congrats.generic",
                                               value: "Общее поздравление",
                                               table: "Localizable")) {
                generateCongrats(for: nil)
            }
            Button(appBundle().localizedString(forKey: "congrats.for_person",
                                               value: "Поздравить конкретного человека…",
                                               table: "Localizable")) {
                showContactPicker = true
            }
            Button(appBundle().localizedString(forKey: "common.cancel",
                                               value: "Отмена",
                                               table: "Localizable"), role: .cancel) {}
        }
        .sheet(isPresented: $showContactPicker) {
            ContactSelectSheetView(vm: vm) { contact in
                generateCongrats(for: contact)
            }
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
                .accessibilityLabel(appBundle().localizedString(forKey: "store.tokens.balance",
                                                                value: "Баланс токенов",
                                                                table: "Localizable"))
            }
        }
    }

    private var navigationTitleText: String {
        appBundle().localizedString(forKey: "popup.congrats.title", value: "Поздравление", table: "Localizable")
    }

    private var holidayHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(holiday.title)
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    // Генерация поздравления (логика сохранения — как в исходном файле)
    private func generateCongrats(for contact: Contact?) {
        isGenerating = true

        let onSuccess: (String) -> Void = { congrats in
            let holidayItem = CongratsHistoryItem(id: UUID(), date: Date(), message: congrats)
            // Сразу обновляем UI, как в ContactCongratsView
            history.insert(holidayItem, at: 0)
            CongratsHistoryManager.addCongratsForHoliday(item: holidayItem, holidayId: holiday.id)

            if let contact = contact {
                let contactItem = CongratsHistoryItem(id: UUID(), date: Date(), message: congrats)
                CongratsHistoryManager.addCongrats(item: contactItem, for: contact.id)
            }

            selectedCongrats = congrats
            showCongratsPopup = true
        }

        let onFailure: (Error) -> Void = { error in
            let fmt2 = appBundle().localizedString(forKey: "error.generation_prefix", value: "Ошибка генерации: %@", table: "Localizable")
            selectedCongrats = String(format: fmt2, error.localizedDescription)
            showCongratsPopup = true
        }

        if let contact = contact {
            ChatGPTService.shared.generateHolidayGreeting(for: contact, holidayTitle: holiday.title) { result in
                DispatchQueue.main.async {
                    isGenerating = false
                    switch result {
                    case .success(let congrats): onSuccess(congrats)
                    case .failure(let err): onFailure(err)
                    }
                }
            }
        } else {
            ChatGPTService.shared.generateHolidayGreeting(for: holiday.title) { result in
                DispatchQueue.main.async {
                    isGenerating = false
                    switch result {
                    case .success(let congrats): onSuccess(congrats)
                    case .failure(let err): onFailure(err)
                    }
                }
            }
        }
    }
}

// MARK: - История поздравлений (визуально как в ContactCongratsView)
@MainActor private struct HolidayCongratsHistorySection: View {
    let history: [CongratsHistoryItem]
    let onDelete: (CongratsHistoryItem) -> Void
    let onShowPopup: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appBundle().localizedString(forKey: "history.congrats.title",
                                             value: "История поздравлений",
                                             table: "Localizable"))
                .font(.headline)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

            if history.isEmpty {
                Text(appBundle().localizedString(forKey: "history.congrats.empty",
                                                 value: "Нет поздравлений",
                                                 table: "Localizable"))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 12) {
                    ForEach(history) { item in
                        HolidayCongratsHistoryItemView(
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

@MainActor private struct HolidayCongratsHistoryItemView: View {
    let item: CongratsHistoryItem
    let onDelete: () -> Void
    let onShowPopup: () -> Void
    @State private var isShareSheetPresented = false
    @State private var sharingText: String? = nil

    private let maxPreviewChars = 140
    private var previewText: String {
        let trimmed = item.message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > maxPreviewChars ? String(trimmed.prefix(maxPreviewChars)) + "…" : trimmed
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
        .onTapGesture { onShowPopup() }
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
                DispatchQueue.main.async {
                    UIPasteboard.general.string = item.message
                }
            } label: {
                Label(appBundle().localizedString(forKey: "common.copy", value: "Копировать", table: "Localizable"), systemImage: "doc.on.doc")
            }
            Button {
                DispatchQueue.main.async {
                    sharingText = item.message
                    isShareSheetPresented = true
                }
            } label: {
                Label(appBundle().localizedString(forKey: "common.share", value: "Поделиться", table: "Localizable"), systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) {
                DispatchQueue.main.async {
                    onDelete()
                }
            } label: {
                Label(appBundle().localizedString(forKey: "common.delete", value: "Удалить", table: "Localizable"), systemImage: "trash")
            }
        }
        .sheet(isPresented: $isShareSheetPresented) {
            if let sharingText { ActivityViewController(activityItems: [sharingText]) }
        }
    }
}
