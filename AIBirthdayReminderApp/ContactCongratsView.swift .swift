//
//  ContactCongratsView.swift .swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 06.07.2025.
//


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

// MARK: - Main View
struct ContactCongratsView: View {
    @Binding var contact: Contact

    @State private var selectedStyle: CongratsStyle = .classic
    @State private var isLoading = false
    @State private var alertMessage: String? = nil
    @State private var showCardFullScreen = false
    @State private var selectedCardID: String? = nil
    @State private var cardURLsState: [URL] = []

    // Computed property for [URL]
    private var cardURLs: [URL] {
        contact.cardHistory.compactMap { card in
            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            return documentsURL?.appendingPathComponent("Cards").appendingPathComponent(card.cardID)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text(contact.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)

                // Style Picker
                Picker("Стиль поздравления", selection: $selectedStyle) {
                    ForEach(CongratsStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                // Generate Buttons
                generateButtons()

                // History Sections
                VStack(spacing: 24) {
                    ContactCongratsHistorySection(contact: $contact)
                    ContactCardsHistorySection(contact: $contact, selectedCardID: $selectedCardID, showCardFullScreen: $showCardFullScreen)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
        .fullScreenCover(isPresented: $showCardFullScreen) {
            CardFullScreenView(
                isPresented: $showCardFullScreen,
                cards: $cardURLsState,
                onDelete: { index in
                    let url = cardURLsState[index]
                    if let fileName = url.pathComponents.last {
                        contact.cardHistory.removeAll { $0.cardID == fileName }
                    }
                    cardURLsState = cardURLs // обновить после удаления
                },
                onSaveCard: { url in
                    let fileName = url.lastPathComponent
                    let newCard = CardHistoryItem(date: Date(), cardID: fileName)
                    contact.cardHistory.append(newCard)
                    cardURLsState = cardURLs // обновить после добавления
                },
                contact: contact,
                apiKey: UserDefaults.standard.string(forKey: "openai_api_key") ?? "",
                isTestMode: false
            )
        }
        .onAppear {
            var contactCopy = contact
            loadCongratsHistory(for: &contactCopy)
            loadCardHistory(for: &contactCopy)
            contact = contactCopy
            cardURLsState = cardURLs
        }
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
                            contact.congratsHistory.append(newCongrats)
                            saveCongratsHistory(for: contact)
                            let key = "CongratsHistory_\(contact.id.uuidString)"
                            if UserDefaults.standard.data(forKey: key) == nil {
                                alertMessage = "Ошибка: поздравление не сохранено. Попробуйте ещё раз"
                            }
                        case .failure(let error):
                            alertMessage = error.localizedDescription
                        }
                    }
                }
            }) {
                Label("Новое поздравление", systemImage: "wand.and.stars")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .opacity(isLoading ? 0.6 : 1)
            .disabled(isLoading)

            Button(action: {
                isLoading = true
                let apiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
                ChatGPTService.shared.generateCard(for: contact, apiKey: apiKey) { result in
                    DispatchQueue.main.async {
                        isLoading = false
                        switch result {
                        case .success(let url):
                            if FileManager.default.fileExists(atPath: url.path) {
                                let fileName = url.lastPathComponent
                                let newCard = CardHistoryItem(date: Date(), cardID: fileName)
                                contact.cardHistory.insert(newCard, at: 0)
                                saveCardHistory(for: contact)
                            } else {
                                alertMessage = "Ошибка: открытка не была сохранена. Повторите попытку."
                            }
                        case .failure(let error):
                            alertMessage = error.localizedDescription
                        }
                    }
                }
            }) {
                Label("Новая открытка", systemImage: "photo.on.rectangle.angled")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .opacity(isLoading ? 0.6 : 1)
            .disabled(isLoading)
        }
        .padding(.horizontal)
    }

    // MARK: - Storage for Congrats History
    private func saveCongratsHistory(for contact: Contact) {
        let key = "CongratsHistory_\(contact.id.uuidString)"
        if let data = try? JSONEncoder().encode(contact.congratsHistory) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    private func loadCongratsHistory(for contact: inout Contact) {
        let key = "CongratsHistory_\(contact.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let history = try? JSONDecoder().decode([CongratsHistoryItem].self, from: data) {
            contact.congratsHistory = history
        }
    }

    // MARK: - Storage for Card History
    private func saveCardHistory(for contact: Contact) {
        let key = "CardHistory_\(contact.id.uuidString)"
        if let data = try? JSONEncoder().encode(contact.cardHistory) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    private func loadCardHistory(for contact: inout Contact) {
        let key = "CardHistory_\(contact.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let history = try? JSONDecoder().decode([CardHistoryItem].self, from: data) {
            contact.cardHistory = history
        }
    }
}

// MARK: - ContactCongratsHistorySection
private struct ContactCongratsHistorySection: View {
    @Binding var contact: Contact

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("История поздравлений")
                    .font(.headline)
                    .padding(.bottom, 4)
                if contact.congratsHistory.isEmpty {
                    Text("Нет поздравлений")
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                } else {
                    ForEach(contact.congratsHistory) { item in
                        CongratsHistoryItemView(item: item, contact: $contact)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
    }
}

private struct CongratsHistoryItemView: View {
    let item: CongratsHistoryItem
    @Binding var contact: Contact
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
        .background(Color(.systemBackground))
        .cornerRadius(12)
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
                contact.congratsHistory.removeAll { $0.id == item.id }
                // Save after removal
                if let save = ContactCongratsViewHelpers.saveCongratsHistoryFunc {
                    save(contact)
                    // Проверяем, что UserDefaults содержит данные
                    let key = "CongratsHistory_\(contact.id.uuidString)"
                    if UserDefaults.standard.data(forKey: key) == nil {
                        alertMessage = "Ошибка: поздравление не удалено. Попробуйте ещё раз"
                    }
                }
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

// MARK: - ContactCardsHistorySection
private struct ContactCardsHistorySection: View {
    @Binding var contact: Contact
    @Binding var selectedCardID: String?
    @Binding var showCardFullScreen: Bool

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("История открыток")
                    .font(.headline)
                    .padding(.bottom, 4)
                if contact.cardHistory.isEmpty {
                    Text("Нет открыток")
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                } else {
                    ForEach(contact.cardHistory) { card in
                        CardHistoryItemView(card: card, contact: $contact, selectedCardID: $selectedCardID, showCardFullScreen: $showCardFullScreen)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
    }
}

private struct CardHistoryItemView: View {
    let card: CardHistoryItem
    @Binding var contact: Contact
    @Binding var selectedCardID: String?
    @Binding var showCardFullScreen: Bool

    // Computed property to get card image URL if exists
    var cardImageURL: URL? {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let url = documentsURL?.appendingPathComponent("Cards").appendingPathComponent(card.cardID)
        if let url = url, FileManager.default.fileExists(atPath: url.path) {
            return url
        } else {
            return nil
        }
    }

    @State private var sharingURL: URL? = nil
    @State private var isShareSheetPresented = false

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            if let url = cardImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, minHeight: 180)
                            .cornerRadius(16)
                            .shadow(radius: 6)
                    case .failure(_):
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 180)
                            .foregroundColor(.accentColor)
                    @unknown default:
                        EmptyView()
                    }
                }
                .onTapGesture {
                    selectedCardID = card.cardID
                    showCardFullScreen = true
                }
            } else {
                Text("Файл открытки не найден. Проверьте папку Cards.")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(Color.red)
                    .cornerRadius(12)
                    .multilineTextAlignment(.center)
            }
            Text(card.date, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .contextMenu {
            Button {
                if let url = cardImageURL,
                   let data = try? Data(contentsOf: url),
                   let uiImage = UIImage(data: data) {
                    UIPasteboard.general.image = uiImage
                }
            } label: {
                Label("Копировать", systemImage: "doc.on.doc")
            }
            Button {
                if let url = cardImageURL {
                    sharingURL = url
                    isShareSheetPresented = true
                }
            } label: {
                Label("Поделиться", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) {
                // Получаем cardImageURL перед удалением
                let url = cardImageURL
                if let url = url, FileManager.default.fileExists(atPath: url.path) {
                    try? FileManager.default.removeItem(at: url)
                }
                contact.cardHistory.removeAll { $0.id == card.id }
                // Save after removal
                if let save = ContactCongratsViewHelpers.saveCardHistoryFunc {
                    save(contact)
                }
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
        .sheet(isPresented: $isShareSheetPresented) {
            if let sharingURL = sharingURL {
                ActivityViewController(activityItems: [sharingURL])
            }
        }
        Divider()
    }
}

// MARK: - Helper for Save Functions
private struct ContactCongratsViewHelpers {
    static var saveCongratsHistoryFunc: ((Contact) -> Void)?
    static var saveCardHistoryFunc: ((Contact) -> Void)?
}

// MARK: - Preview
#if DEBUG
struct ContactCongratsView_Previews: PreviewProvider {
    @State static var contact1 = Contact(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "Александр",
        surname: "Дротенко",
        nickname: nil as String?,
        relationType: "Друг",
        gender: "М",
        birthday: Birthday(day: 7, month: 6, year: 1991),
        notificationSettings: NotificationSettings.default,
        imageData: nil as Data?,
        emoji: "🎂" as String?,
        occupation: "Разработчик",
        hobbies: "Музыка",
        leisure: "Путешествия",
        additionalInfo: nil as String?,
        phoneNumber: "+37377123456"
    )
    @State static var contact2 = Contact(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        name: "Мария",
        surname: "Иванова",
        nickname: "Маша" as String?,
        relationType: "Коллега",
        gender: "Ж",
        birthday: Birthday(day: 15, month: 12, year: 1988),
        notificationSettings: NotificationSettings.default,
        imageData: nil as Data?,
        emoji: "🎉" as String?,
        occupation: "Дизайнер",
        hobbies: "Рисование",
        leisure: "Чтение",
        additionalInfo: "Любит кофе" as String?,
        phoneNumber: "+37377223344"
    )

    static var previews: some View {
        // Register save functions for contextMenu removals
        ContactCongratsViewHelpers.saveCongratsHistoryFunc = { contact in
            let key = "CongratsHistory_\(contact.id.uuidString)"
            if let data = try? JSONEncoder().encode(contact.congratsHistory) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
        ContactCongratsViewHelpers.saveCardHistoryFunc = { contact in
            let key = "CardHistory_\(contact.id.uuidString)"
            if let data = try? JSONEncoder().encode(contact.cardHistory) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
        return Group {
            ContactCongratsView(contact: $contact1)
                .preferredColorScheme(.light)
            ContactCongratsView(contact: $contact2)
                .preferredColorScheme(.dark)
        }
    }
}
#endif
