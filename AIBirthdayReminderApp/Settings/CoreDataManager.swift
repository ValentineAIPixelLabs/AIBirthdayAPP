import Foundation
import CoreData

@MainActor
final class CoreDataManager {
    static let shared = CoreDataManager()

    let persistentContainer: NSPersistentContainer

    /// Удобный алиас для viewContext
    var viewContext: NSManagedObjectContext { persistentContainer.viewContext }

    /// Для обратной совместимости с существующим кодом
    var context: NSManagedObjectContext { viewContext }

    private init() {
        let modelName = "Model" // must match .xcdatamodeld

        // 1) Load a single compiled model from the app bundle (.momd), avoiding merged models.
        guard
            let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd"),
            let model = NSManagedObjectModel(contentsOf: modelURL)
        else {
            fatalError("❌ Не удалось загрузить NSManagedObjectModel \(modelName).momd из бандла")
        }

        // 2) Prepare a stable store URL in Application Support
        let fm = FileManager.default
        let appSupport = try! fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let storeURL = appSupport.appendingPathComponent("\(modelName).sqlite")

        // Ensure directory exists (iOS creates it lazily)
        if !fm.fileExists(atPath: appSupport.path) {
            try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }

        // Helper: detect migration/incompatibility errors
        func isIncompatibilityError(_ error: Error) -> Bool {
            let e = error as NSError
            guard e.domain == NSCocoaErrorDomain else { return false }
            // Most common Core Data incompatibility/migration errors
            let codes: [Int] = [
                NSPersistentStoreIncompatibleVersionHashError,
                NSMigrationMissingSourceModelError,
                NSMigrationError,
                NSPersistentStoreIncompatibleSchemaError,
                NSPersistentStoreOpenError
            ]
            return codes.contains(e.code)
        }

        // Helper: load stores, on incompatibility nuke and retry once
        func loadStoresOrResetOnce(_ container: NSPersistentContainer, at url: URL) -> Error? {
            var loadError: Error?
            let sem = DispatchSemaphore(value: 0)
            container.loadPersistentStores { _, error in
                loadError = error
                sem.signal()
            }
            sem.wait()
            if let err = loadError, isIncompatibilityError(err) {
                #if DEBUG
                print("⚠️ loadPersistentStores incompatibility: \(err). Deleting local store and retrying once…")
                #endif
                let sidecars = [url, url.appendingPathExtension("wal"), url.appendingPathExtension("shm")]
                for f in sidecars { try? fm.removeItem(at: f) }
                loadError = nil
                let sem2 = DispatchSemaphore(value: 0)
                container.loadPersistentStores { _, error in
                    loadError = error
                    sem2.signal()
                }
                sem2.wait()
            }
            return loadError
        }

        // Helper: preflight existing SQLite for model compatibility and delete if incompatible (DEBUG-safe)
        func nukeIfIncompatible(model: NSManagedObjectModel, at url: URL) {
            let sidecars = [url, url.appendingPathExtension("wal"), url.appendingPathExtension("shm")]
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            do {
                let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: url)
                let ok = model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
                if !ok {
                    #if DEBUG
                    print("🧨 Preflight: incompatible SQLite for current model → deleting \(url.lastPathComponent)")
                    #endif
                    sidecars.forEach { try? FileManager.default.removeItem(at: $0) }
                }
            } catch {
                // Если метаданные не читаются, в дев-цикле разумно снести локальный стор
                #if DEBUG
                print("⚠️ Preflight: cannot read store metadata (\(error)) → deleting local store")
                #endif
                sidecars.forEach { try? FileManager.default.removeItem(at: $0) }
            }
        }

        // 3) Preflight the dev store for compatibility (only affects existing local files)
        nukeIfIncompatible(model: model, at: storeURL)

        // 4) Try CloudKit first, built with the SAME model
        do {
            let cloud = NSPersistentCloudKitContainer(name: modelName, managedObjectModel: model)

            if let description = cloud.persistentStoreDescriptions.first {
                description.url = storeURL

                // Force specific CloudKit container (must match entitlements)
                let containerID = "iCloud.com.ValentinStancov.AIBirthdayReminderApp"
                description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerID)
                print("🔗 CloudKit container ID (forced): \(containerID)")

                // History/remote-change options
                description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

                // Automigrations
                description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
                description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            }

            let cloudLoadError = loadStoresOrResetOnce(cloud, at: storeURL)

            if let err = cloudLoadError {
                print("⚠️ CloudKit недоступен, переключаемся на локальный стор. Причина: \(err)")

                // 5) Local fallback with the SAME model and same URL
                let local = NSPersistentContainer(name: modelName, managedObjectModel: model)
                if let description = local.persistentStoreDescriptions.first {
                    description.url = storeURL
                    // Automigrations & parity with cloud options
                    description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
                    description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
                    description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                    description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                }

                let localLoadError = loadStoresOrResetOnce(local, at: storeURL)
                if let e = localLoadError {
                    fatalError("❌ Core Data ошибка загрузки локального стора: \(e)")
                }

                persistentContainer = local
                print("✅ Core Data (локальный стор) загружена")
            } else {
                persistentContainer = cloud
                print("✅ Core Data с CloudKit успешно загружена")
            }
            // Observe CloudKit mirroring resets and remote changes for clearer logs
            NotificationCenter.default.addObserver(forName: NSNotification.Name("NSPersistentStoreRemoteChange"), object: persistentContainer.persistentStoreCoordinator, queue: .main) { _ in
                #if DEBUG
                print("📡 NSPersistentStoreRemoteChange received")
                #endif
            }
            NotificationCenter.default.addObserver(forName: NSNotification.Name("NSCloudKitMirroringDelegateWillResetSyncNotification"), object: nil, queue: .main) { note in
                #if DEBUG
                print("☁️ Mirroring WILL RESET (reason: \(note.userInfo?["reason"] ?? "unknown"))")
                #endif
            }
            NotificationCenter.default.addObserver(forName: NSNotification.Name("NSCloudKitMirroringDelegateDidResetSyncNotification"), object: nil, queue: .main) { _ in
                #if DEBUG
                print("☁️ Mirroring DID RESET")
                #endif
            }
        }
        #if DEBUG
        // One‑time (DEBUG) CloudKit schema initialization for Development environment
        if let ck = persistentContainer as? NSPersistentCloudKitContainer {
            do {
                try ck.initializeCloudKitSchema(options: [])
                print("☁️ CloudKit dev schema initialized/updated from Core Data model")
            } catch {
                print("⚠️ initializeCloudKitSchema failed: \(error)")
            }
        }
        let modelPtr = Unmanaged.passUnretained(persistentContainer.managedObjectModel).toOpaque()
        print("📦 NSManagedObjectModel @", modelPtr)
        for s in persistentContainer.persistentStoreCoordinator.persistentStores {
            let mPtr = Unmanaged.passUnretained(persistentContainer.persistentStoreCoordinator.managedObjectModel).toOpaque()
            print("• store:", s.type, "url:", s.url?.lastPathComponent ?? "nil", "model @", mPtr)
        }
        #endif
        // Common viewContext configuration
        let ctx = persistentContainer.viewContext
        ctx.name = "viewContext"
        ctx.automaticallyMergesChangesFromParent = true
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.transactionAuthor = "app"
        ctx.shouldDeleteInaccessibleFaults = true
    }

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
}
