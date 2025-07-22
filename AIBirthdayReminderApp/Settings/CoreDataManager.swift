import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()

    let persistentContainer: NSPersistentCloudKitContainer

    private init() {
        let container = NSPersistentCloudKitContainer(name: "Model") // Имя должно совпадать с .xcdatamodeld

        // Подключаем CloudKit-схему
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("❌ Не удалось получить описание persistent store")
        }

        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.loadPersistentStores { (desc, error) in
            if let error = error {
                fatalError("❌ Core Data (CloudKit) ошибка: \(error.localizedDescription)")
            } else {
                print("✅ Core Data с CloudKit успешно загружена")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        self.persistentContainer = container
        
    }

    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
                print("✅ Core Data: изменения успешно сохранены.")
            } catch {
                print("❌ Core Data ошибка при сохранении: \(error.localizedDescription)")
            }
        }
    }
}


