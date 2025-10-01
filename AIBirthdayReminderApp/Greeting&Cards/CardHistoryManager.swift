import UIKit
import CoreData

struct CardHistoryItemWithImage {
    let id: UUID
    let date: Date
    let cardID: String
    let image: UIImage?
}

@MainActor
final class CardHistoryManager {
    private static var viewContext: NSManagedObjectContext {
        CoreDataManager.shared.viewContext
    }

    /// Добавить открытку в Core Data
    static func addCard(item: CardHistoryItem, image: UIImage, for contactId: UUID, completion: (() -> Void)? = nil) {
        CoreDataManager.shared.performBackgroundTask(author: "addCard") { ctx in
            let request: NSFetchRequest<ContactEntity> = ContactEntity.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "id == %@", contactId as CVarArg)

            do {
                guard let contact = try ctx.fetch(request).first else {
                    print("❌ Не найден контакт с id: \(contactId)")
                    return
                }

                // Сначала ищем по id
                let byId: NSFetchRequest<CardHistoryEntity> = CardHistoryEntity.fetchRequest()
                byId.fetchLimit = 1
                byId.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)

                // Если по id не нашли, пытаемся дедуплицировать по (contact + день(date) + cardID)
                let day = Calendar.current.startOfDay(for: item.date)
                let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day)!
                let byContactCardAndDay: NSFetchRequest<CardHistoryEntity> = CardHistoryEntity.fetchRequest()
                byContactCardAndDay.fetchLimit = 1
                byContactCardAndDay.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "contact == %@", contact),
                    NSPredicate(format: "cardID == %@", item.cardID),
                    NSPredicate(format: "date >= %@ AND date < %@", day as NSDate, nextDay as NSDate)
                ])

                let entity: CardHistoryEntity
                if let found = try ctx.fetch(byId).first {
                    entity = found
                } else if let dup = try ctx.fetch(byContactCardAndDay).first {
                    entity = dup
                    if entity.id == nil { entity.id = item.id }
                } else {
                    let e = CardHistoryEntity(context: ctx)
                    e.id = item.id
                    entity = e
                }
                entity.date = item.date
                entity.cardID = item.cardID
                // JPEG обычно заметно меньше PNG. При включенном Allows External Storage большие данные уйдут в CKAsset.
                entity.imageData = image.jpegData(compressionQuality: 0.85)
                if let data = entity.imageData {
                    print("🧠 Сохранено imageData, размер: \(data.count) байт (JPEG 0.85)")
                } else {
                    print("⚠️ imageData получилось nil")
                }
                entity.contact = contact
                print("🧩 Привязана к контакту: \(contact.id?.uuidString ?? "nil")")
            } catch {
                assertionFailure("❌ Ошибка выборки контакта для открытки: \(error)")
            }
            do {
                try ctx.save()
                print("✅ Core Data: bgContext(addCard) сохранён")
                if let completion = completion {
                    Task { @MainActor in completion() }
                }
            } catch {
                assertionFailure("❌ Не удалось сохранить открытку (addCard): \(error)")
            }
        }
    }

    /// Получить все открытки для контакта
    static func getCards(for contactId: UUID) -> [CardHistoryItemWithImage] {
        let request: NSFetchRequest<CardHistoryEntity> = CardHistoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "contact.id == %@", contactId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CardHistoryEntity.date, ascending: false)]
        request.fetchBatchSize = 50

        do {
            let results = try viewContext.fetch(request)
            
            return results.map {
                CardHistoryItemWithImage(
                    id: $0.id ?? UUID(),
                    date: $0.date ?? .distantPast,
                    cardID: $0.cardID ?? "",
                    image: $0.imageData.flatMap { UIImage(data: $0) }
                )
            }
        } catch {
            print("❌ Не удалось загрузить открытки: \(error)")
            return []
        }
    }

    /// Добавить открытку по празднику (без привязки к контакту)
    static func addCardForHoliday(item: CardHistoryItem, image: UIImage, holidayId: UUID, completion: (() -> Void)? = nil) {
        CoreDataManager.shared.performBackgroundTask(author: "addCardHoliday") { ctx in
            // Сначала ищем по id, затем дедуп по (holidayID + день(date) + cardID)
            let byId: NSFetchRequest<CardHistoryEntity> = CardHistoryEntity.fetchRequest()
            byId.fetchLimit = 1
            byId.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)

            let day = Calendar.current.startOfDay(for: item.date)
            let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day)!
            let byHolidayCardAndDay: NSFetchRequest<CardHistoryEntity> = CardHistoryEntity.fetchRequest()
            byHolidayCardAndDay.fetchLimit = 1
            byHolidayCardAndDay.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "holidayID == %@", holidayId as CVarArg),
                NSPredicate(format: "cardID == %@", item.cardID),
                NSPredicate(format: "date >= %@ AND date < %@", day as NSDate, nextDay as NSDate)
            ])

            let entity: CardHistoryEntity
            if let found = (try? ctx.fetch(byId))?.first {
                entity = found
            } else if let dup = (try? ctx.fetch(byHolidayCardAndDay))?.first {
                entity = dup
                if entity.id == nil { entity.id = item.id }
            } else {
                let e = CardHistoryEntity(context: ctx)
                e.id = item.id
                entity = e
            }
            entity.date = item.date
            entity.cardID = item.cardID
            entity.holidayID = holidayId // <-- поле в модели Core Data
            entity.imageData = image.jpegData(compressionQuality: 0.85)
            if let data = entity.imageData {
                print("🧠 Сохранено imageData, размер: \(data.count) байт (JPEG 0.85)")
            } else {
                print("⚠️ imageData получилось nil")
            }
            // Явно не привязываем к контакту
            entity.contact = nil
            do {
                try ctx.save()
                print("✅ Core Data: bgContext(addCardHoliday) сохранён")
                if let completion = completion {
                    Task { @MainActor in completion() }
                }
            } catch {
                assertionFailure("❌ Не удалось сохранить открытку (addCardForHoliday): \(error)")
            }
        }
    }

    /// Получить все открытки для праздника
    static func getCards(forHoliday holidayId: UUID) -> [CardHistoryItemWithImage] {
        let request: NSFetchRequest<CardHistoryEntity> = CardHistoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "holidayID == %@", holidayId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CardHistoryEntity.date, ascending: false)]
        request.fetchBatchSize = 50

        do {
            let results = try viewContext.fetch(request)
           
            return results.map {
                CardHistoryItemWithImage(
                    id: $0.id ?? UUID(),
                    date: $0.date ?? .distantPast,
                    cardID: $0.cardID ?? "",
                    image: $0.imageData.flatMap { UIImage(data: $0) }
                )
            }
        } catch {
            print("❌ Не удалось загрузить открытки по празднику: \(error)")
            return []
        }
    }

    

    /// Удалить открытку по id
    static func deleteCard(_ id: UUID) {
        CoreDataManager.shared.performBackgroundTask(author: "deleteCard") { ctx in
            let request: NSFetchRequest<CardHistoryEntity> = CardHistoryEntity.fetchRequest()
            request.fetchLimit = 1
            
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            do {
                if let entity = try ctx.fetch(request).first {
                    print("🗑️ ✅ Открытка найдена для удаления: \(id)")
                    ctx.delete(entity)
                    try ctx.save()
                    print("🗑 Открытка удалена и сохранена: \(id)")
                } else {
                    print("🗑️ ❌ Открытка НЕ найдена для удаления: \(id)")
                }
            } catch {
                assertionFailure("❌ Ошибка выборки открытки для удаления: \(error)")
            }
        }
    }

    // MARK: - Helpers
    private static func fetchCard(by id: UUID, in ctx: NSManagedObjectContext) throws -> CardHistoryEntity? {
        let req: NSFetchRequest<CardHistoryEntity> = CardHistoryEntity.fetchRequest()
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try ctx.fetch(req).first
    }
}
