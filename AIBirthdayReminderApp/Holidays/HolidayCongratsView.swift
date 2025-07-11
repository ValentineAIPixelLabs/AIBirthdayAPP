// MARK: - Обёртки для истории поздравлений и удаления

struct GeneratedText: Identifiable, Codable, Equatable {
    let id: UUID
    let value: String
}

struct GeneratedCard: Identifiable, Codable, Equatable {
    let id: UUID
    let imageData: Data
}

import SwiftUI
//import ButtonStyle
import UIKit

struct HolidayCongratsView: View {
    @ObservedObject var vm: ContactsViewModel
    let holiday: Holiday

    @State private var selectedStyle: CongratsStyle = .classic
    @State private var isGeneratingText = false
    @State private var isGeneratingCard = false
    @State private var generatedTexts: [GeneratedText] = []
    @State private var generatedCards: [GeneratedCard] = []

    @State private var shareItem: ShareItem?
    
    @State private var showCongratsActionSheet = false
    @State private var congratsActionType: CongratsActionType?
    @State private var showContactPicker = false
    @State private var selectedContact: Contact?
    
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            AppBackground()
                .onChange(of: generatedTexts) {
                    saveCongratsHistory()
                }
                .onChange(of: generatedCards) {
                    saveCardHistory()
                }
                .onAppear { loadCongratsHistory(); loadCardHistory() }

            HolidayCongratsMainContent(
                holiday: holiday,
                selectedStyle: $selectedStyle,
                isGeneratingText: $isGeneratingText,
                isGeneratingCard: $isGeneratingCard,
                generatedTexts: $generatedTexts,
                generatedCards: $generatedCards,
                shareText: .constant(nil), // not used
                shareImage: .constant(nil), // not used
                showCongratsActionSheet: $showCongratsActionSheet,
                congratsActionType: $congratsActionType,
                showContactPicker: $showContactPicker,
                selectedContact: $selectedContact,
                formattedDate: formattedDate,
                generateTextCongrats: generateTextCongrats,
                generateCardCongrats: generateCardCongrats,
                generatePersonalizedTextCongrats: generatePersonalizedTextCongrats,
                generatePersonalizedCardCongrats: generatePersonalizedCardCongrats,
                saveCongratsHistory: saveCongratsHistory,
                saveCardHistory: saveCardHistory,
                dismiss: dismiss,
                loadCongratsHistory: loadCongratsHistory,
                loadCardHistory: loadCardHistory,
                onGenerateText: { congratsActionType = .text; showCongratsActionSheet = true },
                onGenerateCard: { congratsActionType = .card; showCongratsActionSheet = true },
                onShareText: { shareItem = .text($0) },
                onDeleteText: { _ in },
                onShareImage: { shareItem = .image(UIImage(data: $0.imageData) ?? UIImage()) },
                onDeleteImage: { _ in }
            )
        }
        .confirmationDialog(
            "Выберите тип поздравления",
            isPresented: $showCongratsActionSheet,
            titleVisibility: .visible
        ) {
            Button("Общее поздравление") {
                if congratsActionType == .text {
                    generateTextCongrats()
                } else if congratsActionType == .card {
                    generateCardCongrats()
                }
            }
            Button("Поздравить конкретного человека…") {
                showContactPicker = true
            }
            Button("Отмена", role: .cancel) { }
        }
        .sheet(isPresented: $showContactPicker) {
            ContactSelectSheetView(vm: vm, onContactSelected: { contact in
                selectedContact = contact
                showContactPicker = false
                if congratsActionType == .text {
                    generatePersonalizedTextCongrats(for: contact)
                } else if congratsActionType == .card {
                    generatePersonalizedCardCongrats(for: contact)
                }
            })
        }
        .navigationBarBackButtonHidden(true)
        .sheet(item: $shareItem) { item in
            switch item {
            case .text(let text):
                ActivityView(activityItems: [text])
            case .image(let image):
                ActivityView(activityItems: [image])
            }
        }
        // Alerts for deleting moved to HolidayCongratsMainContent
    }

    // MARK: - Helpers

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }

    enum CongratsStyle: String, CaseIterable {
        case classic, funny, poetic
        var title: String {
            switch self {
            case .classic: return "Классика"
            case .funny: return "Смешное"
            case .poetic: return "Поэтичное"
            }
        }
    }
    
    enum CongratsActionType {
        case text, card
    }

    func generateTextCongrats() {
        isGeneratingText = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            generatedTexts.insert(GeneratedText(id: UUID(), value: "Текстовое поздравление (\(selectedStyle.title)) для '\(holiday.title)'"), at: 0)
            saveCongratsHistory()
            isGeneratingText = false
        }
    }
    func generateCardCongrats() {
        isGeneratingCard = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if let img = UIImage(systemName: "gift") {
                if let data = img.pngData() {
                    generatedCards.insert(GeneratedCard(id: UUID(), imageData: data), at: 0)
                    saveCardHistory()
                }
            }
            isGeneratingCard = false
        }
    }
    func generatePersonalizedTextCongrats(for contact: Contact) {
        isGeneratingText = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            generatedTexts.insert(GeneratedText(id: UUID(), value: "Персональное поздравление (\(selectedStyle.title)) для \(contact.fullName) и праздника '\(holiday.title)'"), at: 0)
            saveCongratsHistory()
            isGeneratingText = false
        }
    }
    func generatePersonalizedCardCongrats(for contact: Contact) {
        isGeneratingCard = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if let img = UIImage(systemName: "gift") {
                if let data = img.pngData() {
                    generatedCards.insert(GeneratedCard(id: UUID(), imageData: data), at: 0)
                    saveCardHistory()
                }
            }
            isGeneratingCard = false
        }
    }

    func saveCongratsHistory() {
        let key = "congrats_texts_\(holiday.id.uuidString)"
        if let data = try? JSONEncoder().encode(generatedTexts) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func loadCongratsHistory() {
        let key = "congrats_texts_\(holiday.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([GeneratedText].self, from: data) {
            DispatchQueue.main.async {
                generatedTexts = saved
            }
        }
    }
    
    func saveCardHistory() {
        let key = "congrats_cards_\(holiday.id.uuidString)"
        if let data = try? JSONEncoder().encode(generatedCards) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func loadCardHistory() {
        let key = "congrats_cards_\(holiday.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let arr = try? JSONDecoder().decode([GeneratedCard].self, from: data) {
            generatedCards = arr
        }
    }

    enum ShareItem: Identifiable {
        case text(String)
        case image(UIImage)

        var id: String {
            switch self {
            case .text(let text): return "text-\(text.hashValue)"
            case .image(let image): return "image-\(image.hashValue)"
            }
        }
    }
}

// MARK: - Main Content Component

private struct HolidayCongratsMainContent: View {
    let holiday: Holiday
    @Binding var selectedStyle: HolidayCongratsView.CongratsStyle
    @Binding var isGeneratingText: Bool
    @Binding var isGeneratingCard: Bool
    @Binding var generatedTexts: [GeneratedText]
    @Binding var generatedCards: [GeneratedCard]
    @Binding var shareText: String?
    @Binding var shareImage: UIImage?
    @Binding var showCongratsActionSheet: Bool
    @Binding var congratsActionType: HolidayCongratsView.CongratsActionType?
    @Binding var showContactPicker: Bool
    @Binding var selectedContact: Contact?

    let formattedDate: (Date) -> String
    let generateTextCongrats: () -> Void
    let generateCardCongrats: () -> Void
    let generatePersonalizedTextCongrats: (Contact) -> Void
    let generatePersonalizedCardCongrats: (Contact) -> Void
    let saveCongratsHistory: () -> Void
    let saveCardHistory: () -> Void
    let dismiss: DismissAction
    let loadCongratsHistory: () -> Void
    let loadCardHistory: () -> Void

    let onGenerateText: () -> Void
    let onGenerateCard: () -> Void

    // Новые параметры для контекстного меню
    let onShareText: (String) -> Void
    let onDeleteText: (GeneratedText) -> Void
    let onShareImage: (GeneratedCard) -> Void
    let onDeleteImage: (GeneratedCard) -> Void

    // Локальные состояния для алертов удаления
    @State private var localTextToDelete: GeneratedText?
    @State private var localCardToDelete: GeneratedCard?

    var body: some View {
        VStack(spacing: 0) {
            // Button("Тест Alert") {
            //     textToDelete = GeneratedText(id: UUID(), value: "Тест")
            // }
            // .padding()
            HStack(alignment: .center) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color.accentColor)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1)
                        )
                }
                Spacer()
            }
            .padding(.leading, 14)
            .padding(.top, 0)
            .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        if let icon = holiday.icon, !icon.isEmpty, icon.count == 1 {
                            Text(icon)
                                .font(.system(size: 38))
                        } else {
                            Image(systemName: "calendar")
                                .font(.system(size: 32))
                                .foregroundColor(.accentColor)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(holiday.title)
                                .font(.title2.bold())
                            Text(formattedDate(holiday.date))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Picker("Стиль поздравления", selection: $selectedStyle) {
                        ForEach(HolidayCongratsView.CongratsStyle.allCases, id: \.self) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 18) {
                        Button(action: {
                            onGenerateText()
                        }) {
                            if isGeneratingText {
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 56)
                            } else {
                                HStack(spacing: 10) {
                                    Image(systemName: "text.bubble")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(AppButtonStyle.Primary.textColor)
                                    VStack(spacing: 0) {
                                        Text("Сгенерировать")
                                        Text("текст")
                                    }
                                }
                                .font(AppButtonStyle.Primary.font)
                                .foregroundColor(AppButtonStyle.Primary.textColor)
                                .padding(.horizontal, AppButtonStyle.horizontalPadding)
                                .padding(.vertical, AppButtonStyle.verticalPadding)
                                .background(
                                    RoundedRectangle(cornerRadius: AppButtonStyle.cornerRadius, style: .continuous)
                                        .fill(AppButtonStyle.Primary.backgroundColor)
                                        .shadow(color: AppButtonStyle.Primary.shadow, radius: AppButtonStyle.Primary.shadowRadius, y: 2)
                                )
                                .frame(maxWidth: .infinity, minHeight: 56)
                            }
                        }
                        .disabled(isGeneratingText || isGeneratingCard)

                        Button(action: {
                            onGenerateCard()
                        }) {
                            if isGeneratingCard {
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 56)
                            } else {
                                HStack(spacing: 10) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(AppButtonStyle.Primary.textColor)
                                    Text("Открытка")
                                }
                                .font(AppButtonStyle.Primary.font)
                                .foregroundColor(AppButtonStyle.Primary.textColor)
                                .padding(.horizontal, AppButtonStyle.horizontalPadding)
                                .padding(.vertical, AppButtonStyle.verticalPadding)
                                .background(
                                    RoundedRectangle(cornerRadius: AppButtonStyle.cornerRadius, style: .continuous)
                                        .fill(AppButtonStyle.Primary.backgroundColor)
                                        .shadow(color: AppButtonStyle.Primary.shadow, radius: AppButtonStyle.Primary.shadowRadius, y: 2)
                                )
                                .frame(maxWidth: .infinity, minHeight: 56)
                            }
                        }
                        .disabled(isGeneratingText || isGeneratingCard)
                    }
                    .padding(.vertical, 6)

                    if !generatedTexts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("История поздравлений")
                                .font(.headline)
                            ForEach(generatedTexts, id: \.id) { item in
                                Text("• \(item.value)")
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                    .contextMenu {
                                        Button("Скопировать") {
                                            UIPasteboard.general.string = item.value
                                        }
                                        Button("Поделиться") {
                                            onShareText(item.value)
                                        }
                                        Button(role: .destructive) {
                                            localTextToDelete = item
                                        } label: {
                                            Label("Удалить", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.top, 10)
                        .alert(item: $localTextToDelete) { deletable in
                            Alert(
                                title: Text("Удалить поздравление?"),
                                message: Text(deletable.value),
                                primaryButton: .destructive(Text("Удалить")) {
                                    generatedTexts.removeAll { $0.id == deletable.id }
                                    saveCongratsHistory()
                                },
                                secondaryButton: .cancel()
                            )
                        }
                    }

                    if !generatedCards.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("История открыток")
                                .font(.headline)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(generatedCards) { card in
                                        Image(uiImage: UIImage(data: card.imageData) ?? UIImage())
                                            .resizable()
                                            .frame(width: 100, height: 100)
                                            .cornerRadius(10)
                                            .contextMenu {
                                                Button("Скопировать") {
                                                    if let img = UIImage(data: card.imageData) {
                                                        UIPasteboard.general.image = img
                                                    }
                                                }
                                                Button("Поделиться") {
                                                    onShareImage(card)
                                                }
                                                Button(role: .destructive) {
                                                    localCardToDelete = card
                                                } label: {
                                                    Label("Удалить", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                            }
                        }
                        .padding(.top, 10)
                        .alert(item: $localCardToDelete) { deletable in
                            Alert(
                                title: Text("Удалить открытку?"),
                                primaryButton: .destructive(Text("Удалить")) {
                                    generatedCards.removeAll { $0.id == deletable.id }
                                    saveCardHistory()
                                },
                                secondaryButton: .cancel()
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - ActivityView для шаринга
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
