import Foundation
import CoreData



@MainActor
final class CongratsHistoryManager {
    private static var viewContext: NSManagedObjectContext {
        CoreDataManager.shared.viewContext
    }

    /// Добавить поздравление
    static func addCongrats(item: CongratsHistoryItem, for contactId: UUID) {
        CoreDataManager.shared.performBackgroundTask(author: "addCongrats") { ctx in
            // Найти контакт в том же контексте
            let request: NSFetchRequest<ContactEntity> = ContactEntity.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "id == %@", contactId as CVarArg)

            do {
                guard let contact = try ctx.fetch(request).first else {
                    print("❌ Контакт не найден для поздравления (id=\(contactId))")
                    return
                }

                // Upsert по естественному ключу (id)
                let req: NSFetchRequest<CongratsHistoryEntity> = CongratsHistoryEntity.fetchRequest()
                req.fetchLimit = 1
                req.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)

                let entity = try ctx.fetch(req).first ?? {
                    let e = CongratsHistoryEntity(context: ctx)
                    e.id = item.id
                    return e
                }()
                entity.date = item.date
                entity.message = item.message
                entity.holidayID = nil
                entity.contact = contact
                try ctx.save()
                print("✅ Core Data: bgContext(addCongrats) сохранён")
            } catch {
                assertionFailure("❌ addCongrats fetch contact error: \(error)")
            }
        }
    }

    /// Загрузить поздравления по id контакта
    static func getCongrats(for contactId: UUID) -> [CongratsHistoryItem] {
        let request: NSFetchRequest<CongratsHistoryEntity> = CongratsHistoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "contact.id == %@", contactId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchBatchSize = 50

        do {
            let results = try viewContext.fetch(request)
            return results.map {
                CongratsHistoryItem(
                    id: $0.id ?? UUID(),
                    date: $0.date ?? Date(),
                    message: $0.message ?? ""
                )
            }
        } catch {
            print("❌ Ошибка при загрузке истории поздравлений: \(error)")
            return []
        }
    }

    /// Добавить поздравление по празднику (без привязки к контакту)
    static func addCongratsForHoliday(item: CongratsHistoryItem, holidayId: UUID) {
        CoreDataManager.shared.performBackgroundTask(author: "addCongratsHoliday") { ctx in
            do {
                // Upsert по id, чтобы избежать дубликатов
                let req: NSFetchRequest<CongratsHistoryEntity> = CongratsHistoryEntity.fetchRequest()
                req.fetchLimit = 1
                req.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)

                let existing = try ctx.fetch(req).first
                let target: CongratsHistoryEntity = existing ?? {
                    let e = CongratsHistoryEntity(context: ctx)
                    e.id = item.id
                    return e
                }()
                target.date = item.date
                target.message = item.message
                target.holidayID = holidayId
                target.contact = nil

                try ctx.save()
                print("✅ Core Data: bgContext(addCongratsHoliday) сохранён")
            } catch {
                assertionFailure("❌ addCongratsForHoliday error: \(error)")
            }
        }
    }

    /// Загрузить поздравления по id праздника
    static func getCongrats(forHoliday holidayId: UUID) -> [CongratsHistoryItem] {
        let request: NSFetchRequest<CongratsHistoryEntity> = CongratsHistoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "holidayID == %@", holidayId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchBatchSize = 50

        do {
            let results = try viewContext.fetch(request)
            return results.map {
                CongratsHistoryItem(
                    id: $0.id ?? UUID(),
                    date: $0.date ?? Date(),
                    message: $0.message ?? ""
                )
            }
        } catch {
            print("❌ Ошибка при загрузке поздравлений по празднику: \(error)")
            return []
        }
    }

    /// Удалить поздравление по id
    static func deleteCongrats(_ id: UUID) {
        CoreDataManager.shared.performBackgroundTask(author: "deleteCongrats") { ctx in
            let request: NSFetchRequest<CongratsHistoryEntity> = CongratsHistoryEntity.fetchRequest()
            request.fetchLimit = 1
            
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            do {
                if let entity = try ctx.fetch(request).first {
                    print("🗑️ ✅ Поздравление найдено для удаления: \(id)")
                    ctx.delete(entity)
                    try ctx.save()
                    print("🗑 Поздравление удалено и сохранено: \(id)")
                } else {
                    print("🗑️ ❌ Поздравление НЕ найдено для удаления: \(id)")
                }
            } catch {
                assertionFailure("❌ deleteCongrats fetch/save error: \(error)")
            }
        }
    }
    // MARK: - Helpers
    private static func fetchCongrats(by id: UUID, in ctx: NSManagedObjectContext) throws -> CongratsHistoryEntity? {
        let req: NSFetchRequest<CongratsHistoryEntity> = CongratsHistoryEntity.fetchRequest()
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try ctx.fetch(req).first
    }
}
