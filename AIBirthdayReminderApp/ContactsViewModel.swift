import Foundation

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
    
    private let storageKey = "contacts_data_v1"
    private let notificationSettingsKey = "globalNotificationSettings"
    
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
        load()
        loadNotificationSettings()
        if let stored = UserDefaults.standard.string(forKey: "colorScheme"),
           let scheme = AppColorScheme(rawValue: stored) {
            colorScheme = scheme
        }
    }
    
    func addContact(_ contact: Contact) {
        contacts.append(contact)
        save()
        NotificationManager.shared.scheduleBirthdayNotifications(for: contact, settings: contact.notificationSettings)
    }
    
    func removeContact(at offsets: IndexSet) {
        for index in offsets {
            let contact = contacts[index]
            NotificationManager.shared.removeBirthdayNotifications(for: contact)
        }
        contacts.remove(atOffsets: offsets)
        save()
    }
    
    func removeContact(_ contact: Contact) {
        removeContactById(contact.id)
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(contacts) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Contact].self, from: data) {
            contacts = decoded
        }
    }
    
    func updateContact(_ updated: Contact) {
        if let idx = contacts.firstIndex(where: { $0.id == updated.id }) {
            contacts[idx] = updated
            contacts = contacts
            save()
            NotificationManager.shared.scheduleBirthdayNotifications(for: updated, settings: updated.notificationSettings)
        }
    }
    
    func removeContactById(_ id: UUID) {
        if let idx = contacts.firstIndex(where: { $0.id == id }) {
            contacts.remove(at: idx)
            save()
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
                self?.save()
                importedContacts.forEach { contact in
                    NotificationManager.shared.scheduleBirthdayNotifications(for: contact, settings: contact.notificationSettings)
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
