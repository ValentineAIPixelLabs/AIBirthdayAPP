import Foundation
import CoreData
import UIKit
import SwiftUI
import CoreData

@MainActor
class ContactsViewModel: NSObject, ObservableObject {
    enum AppColorScheme: String, CaseIterable, Identifiable, Codable {
        case system, light, dark
        var id: String { rawValue }
        /// SwiftUI-aware key for use with Text(...), respects \(.locale)
        var labelKey: LocalizedStringKey {
            switch self {
            case .system: return "theme.mode.auto"
            case .light:  return "theme.mode.light"
            case .dark:   return "theme.mode.dark"
            }
        }
        /// Convenience String if you need a plain String
        var label: String {
            switch self {
            case .system: return String(localized: "theme.mode.auto")
            case .light:  return String(localized: "theme.mode.light")
            case .dark:   return String(localized: "theme.mode.dark")
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
    private var frc: NSFetchedResultsController<ContactEntity>? = nil
    private var didSetInitialSnapshot = false
    private var viewContext: NSManagedObjectContext { CoreDataManager.shared.viewContext }
    
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
    
    override init() {
        super.init()
        loadNotificationSettings()
        if let stored = UserDefaults.standard.string(forKey: "colorScheme"),
           let scheme = AppColorScheme(rawValue: stored) {
            colorScheme = scheme
        }
        // Не запускаем FRC в init. Ждем нотификацию, что стор готов (.storageModeSwitched)
        setupStorageModeObserver()
    }
    
    func addContact(_ contact: Contact) {
        contacts.append(contact)
        saveContactToCoreData(contact)
        NotificationManager.shared.scheduleBirthdayNotifications(for: contact, settings: contact.notificationSettings)
        
    }
    
    func removeContact(at offsets: IndexSet) {
        for index in offsets {
            let contact = contacts[index]
            NotificationManager.shared.removeBirthdayNotifications(for: contact)
            deleteContactFromCoreData(contact.id)
            
        }
        contacts.remove(atOffsets: offsets)
    }
    
    func removeContact(_ contact: Contact) {
        removeContactById(contact.id)
        
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
        // Загружаем все контакты
        let fetchRequest: NSFetchRequest<ContactEntity> = ContactEntity.fetchRequest()
        fetchRequest.fetchBatchSize = 50

        do {
            let entities = try viewContext.fetch(fetchRequest)
            contacts = entities.compactMap { entity in
                guard let entityId = entity.id else { return nil }
                return Contact(
                    id: entityId,
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
                            return Birthday(day: day, month: month, year: year != 0 ? year : nil)
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
                    congratsHistory: CongratsHistoryManager.getCongrats(for: entityId),
                    cardHistory: CardHistoryManager.getCards(for: entityId).map {
                        CardHistoryItem(id: $0.id, date: $0.date, cardID: $0.cardID)
                    }
                )
            }
        } catch {
            print("❌ Не удалось загрузить контакты из CoreData: \(error)")
        }
    }
    
    private func saveContactToCoreData(_ contact: Contact) {
        CoreDataManager.shared.performBackgroundTask(author: "saveContact") { ctx in
            let req: NSFetchRequest<ContactEntity> = ContactEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", contact.id as CVarArg)
            req.fetchLimit = 1

            let entity: ContactEntity
            do {
                if let existing = try ctx.fetch(req).first {
                    entity = existing
                } else {
                    entity = ContactEntity(context: ctx)
                    entity.id = contact.id
                }
            } catch {
                assertionFailure("❌ Fetch ContactEntity error: \(error)")
                return
            }

            entity.name = contact.name
            entity.surname = contact.surname
            entity.nickname = contact.nickname
            entity.relationType = contact.relationType
            entity.gender = contact.gender

            if let bday = contact.birthday {
                entity.birthdayDay = Int16(bday.day ?? 0)
                entity.birthdayMonth = Int16(bday.month ?? 0)
                entity.birthdayYear = Int16(bday.year ?? 0)
            } else {
                entity.birthdayDay = 0
                entity.birthdayMonth = 0
                entity.birthdayYear = 0
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
        }
        print("💾 Контакт отправлен на сохранение в CoreData: \(contact.name), id: \(contact.id)")
    }
    
    private func deleteContactFromCoreData(_ id: UUID) {
        CoreDataManager.shared.performBackgroundTask(author: "deleteContact") { ctx in
            let req: NSFetchRequest<ContactEntity> = ContactEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            req.fetchLimit = 1
            
            do {
                if let entity = try ctx.fetch(req).first {
                    print("🗑️ ✅ Контакт найден для удаления: \(id)")
                    ctx.delete(entity)
                } else {
                    print("🗑️ ❌ Контакт НЕ найден для удаления: \(id)")
                }
            } catch {
                assertionFailure("❌ Fetch for delete ContactEntity error: \(error)")
            }
        }
        print("🗑️ Контакт отправлен на удаление из CoreData: \(id)")
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
    
    // MARK: - Storage Mode Observer
    
    private func setupStorageModeObserver() {
        NotificationCenter.default.addObserver(
            forName: .storageModeSwitched,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Пересоздаём FRC на новом viewContext только после готовности стора.
            // Сбрасываем флаг, чтобы не показать пустой список во время переключения.
            Task { @MainActor in
                self?.didSetInitialSnapshot = false
                self?.startObservingContacts()
            }
        }
    }

    // MARK: - NSFetchedResultsController
    private func startObservingContacts() {
        let fetch: NSFetchRequest<ContactEntity> = ContactEntity.fetchRequest()
        fetch.fetchBatchSize = 50
        fetch.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        fetch.relationshipKeyPathsForPrefetching = ["congratsHistory", "cardHistory"]

        let controller = NSFetchedResultsController(fetchRequest: fetch,
                                                    managedObjectContext: viewContext,
                                                    sectionNameKeyPath: nil,
                                                    cacheName: nil)
        controller.delegate = self
        do {
            try controller.performFetch()
        } catch {
            print("❌ FRC performFetch error: \(error)")
        }
        self.frc = controller
        applySnapshotFromFRC()
    }

    private func applySnapshotFromFRC() {
        let objs = frc?.fetchedObjects ?? []
        let mapped: [Contact] = objs.compactMap { e in
            guard let entityId = e.id else { return nil }
            let birthday: Birthday? = {
                let day = Int(e.birthdayDay)
                let month = Int(e.birthdayMonth)
                let year = Int(e.birthdayYear)
                if day != 0 && month != 0 {
                    return Birthday(day: day, month: month, year: year != 0 ? year : nil)
                }
                return nil
            }()
            // Map relations without extra fetches
            let congrats: [CongratsHistoryItem] = (e.congratsHistory as? Set<CongratsHistoryEntity> ?? [])
                .compactMap { ce in
                    guard let id = ce.id, let date = ce.date else { return nil }
                    return CongratsHistoryItem(id: id, date: date, message: ce.message ?? "")
                }
                .sorted { $0.date > $1.date }
            let cards: [CardHistoryItem] = (e.cardHistory as? Set<CardHistoryEntity> ?? [])
                .compactMap { he in
                    guard let id = he.id, let date = he.date else { return nil }
                    return CardHistoryItem(id: id, date: date, cardID: he.cardID ?? "")
                }
                .sorted { $0.date > $1.date }

            return Contact(
                id: entityId,
                name: e.name ?? "",
                surname: e.surname,
                nickname: e.nickname,
                relationType: e.relationType,
                gender: e.gender,
                birthday: birthday,
                notificationSettings: NotificationSettings(
                    enabled: e.notificationEnabled,
                    daysBefore: [Int(e.notificationDaysBefore)],
                    hour: Int(e.notificationHour),
                    minute: Int(e.notificationMinute)
                ),
                imageData: e.imageData,
                emoji: e.emoji,
                occupation: e.occupation,
                hobbies: e.hobbies,
                leisure: e.leisure,
                additionalInfo: e.additionalInfo,
                phoneNumber: e.phoneNumber,
                congratsHistory: congrats,
                cardHistory: cards
            )
        }
        // Избегаем мигания пустым списком при первом получении снапшота
        if !didSetInitialSnapshot && mapped.isEmpty {
            return
        }
        self.contacts = mapped
        if !mapped.isEmpty { didSetInitialSnapshot = true }
    }
}

extension ContactsViewModel: NSFetchedResultsControllerDelegate {
    nonisolated func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Перекладываем работу на главный актор, так как ContactsViewModel помечен @MainActor
        Task { @MainActor in
            self.applySnapshotFromFRC()
        }
    }
}
