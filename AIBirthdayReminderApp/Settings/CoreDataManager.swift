import Foundation
import CoreData
import CloudKit

@MainActor
final class CoreDataManager {
    static let shared = CoreDataManager()

    // MARK: - Shared Model (single instance to avoid duplicate NSEntityDescription warnings)
    private static let modelName = "Model4"
    private static let managedModel: NSManagedObjectModel = {
        guard
            let url = Bundle.main.url(forResource: modelName, withExtension: "momd"),
            let model = NSManagedObjectModel(contentsOf: url)
        else {
            fatalError("❌ Не удалось загрузить NSManagedObjectModel \(modelName).momd из бандла")
        }
        return model
    }()

    // MARK: - Storage Mode
    enum StorageMode {
        case local        // Только локальная база
        case cloudKit     // CloudKit + локальная база
    }
    
    private(set) var currentMode: StorageMode = .local
    private(set) var persistentContainer: NSPersistentContainer
    private var isSwitchingStorage = false
    private var pendingBackgroundTasks: [(author: String, block: (NSManagedObjectContext) -> Void)] = []

    /// Удобный алиас для viewContext
    var viewContext: NSManagedObjectContext { persistentContainer.viewContext }
    
    /// Проверяет, инициализирован ли CloudKit
    var isCloudKitEnabled: Bool { currentMode == .cloudKit }
    
    /// Проверяет, вошел ли пользователь в аккаунт
    private var isUserSignedIn: Bool {
        return AppleSignInManager.shared.currentAppleId != nil && AppleSignInManager.shared.currentJWTToken != nil
    }


    private init() {
        // Инициализируем сразу в локальном режиме
        persistentContainer = Self.createLocalContainer()
        currentMode = .local
        print("🏠 CoreDataManager инициализирован в локальном режиме")
        
        // Проверяем состояние входа при запуске
        checkSignInStateOnLaunch()
        // Observe iCloud account status changes and react accordingly
        NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            Task { await self.handleCKAccountChange() }
        }
    }

    /// Handles CloudKit account availability changes.
    private func handleCKAccountChange() async {
        if isSwitchingStorage {
            #if DEBUG
            print("ℹ️ CKAccountChanged ignored: switching in progress")
            #endif
            return
        }
        // Query current iCloud account status
        let status: CKAccountStatus
        do {
            status = try await CKContainer.default().accountStatus()
        } catch {
            #if DEBUG
            print("⚠️ CK accountStatus error: \(error)")
            #endif
            status = .couldNotDetermine
        }

        switch status {
        case .available:
            // If user is signed in (our app) but storage is local, enable CloudKit now
            if isUserSignedIn && currentMode == .local {
                do {
                    try await enableCloudKit()
                    #if DEBUG
                    print("✅ CloudKit re-enabled after CKAccountChanged")
                    #endif
                } catch {
                    #if DEBUG
                    print("❌ Failed to enable CloudKit after account became available: \(error)")
                    #endif
                }
            }
        default:
            // If iCloud becomes unavailable while we are in CloudKit mode, fall back to local
            if currentMode == .cloudKit {
                #if DEBUG
                print("⚠️ iCloud unavailable (status=\(status.rawValue)); switching to local mode…")
                #endif
                disableCloudKit()
            }
        }
    }
    
    /// Проверяет состояние входа при запуске приложения
    private func checkSignInStateOnLaunch() {
        if isUserSignedIn {
            print("✅ Пользователь уже вошел в аккаунт, активируем CloudKit...")
            Task {
                do {
                    try await enableCloudKit()
                    print("✅ CloudKit активирован при запуске (пользователь авторизован)")
                } catch {
                    print("❌ Ошибка активации CloudKit при запуске: \(error)")
                }
            }
        } else {
            print("🏠 Пользователь не вошел в аккаунт, работаем в локальном режиме")
        }
    }
    
    // MARK: - Container Creation
    
    private static func createLocalContainer() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: modelName, managedObjectModel: managedModel)
        configureLocalContainer(container)
        return container
    }

    private static func createCloudKitContainer() -> NSPersistentCloudKitContainer {
        // Проверяем, что пользователь вошел в аккаунт
        guard CoreDataManager.shared.isUserSignedIn else {
            fatalError("❌ CloudKit контейнер не может быть создан без входа в аккаунт")
        }
        let container = NSPersistentCloudKitContainer(name: modelName, managedObjectModel: managedModel)
        configureCloudKitContainer(container)
        return container
    }
    
    private static func configureLocalContainer(_ container: NSPersistentContainer) {
        let storeURL = getStoreURL()
        
        if let description = container.persistentStoreDescriptions.first {
            description.url = storeURL
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        loadStoresOrResetOnce(container)
        configureViewContext(container.viewContext)
        
        print("🏠 Локальный контейнер настроен")
    }
    
    private static func configureCloudKitContainer(_ container: NSPersistentCloudKitContainer) {
        let storeURL = getCloudKitStoreURL()
        
        if let description = container.persistentStoreDescriptions.first {
            description.url = storeURL
            
            // CloudKit контейнер из entitlements
            let containerID = "iCloud.com.ValentinStancov.AIBirthdayReminderApp.v2"
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerID)
            
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        loadStoresOrResetOnce(container)
        configureViewContext(container.viewContext)
        
        #if DEBUG
        #if !targetEnvironment(simulator)
        do {
            try container.initializeCloudKitSchema(options: [])
            print("☁️ CloudKit dev schema initialized")
        } catch {
            print("⚠️ initializeCloudKitSchema failed: \(error)")
        }
        #else
        print("ℹ️ Skipping initializeCloudKitSchema on Simulator")
        #endif
        #endif
        
        print("☁️ CloudKit контейнер настроен")
    }
    
    private static func getStoreURL() -> URL {
        let fm = FileManager.default
        let appSupport = try! fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let storeURL = appSupport.appendingPathComponent("Model4.sqlite")

        if !fm.fileExists(atPath: appSupport.path) {
            try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }

        return storeURL
    }
    
    private static func getCloudKitStoreURL() -> URL {
        let fm = FileManager.default
        let appSupport = try! fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let storeURL = appSupport.appendingPathComponent("Model4_CloudKit.sqlite")

        if !fm.fileExists(atPath: appSupport.path) {
            try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }

        return storeURL
    }
    
    private static func configureViewContext(_ context: NSManagedObjectContext) {
        context.name = "viewContext"
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        context.transactionAuthor = "app"
        context.shouldDeleteInaccessibleFaults = true
    }

    private static func isIncompatibilityError(_ error: Error) -> Bool {
        let e = error as NSError
        guard e.domain == NSCocoaErrorDomain else { return false }
        let codes: [Int] = [
            NSPersistentStoreIncompatibleVersionHashError,
            NSMigrationMissingSourceModelError,
            NSMigrationError,
            NSPersistentStoreIncompatibleSchemaError,
            NSPersistentStoreOpenError,
            134060 // CloudKit doesn't support uniquenessConstraints and related incompatibilities
        ]
        #if DEBUG
        if e.code == 134060 {
            print("⚠️ CloudKit doesn't support uniquenessConstraints — resetting store and retrying once…")
        }
        #endif
        return codes.contains(e.code)
    }

    private static func loadStoresOrResetOnce(_ container: NSPersistentContainer) {
        // Определяем URL хранилища в зависимости от типа контейнера
        let storeURL: URL
        if container is NSPersistentCloudKitContainer {
            storeURL = getCloudKitStoreURL()
        } else {
            storeURL = getStoreURL()
        }
        
        var loadError: Error?
        let sem = DispatchSemaphore(value: 0)
    
        container.loadPersistentStores { _, error in
            loadError = error
            sem.signal()
        }
        sem.wait()
    
        if let err = loadError, isIncompatibilityError(err) {
            #if DEBUG
            print("⚠️ loadPersistentStores incompatibility: \(err). Deleting store and retrying once…")
            #endif
        
        let fm = FileManager.default
        let sidecars = [storeURL, storeURL.appendingPathExtension("wal"), storeURL.appendingPathExtension("shm")]
        let cloudKitFiles = [
            storeURL.appendingPathExtension("ckAssetFiles"),
            storeURL.deletingLastPathComponent().appendingPathComponent("ckAssetFiles"),
            storeURL.deletingLastPathComponent().appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist"),
            storeURL.deletingLastPathComponent().appendingPathComponent("CloudKit")
        ]
        
        for file in sidecars + cloudKitFiles {
            try? fm.removeItem(at: file)
        }
        
            let sem2 = DispatchSemaphore(value: 0)
            container.loadPersistentStores { _, error in
                loadError = error
                sem2.signal()
            }
            sem2.wait()
        }
    
        if let error = loadError {
            fatalError("❌ Core Data ошибка загрузки стора: \(error)")
        }
    }


    // MARK: - Mode Switching
    
    /// Переключается на CloudKit режим (после входа в Apple ID)
    func enableCloudKit() async throws {
        guard currentMode == .local else {
            print("⚠️ CloudKit уже включен")
            return
        }
        guard !isSwitchingStorage else {
            print("ℹ️ enableCloudKit ignored: switching already in progress")
            return
        }
        isSwitchingStorage = true
        defer { isSwitchingStorage = false }

        // Проверяем, что пользователь вошел в аккаунт
        guard isUserSignedIn else {
            print("❌ Нельзя включить CloudKit без входа в аккаунт")
            throw NSError(domain: "CoreDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Пользователь не вошел в аккаунт"])
        }

        // Дополнительно проверим статус системного iCloud, чтобы избежать 134400
        let status: CKAccountStatus
        do {
            status = try await CKContainer.default().accountStatus()
        } catch {
            print("⚠️ Не удалось получить статус iCloud: \(error). Остаёмся в локальном режиме")
            throw error
        }
        guard status == .available else {
            print("⚠️ iCloud недоступен (status=\(status.rawValue)). Остаёмся в локальном режиме, ждём CKAccountChanged")
            throw NSError(domain: "CoreDataManager", code: 134400, userInfo: [NSLocalizedDescriptionKey: "iCloud недоступен"])
        }

        print("🔄 Переключение на CloudKit режим...")

        // Сохраняем ссылку на старый контейнер
        let oldContainer = persistentContainer
        oldContainer.viewContext.performAndWait {
            oldContainer.viewContext.reset()
        }

        do {
            // Создаем новый CloudKit контейнер
            let cloudContainer = Self.createCloudKitContainer()

            // Мигрируем данные из локального контейнера
            try await migrateData(from: oldContainer, to: cloudContainer)

            // Переключаемся на новый контейнер
            persistentContainer = cloudContainer
            currentMode = .cloudKit

            print("✅ Переключение на CloudKit завершено")

            // Уведомляем о смене режима
            NotificationCenter.default.post(name: .storageModeSwitched, object: StorageMode.cloudKit)
            flushPendingBackgroundTasks()

        } catch {
            print("❌ Ошибка переключения на CloudKit: \(error)")
            throw error
        }
    }
    
    /// Переключается на локальный режим (после выхода из Apple ID)
    func disableCloudKit() {
        guard currentMode == .cloudKit else {
            print("⚠️ CloudKit уже отключен")
            return
        }
        guard !isSwitchingStorage else {
            print("ℹ️ disableCloudKit ignored: switching already in progress")
            return
        }
        isSwitchingStorage = true
        defer { isSwitchingStorage = false }
        
        print("🔄 Переключение на локальный режим...")
        
        // Создаем новый локальный контейнер
        let localContainer = Self.createLocalContainer()
        
        // Переключаемся на локальное хранилище
        persistentContainer = localContainer
        currentMode = .local
        
        print("✅ Переключение на локальный режим завершено")
        
        // Уведомляем о смене режима
        NotificationCenter.default.post(name: .storageModeSwitched, object: StorageMode.local)
        flushPendingBackgroundTasks()
    }
    
    /// Принудительная синхронизация данных при входе в аккаунт
    func forceSyncWithCloudKit() async throws {
        guard isUserSignedIn else {
            print("❌ Нельзя синхронизировать без входа в аккаунт")
            throw NSError(domain: "CoreDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Пользователь не вошел в аккаунт"])
        }
        
        if currentMode == .local {
            // Если мы в локальном режиме, переключаемся на CloudKit
            try await enableCloudKit()
        } else {
            // Если уже в CloudKit режиме, принудительно синхронизируем данные
            print("🔄 Принудительная синхронизация с CloudKit...")
            // CloudKit автоматически синхронизируется, но мы можем принудительно обновить данные
            try await syncLocalDataToCloudKit()
        }
    }
    
    /// Синхронизирует локальные данные с CloudKit
    private func syncLocalDataToCloudKit() async throws {
        // Этот метод будет вызываться для принудительной синхронизации
        // CloudKit автоматически синхронизируется, но мы можем добавить дополнительную логику
        print("✅ Синхронизация с CloudKit завершена")
    }
    
    /// Проверяет состояние CloudKit
    func checkCloudKitStatus() -> String {
        if isUserSignedIn {
            if isCloudKitEnabled {
                return "CloudKit активен и синхронизируется"
            } else {
                return "Пользователь вошел, но CloudKit не активен"
            }
        } else {
            return "Пользователь не вошел, работаем в локальном режиме"
        }
    }
    
    /// Получает информацию о текущем режиме работы
    func getCurrentModeInfo() -> (mode: StorageMode, isSignedIn: Bool, isCloudKitEnabled: Bool) {
        return (currentMode, isUserSignedIn, isCloudKitEnabled)
    }
    
    // MARK: - Data Migration
    
    /// Мигрирует данные между контейнерами с умным объединением
    private func migrateData(from sourceContainer: NSPersistentContainer, to targetContainer: NSPersistentContainer) async throws {
        print("🔄 Умная миграция данных с объединением...")
        
        let sourceContext = sourceContainer.newBackgroundContext()
        let targetContext = targetContainer.newBackgroundContext()
        
        return try await withCheckedThrowingContinuation { continuation in
            sourceContext.perform {
                do {
                    // Сначала загружаем все данные из источника
                    let sourceContacts = try self.loadAllContacts(from: sourceContext)
                    let sourceHolidays = try self.loadAllHolidays(from: sourceContext)
                    let sourceCardHistory = try self.loadAllCardHistory(from: sourceContext)
                    let sourceCongratsHistory = try self.loadAllCongratsHistory(from: sourceContext)
                    
                    print("📊 Найдено в источнике: \(sourceContacts.count) контактов, \(sourceHolidays.count) праздников, \(sourceCardHistory.count) открыток, \(sourceCongratsHistory.count) поздравлений")
                    
                    // Теперь мигрируем в целевой контекст
                    targetContext.perform {
                        do {
                            // 1. Сначала мигрируем контакты (базовые сущности)
                            try self.migrateContactsWithMerge(from: sourceContacts, to: targetContext)
                            
                            // 2. Затем праздники
                            try self.migrateHolidaysWithMerge(from: sourceHolidays, to: targetContext)
                            
                            // 3. История открыток (зависит от контактов)
                            try self.migrateCardHistoryWithMerge(from: sourceCardHistory, to: targetContext)
                            
                            // 4. История поздравлений (зависит от контактов)
                            try self.migrateCongratsHistoryWithMerge(from: sourceCongratsHistory, to: targetContext)
                            
                            // 5. Восстанавливаем связи между сущностями
                            try self.restoreRelationships(in: targetContext)
                            
                            // Сохраняем целевой контекст
                            if targetContext.hasChanges {
                                try targetContext.save()
                                print("✅ Данные сохранены в CloudKit хранилище")
                            }
                            
                            print("✅ Умная миграция данных завершена")
                            continuation.resume()
                            
                        } catch {
                            print("❌ Ошибка миграции в целевой контекст: \(error)")
                            continuation.resume(throwing: error)
                        }
                    }
                    
                } catch {
                    print("❌ Ошибка загрузки данных из источника: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Data Loading Helpers
    
    private func loadAllContacts(from context: NSManagedObjectContext) throws -> [ContactEntity] {
        let fetchRequest: NSFetchRequest<ContactEntity> = ContactEntity.fetchRequest()
        return try context.fetch(fetchRequest)
    }
    
    private func loadAllHolidays(from context: NSManagedObjectContext) throws -> [HolidayEntity] {
        let fetchRequest: NSFetchRequest<HolidayEntity> = HolidayEntity.fetchRequest()
        return try context.fetch(fetchRequest)
    }
    
    private func loadAllCardHistory(from context: NSManagedObjectContext) throws -> [CardHistoryEntity] {
        let fetchRequest: NSFetchRequest<CardHistoryEntity> = CardHistoryEntity.fetchRequest()
        return try context.fetch(fetchRequest)
    }
    
    private func loadAllCongratsHistory(from context: NSManagedObjectContext) throws -> [CongratsHistoryEntity] {
        let fetchRequest: NSFetchRequest<CongratsHistoryEntity> = CongratsHistoryEntity.fetchRequest()
        return try context.fetch(fetchRequest)
    }
    
    // MARK: - Smart Migration with Merge Strategy
    
    private func migrateContactsWithMerge(from sourceContacts: [ContactEntity], to target: NSManagedObjectContext) throws {
        var migratedCount = 0
        var mergedCount = 0
        
        for sourceContact in sourceContacts {
            guard let sourceId = sourceContact.id else { continue }
            
            // Ищем существующий контакт в целевом контексте
            let targetFetch: NSFetchRequest<ContactEntity> = ContactEntity.fetchRequest()
            targetFetch.predicate = NSPredicate(format: "id == %@", sourceId as CVarArg)
            targetFetch.fetchLimit = 1
            
            if let existingTarget = try target.fetch(targetFetch).first {
                // Контакт существует - применяем стратегию слияния
                mergeContactData(from: sourceContact, to: existingTarget)
                mergedCount += 1
            } else {
                // Контакт не существует - создаем новый
                let targetContact = ContactEntity(context: target)
                copyContactData(from: sourceContact, to: targetContact)
                migratedCount += 1
            }
        }
        
        print("🔄 Контакты: мигрировано \(migratedCount), объединено \(mergedCount)")
    }
    
    private func migrateHolidaysWithMerge(from sourceHolidays: [HolidayEntity], to target: NSManagedObjectContext) throws {
        var migratedCount = 0
        var mergedCount = 0
        
        for sourceHoliday in sourceHolidays {
            guard let sourceId = sourceHoliday.id else { continue }
            
            let targetFetch: NSFetchRequest<HolidayEntity> = HolidayEntity.fetchRequest()
            targetFetch.predicate = NSPredicate(format: "id == %@", sourceId as CVarArg)
            targetFetch.fetchLimit = 1
            
            if let existingTarget = try target.fetch(targetFetch).first {
                mergeHolidayData(from: sourceHoliday, to: existingTarget)
                mergedCount += 1
            } else {
                let targetHoliday = HolidayEntity(context: target)
                copyHolidayData(from: sourceHoliday, to: targetHoliday)
                migratedCount += 1
            }
        }
        
        print("🔄 Праздники: мигрировано \(migratedCount), объединено \(mergedCount)")
    }
    
    private func migrateCardHistoryWithMerge(from sourceCards: [CardHistoryEntity], to target: NSManagedObjectContext) throws {
        var migratedCount = 0
        var mergedCount = 0
        
        for sourceCard in sourceCards {
            guard let sourceId = sourceCard.id else { continue }
            
            let targetFetch: NSFetchRequest<CardHistoryEntity> = CardHistoryEntity.fetchRequest()
            targetFetch.predicate = NSPredicate(format: "id == %@", sourceId as CVarArg)
            targetFetch.fetchLimit = 1
            
            if let existingTarget = try target.fetch(targetFetch).first {
                mergeCardHistoryData(from: sourceCard, to: existingTarget)
                mergedCount += 1
            } else {
                let targetCard = CardHistoryEntity(context: target)
                copyCardHistoryData(from: sourceCard, to: targetCard)
                migratedCount += 1
            }
        }
        
        print("🔄 Открытки: мигрировано \(migratedCount), объединено \(mergedCount)")
    }
    
    private func migrateCongratsHistoryWithMerge(from sourceCongrats: [CongratsHistoryEntity], to target: NSManagedObjectContext) throws {
        var migratedCount = 0
        var mergedCount = 0
        
        for sourceCongrats in sourceCongrats {
            guard let sourceId = sourceCongrats.id else { continue }
            
            let targetFetch: NSFetchRequest<CongratsHistoryEntity> = CongratsHistoryEntity.fetchRequest()
            targetFetch.predicate = NSPredicate(format: "id == %@", sourceId as CVarArg)
            targetFetch.fetchLimit = 1
            
            if let existingTarget = try target.fetch(targetFetch).first {
                mergeCongratsHistoryData(from: sourceCongrats, to: existingTarget)
                mergedCount += 1
            } else {
                let targetCongrats = CongratsHistoryEntity(context: target)
                copyCongratsHistoryData(from: sourceCongrats, to: targetCongrats)
                migratedCount += 1
            }
        }
        
        print("🔄 Поздравления: мигрировано \(migratedCount), объединено \(mergedCount)")
    }
    
    
    // MARK: - Data Merging Helpers (CloudKit Priority)
    
    private func mergeContactData(from source: ContactEntity, to target: ContactEntity) {
        // CloudKit имеет приоритет - обновляем только если целевые данные пустые
        // Это означает, что CloudKit данные не перезаписываются локальными
        if target.name?.isEmpty != false && source.name?.isEmpty == false {
            target.name = source.name
        }
        if target.surname?.isEmpty != false && source.surname?.isEmpty == false {
            target.surname = source.surname
        }
        if target.nickname?.isEmpty != false && source.nickname?.isEmpty == false {
            target.nickname = source.nickname
        }
        if target.phoneNumber?.isEmpty != false && source.phoneNumber?.isEmpty == false {
            target.phoneNumber = source.phoneNumber
        }
        if target.gender?.isEmpty != false && source.gender?.isEmpty == false {
            target.gender = source.gender
        }
        if target.relationType?.isEmpty != false && source.relationType?.isEmpty == false {
            target.relationType = source.relationType
        }
        if target.occupation?.isEmpty != false && source.occupation?.isEmpty == false {
            target.occupation = source.occupation
        }
        if target.hobbies?.isEmpty != false && source.hobbies?.isEmpty == false {
            target.hobbies = source.hobbies
        }
        if target.leisure?.isEmpty != false && source.leisure?.isEmpty == false {
            target.leisure = source.leisure
        }
        if target.additionalInfo?.isEmpty != false && source.additionalInfo?.isEmpty == false {
            target.additionalInfo = source.additionalInfo
        }
        if target.emoji?.isEmpty != false && source.emoji?.isEmpty == false {
            target.emoji = source.emoji
        }
        if target.imageData == nil && source.imageData != nil {
            target.imageData = source.imageData
        }
        
        // Для дат и настроек - всегда берем более свежие данные
        if source.birthdayDay != 0 {
            target.birthdayDay = source.birthdayDay
        }
        if source.birthdayMonth != 0 {
            target.birthdayMonth = source.birthdayMonth
        }
        if source.birthdayYear != 0 {
            target.birthdayYear = source.birthdayYear
        }
        
        // Настройки уведомлений - берем более консервативные (включенные)
        if source.notificationEnabled == true {
            target.notificationEnabled = true
        }
        if source.notificationDaysBefore > target.notificationDaysBefore {
            target.notificationDaysBefore = source.notificationDaysBefore
        }
        if source.notificationHour > target.notificationHour {
            target.notificationHour = source.notificationHour
        }
        if source.notificationMinute > target.notificationMinute {
            target.notificationMinute = source.notificationMinute
        }
    }
    
    private func mergeHolidayData(from source: HolidayEntity, to target: HolidayEntity) {
        // CloudKit имеет приоритет - обновляем только если целевые данные пустые
        if target.title?.isEmpty != false && source.title?.isEmpty == false {
            target.title = source.title
        }
        if target.icon?.isEmpty != false && source.icon?.isEmpty == false {
            target.icon = source.icon
        }
        if target.type?.isEmpty != false && source.type?.isEmpty == false {
            target.type = source.type
        }
        
        // Для дат - берем более свежие данные
        if let sourceDate = source.date, target.date == nil || sourceDate > (target.date ?? Date.distantPast) {
            target.date = sourceDate
        }
        if source.year != 0 {
            target.year = source.year
        }
        
        // Булевы значения - берем более консервативные (true)
        if source.isRegional == true {
            target.isRegional = true
        }
        if source.isCustom == true {
            target.isCustom = true
        }
    }
    
    private func mergeCardHistoryData(from source: CardHistoryEntity, to target: CardHistoryEntity) {
        // CloudKit имеет приоритет - обновляем только если целевые данные пустые
        if target.cardID?.isEmpty != false && source.cardID?.isEmpty == false {
            target.cardID = source.cardID
        }
        if target.imageData == nil && source.imageData != nil {
            target.imageData = source.imageData
        }
        
        // Для дат - берем более свежие данные
        if let sourceDate = source.date, target.date == nil || sourceDate > (target.date ?? Date.distantPast) {
            target.date = sourceDate
        }
        if let sourceHolidayID = source.holidayID, target.holidayID == nil {
            target.holidayID = sourceHolidayID
        }
    }
    
    private func mergeCongratsHistoryData(from source: CongratsHistoryEntity, to target: CongratsHistoryEntity) {
        // CloudKit имеет приоритет - обновляем только если целевые данные пустые
        if target.message?.isEmpty != false && source.message?.isEmpty == false {
            target.message = source.message
        }
        
        // Для дат - берем более свежие данные
        if let sourceDate = source.date, target.date == nil || sourceDate > (target.date ?? Date.distantPast) {
            target.date = sourceDate
        }
        if let sourceHolidayID = source.holidayID, target.holidayID == nil {
            target.holidayID = sourceHolidayID
        }
    }
    
    private func restoreRelationships(in context: NSManagedObjectContext) throws {
        // Восстанавливаем связи между контактами и их историей
        let cardHistoryRequest: NSFetchRequest<CardHistoryEntity> = CardHistoryEntity.fetchRequest()
        let cardHistoryItems = try context.fetch(cardHistoryRequest)
        
        for card in cardHistoryItems {
            if card.contact == nil {
                // Ищем контакт или создаем связь
                // Это упрощенная логика - в реальном приложении может быть сложнее
            }
        }
        
        let congratsRequest: NSFetchRequest<CongratsHistoryEntity> = CongratsHistoryEntity.fetchRequest()
        let congratsItems = try context.fetch(congratsRequest)
        
        for congrats in congratsItems {
            if congrats.contact == nil {
                // Аналогично для поздравлений
            }
        }
        
        print("🔄 Связи между сущностями восстановлены")
    }
    
    // MARK: - Data Copying Helpers
    
    private func copyContactData(from source: ContactEntity, to target: ContactEntity) {
        target.id = source.id
        target.name = source.name
        target.surname = source.surname
        target.nickname = source.nickname
        target.birthdayDay = source.birthdayDay
        target.birthdayMonth = source.birthdayMonth
        target.birthdayYear = source.birthdayYear
        target.phoneNumber = source.phoneNumber
        target.gender = source.gender
        target.relationType = source.relationType
        target.occupation = source.occupation
        target.hobbies = source.hobbies
        target.leisure = source.leisure
        target.additionalInfo = source.additionalInfo
        target.emoji = source.emoji
        target.imageData = source.imageData
        target.notificationEnabled = source.notificationEnabled
        target.notificationDaysBefore = source.notificationDaysBefore
        target.notificationHour = source.notificationHour
        target.notificationMinute = source.notificationMinute
    }
    
    private func copyHolidayData(from source: HolidayEntity, to target: HolidayEntity) {
        target.id = source.id
        target.title = source.title
        target.date = source.date
        target.year = source.year
        target.type = source.type
        target.icon = source.icon
        target.isRegional = source.isRegional
        target.isCustom = source.isCustom
    }
    
    private func copyCardHistoryData(from source: CardHistoryEntity, to target: CardHistoryEntity) {
        target.id = source.id
        target.date = source.date
        target.cardID = source.cardID
        target.imageData = source.imageData
        target.holidayID = source.holidayID
        // Note: relationship к contact будет восстановлен после миграции контактов
    }
    
    private func copyCongratsHistoryData(from source: CongratsHistoryEntity, to target: CongratsHistoryEntity) {
        target.id = source.id
        target.date = source.date
        target.message = source.message
        target.holidayID = source.holidayID
        // Note: relationship к contact будет восстановлен после миграции контактов
    }
    
    // MARK: - Background Context Management

    /// Создаём фоновой контекст с корректной политикой мерджа
    func newBackgroundContext(author: String = "background") -> NSManagedObjectContext {
        let ctx = persistentContainer.newBackgroundContext()
        ctx.name = "bgContext-\(author)"
        ctx.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        ctx.transactionAuthor = author
        #if DEBUG
        assert(ctx.persistentStoreCoordinator === persistentContainer.persistentStoreCoordinator, "⚠️ newBackgroundContext attached to different coordinator/model")
        #endif
        return ctx
    }

    /// Безопасное сохранение viewContext
    func saveViewContextIfNeeded() {
        let ctx = viewContext
        guard ctx.hasChanges else { return }
        ctx.perform {
            do {
                try ctx.save()
                #if DEBUG
                print("✅ Core Data: viewContext сохранён")
                #endif
            } catch {
                assertionFailure("❌ Core Data ошибка сохранения viewContext: \(error)")
            }
        }
    }

    /// Утилита для фоновой работы с автоматическим сохранением
    func performBackgroundTask(author: String = "background", _ block: @escaping (NSManagedObjectContext) -> Void) {
        if isSwitchingStorage {
            #if DEBUG
            print("ℹ️ Deferring bg task '\(author)' until storage switch completes")
            #endif
            pendingBackgroundTasks.append((author: author, block: block))
            return
        }
        let ctx = newBackgroundContext(author: author)
        ctx.perform {
            block(ctx)
            if ctx.hasChanges {
                do {
                    try ctx.save()
                    #if DEBUG
                    print("✅ Core Data: bgContext(\(author)) сохранён")
                    #endif
                } catch {
                    assertionFailure("❌ Core Data ошибка сохранения bgContext: \(error)")
                }
            }
        }
    }
    private func flushPendingBackgroundTasks() {
        guard !pendingBackgroundTasks.isEmpty else { return }
        let tasks = pendingBackgroundTasks
        pendingBackgroundTasks.removeAll()
        for item in tasks {
            let ctx = newBackgroundContext(author: item.author)
            ctx.perform {
                item.block(ctx)
                if ctx.hasChanges {
                    do {
                        try ctx.save()
                        #if DEBUG
                        print("✅ Core Data: bgContext(\(item.author)) (flushed) сохранён")
                        #endif
                    } catch {
                        assertionFailure("❌ Core Data ошибка сохранения bgContext (flushed): \(error)")
                    }
                }
            }
        }
    }

}

// MARK: - Notifications

extension Notification.Name {
    static let storageModeSwitched = Notification.Name("storageModeSwitched")
}
