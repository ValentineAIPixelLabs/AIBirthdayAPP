
import Foundation
import CoreData

struct CongratsHistoryItem {
    let id: UUID
    let date: Date
    let message: String
}

final class CongratsHistoryManager {
    private static var context: NSManagedObjectContext {
        CoreDataManager.shared.context
    }

    /// Добавить поздравление
    static func addCongrats(item: CongratsHistoryItem, for contactId: UUID) {
        let request: NSFetchRequest<ContactEntity> = ContactEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", contactId as CVarArg)

        guard let contact = try? context.fetch(request).first else {
            print("❌ Контакт не найден для поздравления")
            return
        }

        let entity = CongratsHistoryEntity(context: context)
        entity.id = item.id
        entity.date = item.date
        entity.message = item.message
        entity.contact = contact

        do {
            try context.save()
            print("✅ Поздравление сохранено")
        } catch {
            print("❌ Ошибка при сохранении поздравления: \(error.localizedDescription)")
        }
    }

    /// Загрузить поздравления по id контакта
    static func getCongrats(for contactId: UUID) -> [CongratsHistoryItem] {
        let request: NSFetchRequest<CongratsHistoryEntity> = CongratsHistoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "contact.id == %@", contactId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        guard let results = try? context.fetch(request) else {
            print("❌ Ошибка при загрузке истории поздравлений")
            return []
        }

        return results.map {
            CongratsHistoryItem(
                id: $0.id ?? UUID(),
                date: $0.date ?? Date(),
                message: $0.message ?? ""
            )
        }
    }

    /// Удалить поздравление по id
    static func deleteCongrats(_ id: UUID) {
        let request: NSFetchRequest<CongratsHistoryEntity> = CongratsHistoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        guard let result = try? context.fetch(request), let entity = result.first else {
            print("❌ Поздравление не найдено для удаления")
            return
        }

        context.delete(entity)
        try? context.save()
        print("🗑 Поздравление удалено")
    }
}
