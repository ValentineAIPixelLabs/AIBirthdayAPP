import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()

    let persistentContainer: NSPersistentContainer

    private init() {
        persistentContainer = NSPersistentContainer(name: "Model") // Имя должно совпадать с .xcdatamodeld
        persistentContainer.loadPersistentStores { (description, error) in
            if let error = error {
                fatalError("Core Data failed: \(error.localizedDescription)")
            }
        }
    }

    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
                print("Core Data: saveContext() — данные успешно сохранены.")
            } catch {
                print("Core Data ERROR в saveContext():", error)
            }
        }
    }
}
