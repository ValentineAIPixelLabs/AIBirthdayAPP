import SwiftUI
import UIKit

struct ContactDetailView: View {
    let isTestMode = false
    @ObservedObject var vm: ContactsViewModel
    let contactId: UUID

    
    @State private var greetingsHistory: [String] = []
    private let cardHistoryKey: String
    private let greetingsHistoryKey: String
    @State private var pickedImage: UIImage?
    @State private var cardHistory: [URL] = []
    @State private var showAvatarSheet = false
    @State private var showImagePicker = false
    @State private var showCameraPicker = false
    @State private var showEmojiPicker = false
    @State private var showMonogramPicker = false
    @State private var pickedEmoji: String?
    @State private var pickedMonogram: String?
    @State private var monogramColor: Color = .blue
    @State private var showGreetingScreen = false
    @State private var showCardScreen = false

    // Удалены состояния, связанные с генерацией поздравлений и открыток

    @AppStorage("openai_api_key") private var apiKey: String = ""

    @Environment(\.dismiss) var dismiss
    @State private var selectedContactForEdit: Contact? = nil

    var contact: Contact? {
        vm.contacts.first(where: { $0.id == contactId })
    }

    init(vm: ContactsViewModel, contactId: UUID) {
        self.vm = vm
        self.contactId = contactId
        self.cardHistoryKey = "cardHistory_\(contactId.uuidString)"
        self.greetingsHistoryKey = "greetingsHistory_\(contactId.uuidString)"
    }

    let headerHeight: CGFloat = 360

    var body: some View {
        GeometryReader { geo in
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
                                headerBlock(contact: contact)
                                birthdayBlock(contact: contact)
                                occupationBlock(contact: contact)
                                hobbiesBlock(contact: contact)
                                leisureBlock(contact: contact)
                                additionalInfoBlock(contact: contact)
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
        // onAppear без вызова handleOnAppear
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
        
        .onAppear {
            loadHistories()
        }
        .fullScreenCover(isPresented: $showGreetingScreen) {
            if let contact = contact {
                GreetingFullScreenView(
                    isPresented: $showGreetingScreen,
                    greetings: $greetingsHistory,
                    onDelete: { idx in
                        greetingsHistory.remove(at: idx)
                        saveGreetingsHistory()
                    },
                    onSaveGreeting: { newGreeting in
                        greetingsHistory.insert(newGreeting, at: 0)
                        saveGreetingsHistory()
                    },
                    contact: contact,
                    apiKey: apiKey,
                    isTestMode: isTestMode
                )
            } else {
                EmptyView()
            }
        }
        .fullScreenCover(isPresented: $showCardScreen) {
            if let contact = contact {
                CardFullScreenView(
                    isPresented: $showCardScreen,
                    cards: $cardHistory,
                    onDelete: { idx in
                        cardHistory.remove(at: idx)
                        saveCardHistory()
                    },
                    onSaveCard: { url in
                        cardHistory.insert(url, at: 0)
                        saveCardHistory()
                    },
                    contact: contact,
                    apiKey: apiKey,
                    isTestMode: isTestMode
                )
            } else {
                EmptyView()
            }
        }
    }


    // MARK: - Occupation Block
    private func occupationBlock(contact: Contact) -> some View {
        Group {
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
        }
    }

    // MARK: - Hobbies Block
    private func hobbiesBlock(contact: Contact) -> some View {
        Group {
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
        }
    }

    // MARK: - Leisure Block
    private func leisureBlock(contact: Contact) -> some View {
        Group {
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
        }
    }

    // MARK: - Additional Info Block
    private func additionalInfoBlock(contact: Contact) -> some View {
        Group {
            if let info = contact.additionalInfo, !info.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.yellow)
                        .font(.title3)
                        .padding(.top, 2)
                    Text(info)
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

    // MARK: - ActionsPanel (оставлены только две кнопки перехода)
    private func actionsPanel(contact: Contact) -> some View {
        let buttonSize: CGFloat = 64
        return HStack(alignment: .top, spacing: 22) {
            VStack(spacing: 4) {
                Button {
                    showGreetingScreen = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: buttonSize, height: buttonSize)
                            .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
                        Image(systemName: "sparkles")
                            .font(.title)
                            .foregroundColor(.yellow)
                    }
                }
                .buttonStyle(ActionButtonStyle())
                Text("Генерация поздравления")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 4) {
                Button {
                    showCardScreen = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: buttonSize, height: buttonSize)
                            .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title)
                            .foregroundColor(.teal)
                    }
                }
                .buttonStyle(ActionButtonStyle())
                Text("Генерация открытки")
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
            if age < 0 {
                return "Дата рождения: \(dateString)"
            } else {
                return "Дата рождения: \(dateString) (\(age) \(ageSuffix(age)))"
            }
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
                    .background(
                        Circle().fill(Color.white.opacity(0.3))
                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1)
                            )
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
                    .background(
                        Circle().fill(Color.white.opacity(0.3))
                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1)
                            )
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, geo.safeAreaInsets.top + 8)
    }

    // Удалены handleOnAppear, handleGreetingDelete, handleCardDelete

    private func saveCardHistory() {
        let urlStrings = cardHistory.map { $0.absoluteString }
        UserDefaults.standard.set(urlStrings, forKey: cardHistoryKey)
    }

    private func saveGreetingsHistory() {
        UserDefaults.standard.set(greetingsHistory, forKey: greetingsHistoryKey)
    }

    private func loadHistories() {
        if let savedCardURLs = UserDefaults.standard.stringArray(forKey: cardHistoryKey) {
            cardHistory = savedCardURLs.compactMap { URL(string: $0) }
        }

        if let savedGreetings = UserDefaults.standard.stringArray(forKey: greetingsHistoryKey) {
            greetingsHistory = savedGreetings
        }
    }
}


