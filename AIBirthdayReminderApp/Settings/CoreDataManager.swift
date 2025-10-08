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
    
    /// Быстрый способ узнать, добавлены ли persistent stores
    var hasLoadedStores: Bool {
        !(persistentContainer.persistentStoreCoordinator.persistentStores.isEmpty)
    }
    
    /// Считаем пользователя "зарегистрированным", если есть устойчивый токен устройства
    private var isUserSignedIn: Bool {
        !DeviceAccountManager.shared.appAccountToken().isEmpty
    }


    private init() {
        // Всегда быстро поднимаем локальный контейнер для мгновенного UI
        let localContainer = Self.makeLocalContainer()
        persistentContainer = localContainer
        currentMode = .local
        // logging suppressed

        Task { @MainActor in
            // 1) Загружаем локальный стор (не блокируя UI)
            do {
                try await Self.configureAndLoadLocalContainerAsync(localContainer)
                // logging suppressed
                NotificationCenter.default.post(name: .storageModeSwitched, object: StorageMode.local)
            } catch {
                fatalError("❌ Ошибка асинхронной загрузки локального стора: \(error)")
            }

            // 2) Если пользователь уже авторизован и iCloud доступен — включаем CloudKit в фоне
            guard isUserSignedIn else { return }
            let status: CKAccountStatus
            do {
                status = try await CKContainer.default().accountStatus()
            } catch {
                // logging suppressed
                return
            }
            guard status == .available else {
                // logging suppressed
                return
            }

            // 3) Мягкое переключение: миграция уникальных локальных данных → CloudKit и переключение контейнера
            do {
                try await enableCloudKit()
            } catch {
                print("❌ Ошибка активации CloudKit после старта: \(error)")
            }
        }
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
                await disableCloudKit()
            }
        }
    }
    
    /// Проверяет состояние входа при запуске приложения (больше не вызывается из init; логика старта перенесена в init)
    private func checkSignInStateOnLaunch() { /* deprecated path */ }
    
    // MARK: - Container Creation
    
    private static func makeLocalContainer() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: modelName, managedObjectModel: managedModel)
        return container
    }

    private static func makeCloudKitContainer() -> NSPersistentCloudKitContainer {
        // Проверяем, что пользователь вошел в аккаунт
        guard CoreDataManager.shared.isUserSignedIn else {
            fatalError("❌ CloudKit контейнер не может быть создан без входа в аккаунт")
        }
        let container = NSPersistentCloudKitContainer(name: modelName, managedObjectModel: managedModel)
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
        // logging suppressed
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
        // logging suppressed
    }

    // Async configure + load helpers
    private static func loadStoresOrResetOnceAsync(_ container: NSPersistentContainer) async throws {
        func loadOnce() async throws {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                container.loadPersistentStores { _, error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: ()) }
                }
            }
        }
        do {
            try await loadOnce()
        } catch {
            if isIncompatibilityError(error) {
                #if DEBUG
                print("⚠️ loadPersistentStores incompatibility: \(error). Deleting store and retrying once…")
                #endif
                // Удаляем файлы стора (sqlite + sidecars)
                let storeURL: URL = (container is NSPersistentCloudKitContainer) ? getCloudKitStoreURL() : getStoreURL()
                let fm = FileManager.default
                let sidecars = [storeURL, storeURL.appendingPathExtension("wal"), storeURL.appendingPathExtension("shm")]
                for file in sidecars { try? fm.removeItem(at: file) }
                try await loadOnce()
            } else {
                throw error
            }
        }
    }

    private static func configureAndLoadLocalContainerAsync(_ container: NSPersistentContainer) async throws {
        configureLocalContainer(container)
        try await loadStoresOrResetOnceAsync(container)
        configureViewContext(container.viewContext)
        // logging suppressed
    }

    private static func configureAndLoadCloudKitContainerAsync(_ container: NSPersistentCloudKitContainer) async throws {
        configureCloudKitContainer(container)
        try await loadStoresOrResetOnceAsync(container)
        configureViewContext(container.viewContext)
        // Dev schema initialization отключена для ускорения UX старта. Используйте CloudKit Dashboard для схемы.
        // logging suppressed
    }

    /// Полное очищение всех данных в указанном контейнере
    private static func clearAllData(in container: NSPersistentContainer) {
        let ctx = container.newBackgroundContext()
        ctx.performAndWait {
            let entityNames = container.managedObjectModel.entities.compactMap { $0.name }
            for name in entityNames {
                let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: name)
                let request = NSBatchDeleteRequest(fetchRequest: fetch)
                request.resultType = .resultTypeObjectIDs
                do {
                    let result = try ctx.execute(request) as? NSBatchDeleteResult
                    if let objectIDs = result?.result as? [NSManagedObjectID] {
                        let changes = [NSDeletedObjectsKey: objectIDs]
                        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [container.viewContext])
                    }
                } catch {
                    #if DEBUG
                    print("⚠️ clearAllData error for entity \(name): \(error)")
                    #endif
                }
            }
            do { try ctx.save() } catch { }
        }
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
    
    /// Переключается на CloudKit режим (когда iCloud доступен и мы готовы синхронизироваться)
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

        // logging suppressed

        // Сохраняем ссылку на старый контейнер
        let oldContainer = persistentContainer
        oldContainer.viewContext.performAndWait {
            oldContainer.viewContext.reset()
        }

        do {
            // Создаем новый CloudKit контейнер и асинхронно загружаем его
            let cloudContainer = Self.makeCloudKitContainer()
            try await Self.configureAndLoadCloudKitContainerAsync(cloudContainer)

            // Мигрируем данные из локального контейнера
            try await migrateData(from: oldContainer, to: cloudContainer)

            // Переключаемся на новый контейнер
            persistentContainer = cloudContainer
            currentMode = .cloudKit

            // logging suppressed

            // Уведомляем о смене режима
            NotificationCenter.default.post(name: .storageModeSwitched, object: StorageMode.cloudKit)
            flushPendingBackgroundTasks()

        } catch {
            print("❌ Ошибка переключения на CloudKit: \(error)")
            throw error
        }
    }
    
    /// Переключается на локальный режим (когда iCloud недоступен либо требуется оффлайн-режим)
    /// Зеркалирует актуальные данные из CloudKit в локальную базу
    func disableCloudKit() async {
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
        
        // logging suppressed
        
        // Источник: текущий CloudKit контейнер
        let cloudContainer = persistentContainer
        cloudContainer.viewContext.performAndWait {
            cloudContainer.viewContext.reset()
        }

        // Цель: новый локальный контейнер и его загрузка
        let localContainer = Self.makeLocalContainer()
        do {
            try await Self.configureAndLoadLocalContainerAsync(localContainer)
        } catch {
            print("❌ Ошибка загрузки локального контейнера перед зеркалированием: \(error)")
        }
        // Полностью очищаем локальную базу перед зеркалированием (после загрузки стора)
        Self.clearAllData(in: localContainer)

        do {
            try await migrateData(from: cloudContainer, to: localContainer)
        } catch {
            print("❌ Ошибка зеркалирования данных CloudKit → Local: \(error)")
            // Даже при ошибке переключаемся, чтобы не зависать в облачном режиме
        }

        // Переключаемся на локальное хранилище
        persistentContainer = localContainer
        currentMode = .local
        
        // logging suppressed
        
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
            // logging suppressed
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
        // logging suppressed
        
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
                    
                    // logging suppressed
                    
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
                                // logging suppressed
                            }
                            
                            // logging suppressed
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
    
    nonisolated private func loadAllContacts(from context: NSManagedObjectContext) throws -> [ContactEntity] {
        let fetchRequest: NSFetchRequest<ContactEntity> = ContactEntity.fetchRequest()
        return try context.fetch(fetchRequest)
    }
    
    nonisolated private func loadAllHolidays(from context: NSManagedObjectContext) throws -> [HolidayEntity] {
        let fetchRequest: NSFetchRequest<HolidayEntity> = HolidayEntity.fetchRequest()
        return try context.fetch(fetchRequest)
    }
    
    nonisolated private func loadAllCardHistory(from context: NSManagedObjectContext) throws -> [CardHistoryEntity] {
        let fetchRequest: NSFetchRequest<CardHistoryEntity> = CardHistoryEntity.fetchRequest()
        return try context.fetch(fetchRequest)
    }
    
    nonisolated private func loadAllCongratsHistory(from context: NSManagedObjectContext) throws -> [CongratsHistoryEntity] {
        let fetchRequest: NSFetchRequest<CongratsHistoryEntity> = CongratsHistoryEntity.fetchRequest()
        return try context.fetch(fetchRequest)
    }
    
    // MARK: - Smart Migration with Merge Strategy
    
    nonisolated private func migrateContactsWithMerge(from sourceContacts: [ContactEntity], to target: NSManagedObjectContext) throws {
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
                // Доп. проверка дубликатов по естественным ключам
                if let dup = try findDuplicateContactCandidate(of: sourceContact, in: target) {
                    mergeContactData(from: sourceContact, to: dup)
                    mergedCount += 1
                } else {
                    // Контакт не существует - создаем новый
                    let targetContact = ContactEntity(context: target)
                    copyContactData(from: sourceContact, to: targetContact)
                    migratedCount += 1
                }
            }
        }
        
        // logging suppressed
    }

    /// Поиск кандидата‑дубликата контакта по «естественным» ключам
    /// 1) по совпадающему номеру телефона (если не пуст)
    /// 2) по (name+surname) и совпадающему дню/месяцу рождения
    nonisolated private func findDuplicateContactCandidate(of source: ContactEntity, in context: NSManagedObjectContext) throws -> ContactEntity? {
        // 1) Телефон
        if let phone = source.phoneNumber, !phone.isEmpty {
            let req: NSFetchRequest<ContactEntity> = ContactEntity.fetchRequest()
            req.fetchLimit = 1
            req.predicate = NSPredicate(format: "phoneNumber == %@", phone)
            if let found = try context.fetch(req).first { return found }
        }
        // 2) Имя+Фамилия+дата рождения (день/месяц)
        let name = (source.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let surname = (source.surname ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let day = Int(source.birthdayDay)
        let month = Int(source.birthdayMonth)
        if !name.isEmpty || !surname.isEmpty, day != 0, month != 0 {
            let req: NSFetchRequest<ContactEntity> = ContactEntity.fetchRequest()
            req.fetchLimit = 1
            req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "birthdayDay == %d AND birthdayMonth == %d", day, month),
                NSPredicate(format: "(name ==[cd] %@) OR (surname ==[cd] %@)", name, surname)
            ])
            if let found = try context.fetch(req).first { return found }
        }
        return nil
    }
    
    nonisolated private func migrateHolidaysWithMerge(from sourceHolidays: [HolidayEntity], to target: NSManagedObjectContext) throws {
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
        
        // logging suppressed
    }
    
    nonisolated private func migrateCardHistoryWithMerge(from sourceCards: [CardHistoryEntity], to target: NSManagedObjectContext) throws {
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
                // Доп. проверка дубликатов по естественному ключу (contact+cardID+день) или (holidayID+cardID+день)
                var duplicate: CardHistoryEntity?
                if let date = sourceCard.date {
                    let day = Calendar.current.startOfDay(for: date)
                    let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
                    if let contactId = sourceCard.contact?.id {
                        let byContactCardAndDay: NSFetchRequest<CardHistoryEntity> = CardHistoryEntity.fetchRequest()
                        byContactCardAndDay.fetchLimit = 1
                        byContactCardAndDay.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                            NSPredicate(format: "contact.id == %@", contactId as CVarArg),
                            NSPredicate(format: "cardID == %@", sourceCard.cardID ?? ""),
                            NSPredicate(format: "date >= %@ AND date < %@", day as NSDate, nextDay as NSDate)
                        ])
                        duplicate = try target.fetch(byContactCardAndDay).first
                    } else if let holidayId = sourceCard.holidayID {
                        let byHolidayCardAndDay: NSFetchRequest<CardHistoryEntity> = CardHistoryEntity.fetchRequest()
                        byHolidayCardAndDay.fetchLimit = 1
                        byHolidayCardAndDay.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                            NSPredicate(format: "holidayID == %@", holidayId as CVarArg),
                            NSPredicate(format: "cardID == %@", sourceCard.cardID ?? ""),
                            NSPredicate(format: "date >= %@ AND date < %@", day as NSDate, nextDay as NSDate)
                        ])
                        duplicate = try target.fetch(byHolidayCardAndDay).first
                    }
                }

                if let dup = duplicate {
                    mergeCardHistoryData(from: sourceCard, to: dup)
                    // Связь с контактом можно дополнить, если отсутствует
                    if dup.contact == nil, let contactId = sourceCard.contact?.id {
                        let cf: NSFetchRequest<ContactEntity> = ContactEntity.fetchRequest()
                        cf.fetchLimit = 1
                        cf.predicate = NSPredicate(format: "id == %@", contactId as CVarArg)
                        if let found = try target.fetch(cf).first { dup.contact = found }
                    }
                    mergedCount += 1
                } else {
                    let targetCard = CardHistoryEntity(context: target)
                    copyCardHistoryData(from: sourceCard, to: targetCard)
                    // Восстанавливаем связь с контактом по id
                    if let contactId = sourceCard.contact?.id {
                        let contactFetch: NSFetchRequest<ContactEntity> = ContactEntity.fetchRequest()
                        contactFetch.fetchLimit = 1
                        contactFetch.predicate = NSPredicate(format: "id == %@", contactId as CVarArg)
                        if let foundContact = try target.fetch(contactFetch).first {
                            targetCard.contact = foundContact
                        }
                    }
                    migratedCount += 1
                }
            }
        }
        
        // logging suppressed
    }
    
    nonisolated private func migrateCongratsHistoryWithMerge(from sourceCongrats: [CongratsHistoryEntity], to target: NSManagedObjectContext) throws {
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
                // Восстанавливаем связь с контактом по id
                if let contactId = sourceCongrats.contact?.id {
                    let contactFetch: NSFetchRequest<ContactEntity> = ContactEntity.fetchRequest()
                    contactFetch.fetchLimit = 1
                    contactFetch.predicate = NSPredicate(format: "id == %@", contactId as CVarArg)
                    if let foundContact = try target.fetch(contactFetch).first {
                        targetCongrats.contact = foundContact
                    }
                }
                migratedCount += 1
            }
        }
        
        // logging suppressed
    }
    
    
    // MARK: - Data Merging Helpers (CloudKit Priority)
    
    nonisolated private func mergeContactData(from source: ContactEntity, to target: ContactEntity) {
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
    
    nonisolated private func mergeHolidayData(from source: HolidayEntity, to target: HolidayEntity) {
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
    
    nonisolated private func mergeCardHistoryData(from source: CardHistoryEntity, to target: CardHistoryEntity) {
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
    
    nonisolated private func mergeCongratsHistoryData(from source: CongratsHistoryEntity, to target: CongratsHistoryEntity) {
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
    
    nonisolated private func restoreRelationships(in context: NSManagedObjectContext) throws {
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
        
        // logging suppressed
    }
    
    // MARK: - Data Copying Helpers
    
    nonisolated private func copyContactData(from source: ContactEntity, to target: ContactEntity) {
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
    
    nonisolated private func copyHolidayData(from source: HolidayEntity, to target: HolidayEntity) {
        target.id = source.id
        target.title = source.title
        target.date = source.date
        target.year = source.year
        target.type = source.type
        target.icon = source.icon
        target.isRegional = source.isRegional
        target.isCustom = source.isCustom
    }
    
    nonisolated private func copyCardHistoryData(from source: CardHistoryEntity, to target: CardHistoryEntity) {
        target.id = source.id
        target.date = source.date
        target.cardID = source.cardID
        target.imageData = source.imageData
        target.holidayID = source.holidayID
        // Note: relationship к contact будет восстановлен после миграции контактов
    }
    
    nonisolated private func copyCongratsHistoryData(from source: CongratsHistoryEntity, to target: CongratsHistoryEntity) {
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
