import Foundation
import CoreData

class ContactsViewModel: ObservableObject {
    enum AppColorScheme: String, CaseIterable, Identifiable, Codable {
        case system, light, dark
        var id: String { rawValue }
        var label: String {
            switch self {
            case .system: return "Авто"
            case .light: return "Дневной"
            case .dark: return "Ночной"
            }
        }
    }
    @Published var contacts: [Contact] = []
    @Published var isPresentingAdd: Bool = false
    @Published var editingContact: Contact? = nil
    @Published var isEditingContactPresented: Bool = false
    @Published var globalNotificationSettings: NotificationSettings = .default {
        didSet {
            saveNotificationSettings()
        }
    }
    
    @Published var colorScheme: AppColorScheme = .system {
        didSet {
            UserDefaults.standard.set(colorScheme.rawValue, forKey: "colorScheme")
        }
    }
    
    // Мульти-выделение для удаления
    @Published var isSelectionMode: Bool = false
    @Published var selectedContactIDs: Set<UUID> = []

    /// Войти в режим выделения
    func enterSelectionMode() {
        isSelectionMode = true
        selectedContactIDs = []
    }

    /// Выйти из режима выделения
    func exitSelectionMode() {
        isSelectionMode = false
        selectedContactIDs = []
    }

    /// Переключить выделение контакта
    func toggleSelection(for contact: Contact) {
        if selectedContactIDs.contains(contact.id) {
            selectedContactIDs.remove(contact.id)
        } else {
            selectedContactIDs.insert(contact.id)
        }
    }

    /// Отметить все контакты
    func selectAllContacts() {
        selectedContactIDs = Set(contacts.map { $0.id })
    }

    /// Снять выделение со всех
    func deselectAllContacts() {
        selectedContactIDs = []
    }

    /// Удалить выделенные контакты
    func deleteSelectedContacts() {
        let idsToDelete = selectedContactIDs
        for id in idsToDelete {
            if let contact = contacts.first(where: { $0.id == id }) {
                NotificationManager.shared.removeBirthdayNotifications(for: contact)
                deleteContactFromCoreData(contact.id)
            }
        }
        contacts.removeAll { idsToDelete.contains($0.id) }
        selectedContactIDs = []
        isSelectionMode = false
        print("Удалены выделенные контакты: \(idsToDelete)")
    }
    
    private let notificationSettingsKey = "globalNotificationSettings"
    private let context = CoreDataManager.shared.context
    
    var sortedContacts: [Contact] {
        contacts.sorted(by: {
            guard let birthday0 = $0.birthday else { return false }
            guard let birthday1 = $1.birthday else { return true }
            let days0 = daysUntilNextBirthday(from: birthday0)
            let days1 = daysUntilNextBirthday(from: birthday1)
            if days0 == days1 {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return days0 < days1
        })
    }
    
    init() {
        loadNotificationSettings()
        if let stored = UserDefaults.standard.string(forKey: "colorScheme"),
           let scheme = AppColorScheme(rawValue: stored) {
            colorScheme = scheme
        }
        loadContactsFromCoreData()
    }
    
    func addContact(_ contact: Contact) {
        contacts.append(contact)
        saveContactToCoreData(contact)
        NotificationManager.shared.scheduleBirthdayNotifications(for: contact, settings: contact.notificationSettings)
        print("Добавлен контакт: \(contact.name), id: \(contact.id)")
    }
    
    func removeContact(at offsets: IndexSet) {
        for index in offsets {
            let contact = contacts[index]
            NotificationManager.shared.removeBirthdayNotifications(for: contact)
            deleteContactFromCoreData(contact.id)
            print("Удалён контакт: \(contact.name), id: \(contact.id)")
        }
        contacts.remove(atOffsets: offsets)
    }
    
    func removeContact(_ contact: Contact) {
        removeContactById(contact.id)
        print("Удалён контакт по id: \(contact.id)")
    }
    
    func updateContact(_ updated: Contact) {
        if let idx = contacts.firstIndex(where: { $0.id == updated.id }) {
            contacts[idx] = updated
            contacts = contacts
            saveContactToCoreData(updated)
            NotificationManager.shared.scheduleBirthdayNotifications(for: updated, settings: updated.notificationSettings)
            print("Обновлён контакт: \(updated.name), id: \(updated.id)")
        }
    }
    
    func removeContactById(_ id: UUID) {
        if let idx = contacts.firstIndex(where: { $0.id == id }) {
            contacts.remove(at: idx)
            deleteContactFromCoreData(id)
            print("Контакт удалён из массива и CoreData: \(id)")
        }
    }
    
    private func loadContactsFromCoreData() {
        let fetchRequest: NSFetchRequest<ContactEntity> = ContactEntity.fetchRequest()
        if let entities = try? context.fetch(fetchRequest) {
            contacts = entities.compactMap { entity in
                Contact(
                    id: entity.id ?? UUID(),
                    name: entity.name ?? "",
                    surname: entity.surname,
                    nickname: entity.nickname,
                    relationType: entity.relationType,
                    gender: entity.gender,
                    birthday: {
                        let day = Int(entity.birthdayDay)
                        let month = Int(entity.birthdayMonth)
                        let year = Int(entity.birthdayYear)
                        if day != 0 && month != 0 {
                            return Birthday(
                                day: day,
                                month: month,
                                year: year != 0 ? year : nil
                            )
                        }
                        return nil
                    }(),
                    notificationSettings: NotificationSettings(
                        enabled: entity.notificationEnabled,
                        daysBefore: [Int(entity.notificationDaysBefore)],
                        hour: Int(entity.notificationHour),
                        minute: Int(entity.notificationMinute)
                    ),
                    imageData: entity.imageData,
                    emoji: entity.emoji,
                    occupation: entity.occupation,
                    hobbies: entity.hobbies,
                    leisure: entity.leisure,
                    additionalInfo: entity.additionalInfo,
                    phoneNumber: entity.phoneNumber,
                    congratsHistory: [],
                    cardHistory: []
                )
            }
            print("Загружено контактов из CoreData: \(contacts.count)")
            contacts.forEach { print("Contact: \($0.name), id: \($0.id)") }
        } else {
            print("Не удалось загрузить контакты из CoreData")
        }
    }
    
    private func saveContactToCoreData(_ contact: Contact) {
        let fetchRequest: NSFetchRequest<ContactEntity> = ContactEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", contact.id as CVarArg)
        let entity: ContactEntity
        if let result = try? context.fetch(fetchRequest), let existing = result.first {
            entity = existing
        } else {
            entity = ContactEntity(context: context)
            entity.id = contact.id
        }
        entity.name = contact.name
        entity.surname = contact.surname
        entity.nickname = contact.nickname
        entity.relationType = contact.relationType
        entity.gender = contact.gender
        if let day = contact.birthday?.day {
            entity.birthdayDay = Int16(day)
        }
        if let month = contact.birthday?.month {
            entity.birthdayMonth = Int16(month)
        }
        if let year = contact.birthday?.year {
            entity.birthdayYear = Int16(year)
        }
        entity.emoji = contact.emoji
        entity.imageData = contact.imageData
        entity.occupation = contact.occupation
        entity.hobbies = contact.hobbies
        entity.leisure = contact.leisure
        entity.additionalInfo = contact.additionalInfo
        entity.phoneNumber = contact.phoneNumber
        // notificationSettings
        entity.notificationEnabled = contact.notificationSettings.enabled
        entity.notificationDaysBefore = Int16(contact.notificationSettings.daysBefore.first ?? 1)
        entity.notificationHour = Int16(contact.notificationSettings.hour)
        entity.notificationMinute = Int16(contact.notificationSettings.minute)
        try? context.save()
        print("Контакт сохранён в CoreData: \(contact.name), id: \(contact.id)")
    }
    
    private func deleteContactFromCoreData(_ id: UUID) {
        let fetchRequest: NSFetchRequest<ContactEntity> = ContactEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let result = try? context.fetch(fetchRequest), let entity = result.first {
            context.delete(entity)
            try? context.save()
            print("Контакт удалён из CoreData: \(id)")
        }
    }

    func daysUntilNextBirthday(from birthday: Birthday) -> Int {
        let calendar = Calendar.current
        let now = Date()
        var components = DateComponents()
        components.day = birthday.day
        components.month = birthday.month

        // Сегодняшний год
        let thisYear = calendar.component(.year, from: now)
        components.year = thisYear

        guard let nextBirthdayThisYear = calendar.date(from: components) else { return 366 }

        var nextBirthday = nextBirthdayThisYear

        // Если день рождения уже был в этом году — следующий в следующем году
        if nextBirthdayThisYear < calendar.startOfDay(for: now) {
            components.year = thisYear + 1
            nextBirthday = calendar.date(from: components) ?? nextBirthdayThisYear
        }

        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: nextBirthday).day ?? 366
        return days
    }

    func importAllContacts() {
        ContactImportService.importAllContacts { [weak self] importedContacts in
            DispatchQueue.main.async {
                self?.contacts.append(contentsOf: importedContacts)
                importedContacts.forEach { contact in
                    NotificationManager.shared.scheduleBirthdayNotifications(for: contact, settings: contact.notificationSettings)
                }
                importedContacts.forEach { contact in
                    self?.saveContactToCoreData(contact)
                }
            }
        }
    }
    
    func saveNotificationSettings() {
        globalNotificationSettings.save()
    }

    func loadNotificationSettings() {
        globalNotificationSettings = NotificationSettings.load()
    }
}
