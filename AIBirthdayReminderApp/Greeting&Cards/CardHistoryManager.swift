import UIKit
import CoreData

struct CardHistoryItemWithImage {
    let id: UUID
    let date: Date
    let cardID: String
    let image: UIImage?
}

final class CardHistoryManager {
    private static var context: NSManagedObjectContext {
        CoreDataManager.shared.context
    }

    /// Добавить открытку в Core Data
    static func addCard(item: CardHistoryItem, image: UIImage, for contactId: UUID) {
        let request: NSFetchRequest<ContactEntity> = ContactEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", contactId as CVarArg)

        guard let contact = try? context.fetch(request).first else {
            print("❌ Не найден контакт с id: \(contactId)")
            return
        }

        let entity = CardHistoryEntity(context: context)
        entity.id = item.id
        entity.date = item.date
        entity.cardID = item.cardID
        entity.imageData = image.pngData()
        if let data = entity.imageData {
            print("🧠 Сохранено imageData, размер: \(data.count) байт")
        } else {
            print("⚠️ imageData получилось nil")
        }
        entity.contact = contact
        print("🧩 Привязана к контакту: \(contact.id?.uuidString ?? "nil")")

        do {
            try context.save()
            print("✅ Открытка сохранена: \(item.cardID)")
        } catch {
            print("❌ Ошибка при сохранении открытки: \(error.localizedDescription)")
        }
    }

    /// Получить все открытки для контакта
    static func getCards(for contactId: UUID) -> [CardHistoryItemWithImage] {
        let request: NSFetchRequest<CardHistoryEntity> = CardHistoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "contact.id == %@", contactId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        guard let results = try? context.fetch(request) else {
            print("❌ Не удалось загрузить открытки")
            return []
        }
        print("📦 Найдено открыток в Core Data: \(results.count) для контакта \(contactId)")
        return results.map {
            CardHistoryItemWithImage(
                id: $0.id ?? UUID(),
                date: $0.date ?? Date(),
                cardID: $0.cardID ?? "",
                image: $0.imageData.flatMap { UIImage(data: $0) }
            )
        }
    }
    static func logTotalCardImagesSize(for contactId: UUID) {
        let context = CoreDataManager.shared.context
        let request: NSFetchRequest<CardHistoryEntity> = CardHistoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "contact.id == %@", contactId as CVarArg)

        guard let results = try? context.fetch(request) else {
            print("❌ Не удалось загрузить открытки для подсчёта веса")
            return
        }

        let totalBytes = results.compactMap { $0.imageData?.count }.reduce(0, +)
        let totalMB = Double(totalBytes) / 1024 / 1024
        print("🧮 Общий размер всех открыток для контакта \(contactId): \(totalBytes) байт (\(String(format: "%.2f", totalMB)) MB)")
    }


    /// Удалить открытку по id
    static func deleteCard(_ id: UUID) {
        let request: NSFetchRequest<CardHistoryEntity> = CardHistoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        guard let result = try? context.fetch(request), let entity = result.first else {
            print("❌ Открытка с id \(id) не найдена")
            return
        }

        context.delete(entity)
        try? context.save()
        print("🗑 Открытка удалена: \(id)")
    }
}
