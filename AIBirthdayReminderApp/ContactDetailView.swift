import SwiftUI
import UIKit

struct ContactDetailView: View {
    let isTestMode = false
    @ObservedObject var vm: ContactsViewModel
    let contactId: UUID

    
    @State private var pickedImage: UIImage?
    @State private var showAvatarSheet = false
    @State private var showImagePicker = false
    @State private var showCameraPicker = false
    @State private var showEmojiPicker = false
    @State private var showMonogramPicker = false
    @State private var pickedEmoji: String?
    @State private var pickedMonogram: String?
    @State private var monogramColor: Color = .blue

    @State private var showGreetingSheet = false
    @State private var isLoadingGreeting = false
    @State private var generatedGreeting: String?
    @State private var showApiKeyAlert = false
    @State private var greetingsHistory: [String] = []

    @State private var isLoadingCard = false
    @State private var generatedCardURL: URL?
    @State private var showCardSheet = false
    @State private var cardHistory: [URL] = []
    @State private var showCardHistorySheet = false
    @State private var cardGenerationError: String? = nil

    @AppStorage("openai_api_key") private var apiKey: String = ""
    // MARK: - Greetings History Storage Helpers
    func greetingsKey(for contactId: UUID) -> String {
        "greetings_history_\(contactId.uuidString)"
    }
    func loadHistory(for contactId: UUID) -> [String] {
        let key = greetingsKey(for: contactId)
        if let data = UserDefaults.standard.data(forKey: key),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            return arr
        }
        return []
    }
    func saveHistory(_ history: [String], for contactId: UUID) {
        let key = greetingsKey(for: contactId)
        let data = try? JSONEncoder().encode(history)
        UserDefaults.standard.set(data, forKey: key)
    }
    // MARK: - Card History Storage Helpers
    func cardHistoryKey(for contactId: UUID) -> String {
        "card_history_\(contactId.uuidString)"
    }
    func loadCardHistory(for contactId: UUID) -> [URL] {
        let key = cardHistoryKey(for: contactId)
        if let data = UserDefaults.standard.data(forKey: key),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            // Оставляем только реально существующие файлы
            return arr.compactMap { path in
                let url = URL(fileURLWithPath: path)
                return FileManager.default.fileExists(atPath: url.path) ? url : nil
            }
        }
        return []
    }
    func saveCardHistory(_ history: [URL], for contactId: UUID) {
        let key = cardHistoryKey(for: contactId)
        // Сохраняем только путь к локальному файлу
        let arr = history.map { $0.path }
        let data = try? JSONEncoder().encode(arr)
        UserDefaults.standard.set(data, forKey: key)
    }

    @Environment(\.dismiss) var dismiss
    @State private var selectedContactForEdit: Contact? = nil

    var contact: Contact? {
        vm.contacts.first(where: { $0.id == contactId })
    }

    let headerHeight: CGFloat = 360

    var body: some View {
        GeometryReader { geo in
            mainContent(geo: geo, contact: contact)
        }
        .onAppear {
            handleOnAppear()
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        
        .navigationDestination(item: $selectedContactForEdit) { contact in
                    EditContactView(vm: vm, contact: contact)
                }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        
        .sheet(isPresented: $showAvatarSheet) {
            AvatarPickerSheet(
                onCamera: {
                    showAvatarSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showCameraPicker = true }
                },
                onPhoto: {
                    showAvatarSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showImagePicker = true }
                },
                onEmoji: {
                    showAvatarSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showEmojiPicker = true }
                },
                onMonogram: {
                    showAvatarSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        if var contact = contact {
                            contact.imageData = nil
                            contact.emoji = nil
                            vm.updateContact(contact)
                        }
                        pickedImage = nil
                        pickedEmoji = nil
                        pickedMonogram = ""
                    }
                }
            )
            .presentationDetents([.height(225)])
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .sheet(isPresented: $showImagePicker) {
            PhotoPickerWithCrop { image in
                if let image = image, var contact = contact {
                    contact.imageData = image.jpegData(compressionQuality: 0.9)
                    contact.emoji = nil
                    vm.updateContact(contact)
                }
                pickedImage = nil
                pickedEmoji = nil
                pickedMonogram = ""
                showImagePicker = false
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .fullScreenCover(isPresented: $showCameraPicker) {
            CameraPicker(image: $pickedImage)
                .ignoresSafeArea()
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onChange(of: pickedMonogram) { newMonogram, _ in
            // Если выбрали монограмму, сбрасываем изображение и эмодзи и обновляем контакт
            if let newMonogram = newMonogram, !newMonogram.isEmpty {
                pickedImage = nil
                pickedEmoji = nil
                if var contact = contact {
                    contact.imageData = nil
                    contact.emoji = nil
                    vm.updateContact(contact)
                }
            }
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView { emoji in
                if let emoji = emoji, var contact = contact {
                    contact.emoji = emoji
                    contact.imageData = nil
                    vm.updateContact(contact)
                }
                pickedImage = nil
                pickedEmoji = nil
                pickedMonogram = ""
                showEmojiPicker = false
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .sheet(isPresented: $showMonogramPicker) {
            MonogramPickerView(selectedMonogram: $pickedMonogram, color: $monogramColor)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .fullScreenCover(isPresented: $showGreetingSheet) {
            GreetingFullScreenView(
                isPresented: $showGreetingSheet,
                greeting: generatedGreeting ?? "",
                greetings: greetingsHistory,
                onDelete: handleGreetingDelete,
                onGenerate: handleGreetingGenerate
            )
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
         .alert("API ключ не задан", isPresented: $showApiKeyAlert) {
             Button("OK", role: .cancel) {}
         } message: {
             Text("Пожалуйста, укажите API ключ OpenAI в настройках приложения.")
         }
        .fullScreenCover(isPresented: $showCardSheet) {
            CardFullScreenView(
                isPresented: $showCardSheet,
                imageURL: isLoadingCard ? nil : generatedCardURL,
                isLoading: isLoadingCard,
                errorMessage: cardGenerationError,
                onGenerateCard: handleCardGenerate,
                cards: $cardHistory,
                onDelete: handleCardDelete
            )
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
       
        
        .fullScreenCover(isPresented: $showCardHistorySheet) {
            CardsHistoryFullScreenView(
                isPresented: $showCardHistorySheet,
                cards: $cardHistory,
                onDelete: { idx in
                    if let contact = contact {
                        var history = cardHistory
                        // Удаляем файл физически
                        let fileURL = history[idx]
                        if FileManager.default.fileExists(atPath: fileURL.path) {
                            try? FileManager.default.removeItem(at: fileURL)
                        }
                        history.remove(at: idx)
                        saveCardHistory(history, for: contact.id)
                        cardHistory = history
                    }
                }
            )
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Main Content Layout
    private func mainContent(geo: GeometryProxy, contact: Contact?) -> some View {
        Group {
            if let contact = contact {
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.18),
                            Color.purple.opacity(0.16),
                            Color.teal.opacity(0.14)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    ZStack(alignment: .top) {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 20) {
                                // MARK: - Header
                                headerBlock(contact: contact)
                                // MARK: - BirthdayBlock
                                birthdayBlock(contact: contact)
                            // MARK: - DescriptionBlock (removed)
                            // MARK: - Дополнительные сведения о контакте
                            if let occupation = contact.occupation, !occupation.isEmpty {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "briefcase")
                                        .foregroundColor(.indigo)
                                        .font(.title3)
                                        .padding(.top, 2)
                                    Text(occupation)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                }
                                .padding()
                                .cardStyle()
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                            if let hobbies = contact.hobbies, !hobbies.isEmpty {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "soccerball")
                                        .foregroundColor(.green)
                                        .font(.title3)
                                        .padding(.top, 2)
                                    Text(hobbies)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                }
                                .padding()
                                .cardStyle()
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                            if let leisure = contact.leisure, !leisure.isEmpty {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "person.3.sequence")
                                        .foregroundColor(.orange)
                                        .font(.title3)
                                        .padding(.top, 2)
                                    Text(leisure)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                }
                                .padding()
                                .cardStyle()
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                            if let additionalInfo = contact.additionalInfo, !additionalInfo.isEmpty {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "lightbulb")
                                        .foregroundColor(.yellow)
                                        .font(.title3)
                                        .padding(.top, 2)
                                    Text(additionalInfo)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                }
                                .padding()
                                .cardStyle()
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                                // MARK: - ActionsPanel
                                actionsPanel(contact: contact)
                                    .padding(.bottom, 40)
                            }
                            .padding(.top, 80)
                        }
                        topButtons(geo: geo)
                    }
                    .edgesIgnoringSafeArea(.top)
                }
            }
        }
    }

    // MARK: - Header
    private func headerBlock(contact: Contact) -> some View {
        VStack(spacing: 10) {
            ContactAvatarHeaderView(
                contact: contact,
                pickedImage: pickedImage,
                pickedEmoji: pickedEmoji,
                headerHeight: 140,
                onTap: { showAvatarSheet = true }
            )
            // Имя и фамилия (крупно, по центру)
            if let surname = contact.surname, !surname.isEmpty {
                VStack(spacing: 0) {
                    Text(contact.name)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    Text(surname)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            } else {
                Text(contact.name)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            // Тип отношений — бейдж под именем/фамилией, если есть
            if let relation = contact.relationType, !relation.isEmpty {
                Text(relation)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.7))
                    )
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    // MARK: - BirthdayBlock
    private func birthdayBlock(contact: Contact) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .foregroundColor(.pink)
                .font(.title2)
            Text(formatBirthdayDate(birthday: contact.birthday))
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding()
        .cardStyle()
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - DescriptionBlock (удалён)

    // MARK: - ActionsPanel
    private func actionsPanel(contact: Contact) -> some View {
        let buttonSize: CGFloat = 64
        return HStack(alignment: .top, spacing: 22) {
            VStack(spacing: 4) {
                Button {
                    if apiKey.isEmpty {
                        showApiKeyAlert = true
                    } else {
                        // TEST MODE GREETING
                        if isTestMode {
                            generatedGreeting = "Тестовое поздравление! 🎉"
                            showGreetingSheet = true
                            greetingsHistory.insert("Тестовое поздравление! 🎉", at: 0)
                            saveHistory(greetingsHistory, for: contact.id)
                            return
                        } else {
                            isLoadingGreeting = true
                            showGreetingSheet = true
                            generatedGreeting = nil
                            ChatGPTService.shared.generateGreeting(for: contact, apiKey: apiKey) { result in
                                switch result {
                                case .success(let greeting):
                                    generatedGreeting = greeting
                                    greetingsHistory.insert(greeting, at: 0)
                                    saveHistory(greetingsHistory, for: contact.id)
                                case .failure(let error):
                                    generatedGreeting = "Ошибка генерации: \(error.localizedDescription)"
                                }
                                isLoadingGreeting = false
                            }
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: buttonSize, height: buttonSize)
                            .shadow(radius: 6)
                        Image(systemName: "sparkles")
                            .font(.title)
                            .foregroundColor(.yellow)
                    }
                }
                .buttonStyle(ActionButtonStyle())
                Text("Генерация\nпоздравления")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 4) {
                Button {
                    if apiKey.isEmpty {
                        showApiKeyAlert = true
                    } else {
                        // TEST MODE CARD
                        if isTestMode {
                            let testImage = UIImage(systemName: "photo")!
                            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_card.png")
                            try? testImage.pngData()?.write(to: tempURL)
                            generatedCardURL = tempURL
                            showCardSheet = true
                            cardHistory.insert(tempURL, at: 0)
                            saveCardHistory(cardHistory, for: contact.id)
                            return
                        } else {
                            isLoadingCard = true
                            showCardSheet = true
                            generatedCardURL = nil
                            cardGenerationError = nil
                            ChatGPTService.shared.generateCard(for: contact, apiKey: apiKey) { result in
                                switch result {
                                case .success(let url):
                                    generatedCardURL = url
                                    cardHistory.insert(url, at: 0)
                                    saveCardHistory(cardHistory, for: contact.id)
                                case .failure(let error):
                                    cardGenerationError = "Ошибка генерации открытки: \(error.localizedDescription)"
                                }
                                isLoadingCard = false
                            }
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: buttonSize, height: buttonSize)
                            .shadow(radius: 6)
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title)
                            .foregroundColor(.teal)
                    }
                }
                .buttonStyle(ActionButtonStyle())
                Text("Генерация\nоткрытки")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    // MARK: - Birthday Date Formatter
    private func formatBirthdayDate(birthday: Birthday?) -> String {
        guard let birthday = birthday else { return "Дата рождения не указана" }
        // Проверяем, заполнены ли хотя бы день или месяц
        if birthday.day == 0 && birthday.month == 0 {
            return "Дата рождения не указана"
        }
        let calendar = Calendar.current
        var components = DateComponents()
        components.day = birthday.day
        components.month = birthday.month
        components.year = birthday.year ?? 1900
        guard let date = calendar.date(from: components) else {
            return "Дата рождения не указана"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        if birthday.year != nil {
            formatter.dateFormat = "d MMMM yyyy"
            let dateString = formatter.string(from: date)
            let age = calculateAge(birthday: birthday)
            return "Дата рождения: \(dateString) (\(age) \(ageSuffix(age)))"
        } else {
            formatter.dateFormat = "d MMMM"
            let dateStringNoYear = formatter.string(from: date)
            return "Дата рождения: \(dateStringNoYear)"
        }
    }

    private func calculateAge(birthday: Birthday) -> Int {
        guard birthday.year != nil else { return 0 }
        let calendar = Calendar.current
        let now = Date()
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        var age = todayComponents.year! - birthday.year!
        if let bMonth = birthday.month as Int?, let bDay = birthday.day as Int? {
            if (todayComponents.month! < bMonth) || (todayComponents.month! == bMonth && todayComponents.day! < bDay) {
                age -= 1
            }
        }
        return age
    }

    private func ageSuffix(_ age: Int) -> String {
        let lastDigit = age % 10
        let lastTwo = age % 100
        if lastTwo >= 11 && lastTwo <= 14 {
            return "лет"
        }
        switch lastDigit {
        case 1: return "год"
        case 2, 3, 4: return "года"
        default: return "лет"
        }
    }

    // MARK: - Top Buttons ("Назад", "Править")
    private func topButtons(geo: GeometryProxy) -> some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial.opacity(0.9), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            Spacer()
            Button(action: {
                if let contact = contact {
                    selectedContactForEdit = contact
                }
            }) {
                Image(systemName: "pencil")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial.opacity(0.9), in: RoundedRectangle(cornerRadius: 15))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, geo.safeAreaInsets.top + 8)
    }

    // MARK: - OnAppear Handler
    private func handleOnAppear() {
        if let contact = contact {
            greetingsHistory = loadHistory(for: contact.id)
            cardHistory = loadCardHistory(for: contact.id)
        }
    }

    // MARK: - Greeting and Card Handlers
    private func handleGreetingDelete(idx: Int) {
        if let contact = contact {
            var history = greetingsHistory
            history.remove(at: idx)
            saveHistory(history, for: contact.id)
            greetingsHistory = history
        }
    }

    private func handleGreetingGenerate() {
        if apiKey.isEmpty {
            showApiKeyAlert = true
        } else {
            if isTestMode {
                generatedGreeting = "Тестовое поздравление! 🎉"
                showGreetingSheet = true
                greetingsHistory.insert("Тестовое поздравление! 🎉", at: 0)
                saveHistory(greetingsHistory, for: contact?.id ?? UUID())
            } else {
                isLoadingGreeting = true
                showGreetingSheet = true
                generatedGreeting = nil
                if let contact = contact {
                    ChatGPTService.shared.generateGreeting(for: contact, apiKey: apiKey) { result in
                        switch result {
                        case .success(let greeting):
                            generatedGreeting = greeting
                            greetingsHistory.insert(greeting, at: 0)
                            saveHistory(greetingsHistory, for: contact.id)
                        case .failure(let error):
                            generatedGreeting = "Ошибка генерации: \(error.localizedDescription)"
                        }
                        isLoadingGreeting = false
                    }
                }
            }
        }
    }

    private func handleCardGenerate() {
        if apiKey.isEmpty {
            showApiKeyAlert = true
        } else {
            if isTestMode {
                let testImage = UIImage(systemName: "photo")!
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_card.png")
                try? testImage.pngData()?.write(to: tempURL)
                generatedCardURL = nil
                DispatchQueue.main.async {
                    generatedCardURL = tempURL
                    showCardSheet = true
                }
                cardHistory.insert(tempURL, at: 0)
                saveCardHistory(cardHistory, for: contact?.id ?? UUID())
                return
            } else {
                isLoadingCard = true
                showCardSheet = true
                generatedCardURL = nil
                cardGenerationError = nil
                if let contact = contact {
                    ChatGPTService.shared.generateCard(for: contact, apiKey: apiKey) { result in
                        switch result {
                        case .success(let url):
                            generatedCardURL = url
                            cardHistory.insert(url, at: 0)
                            saveCardHistory(cardHistory, for: contact.id)
                        case .failure(let error):
                            cardGenerationError = "Ошибка генерации открытки: \(error.localizedDescription)"
                        }
                        isLoadingCard = false
                    }
                }
            }
        }
    }

    private func handleCardDelete(idx: Int) {
        if let contact = contact {
            var history = cardHistory
            let fileURL = history[idx]
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }
            history.remove(at: idx)
            saveCardHistory(history, for: contact.id)
            cardHistory = history
        }
    }
}


