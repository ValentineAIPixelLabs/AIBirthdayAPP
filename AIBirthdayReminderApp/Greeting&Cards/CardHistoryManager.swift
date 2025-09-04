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

                // Upsert по id, чтобы не создавать дубликаты (CloudKit не поддерживает Unique Constraints)
                let req: NSFetchRequest<CardHistoryEntity> = CardHistoryEntity.fetchRequest()
                req.fetchLimit = 1
                req.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)

                let entity = try ctx.fetch(req).first ?? {
                    let e = CardHistoryEntity(context: ctx)
                    e.id = item.id
                    return e
                }()
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
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
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
            // Upsert по id, чтобы избежать дубликатов
            let req: NSFetchRequest<CardHistoryEntity> = CardHistoryEntity.fetchRequest()
            req.fetchLimit = 1
            req.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)

            let entity = (try? ctx.fetch(req).first) ?? {
                let e = CardHistoryEntity(context: ctx)
                e.id = item.id
                return e
            }()
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
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
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

    static func logTotalCardImagesSize(for contactId: UUID) {
        let ctx = viewContext
        let request: NSFetchRequest<CardHistoryEntity> = CardHistoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "contact.id == %@", contactId as CVarArg)

        do {
            let results = try ctx.fetch(request)
            let totalBytes = results.compactMap { $0.imageData?.count }.reduce(0, +)
            let totalMB = Double(totalBytes) / 1024 / 1024
            print("🧮 Общий размер всех открыток для контакта \(contactId): \(totalBytes) байт (\(String(format: "%.2f", totalMB)) MB)")
        } catch {
            print("❌ Не удалось загрузить открытки для подсчёта веса: \(error)")
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
                    ctx.delete(entity)
                    try ctx.save()
                    print("🗑 Открытка удалена и сохранена: \(id)")
                } else {
                    print("❌ Открытка с id \(id) не найдена")
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
