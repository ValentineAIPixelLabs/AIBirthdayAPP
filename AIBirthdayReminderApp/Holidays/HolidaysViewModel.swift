import Foundation
import SwiftUI
import Combine
import CoreData

@MainActor
class HolidaysViewModel: ObservableObject {
    @Published var holidays: [Holiday] = []
    @Published var searchText: String = ""

    // MARK: - Init
    init() {
        if CoreDataManager.shared.hasLoadedStores {
            loadFromCoreData()
        }
        setupStorageModeObserver()
    }

    // MARK: - Public API (Computed)
    var filteredHolidays: [Holiday] {
        guard !searchText.isEmpty else { return holidays }
        return holidays.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - Public API (CRUD)
    func addHoliday(_ holiday: Holiday) {
        CoreDataManager.shared.performBackgroundTask(author: "addHoliday") { ctx in
            // 1) Попробуем найти по id
            let byId: NSFetchRequest<HolidayEntity> = HolidayEntity.fetchRequest()
            byId.fetchLimit = 1
            byId.predicate = NSPredicate(format: "id == %@", holiday.id as CVarArg)

            // 2) Также проверим дубликат по (title + дата-в-тот-же-день)
            let day = Calendar.current.startOfDay(for: holiday.date)
            guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day) else { return }
            let byTitleAndDay: NSFetchRequest<HolidayEntity> = HolidayEntity.fetchRequest()
            byTitleAndDay.fetchLimit = 1
            byTitleAndDay.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "title == %@", holiday.title),
                NSPredicate(format: "date >= %@ AND date < %@", day as NSDate, nextDay as NSDate)
            ])

            do {
                let existing: HolidayEntity?
                if let byIdFirst = try ctx.fetch(byId).first {
                    existing = byIdFirst
                } else {
                    existing = try ctx.fetch(byTitleAndDay).first
                }
                let entity: HolidayEntity = existing ?? HolidayEntity(context: ctx)
                if existing == nil {
                    entity.id = holiday.id
                }
                entity.title = holiday.title
                entity.date = holiday.date
                entity.year = Int16(holiday.year ?? 0)
                entity.type = holiday.type.rawValue
                entity.icon = holiday.icon
                entity.isRegional = holiday.isRegional
                entity.isCustom = holiday.isCustom
                if existing == nil {
                    try ctx.obtainPermanentIDs(for: [entity])
                }
                try ctx.save()
                #if DEBUG
                print("✅ Core Data: bgContext(addHoliday) сохранён")
                #endif
            } catch {
                assertionFailure("❌ addHoliday fetch error: \(error)")
            }
        }
        // Обновим вью‑модель после фонового сохранения (простая перезагрузка списка)
        reloadAfterBackgroundChange()
    }

    func updateHoliday(_ holiday: Holiday) {
        CoreDataManager.shared.performBackgroundTask(author: "updateHoliday") { ctx in
            let req: NSFetchRequest<HolidayEntity> = HolidayEntity.fetchRequest()
            req.fetchLimit = 1
            req.predicate = NSPredicate(format: "id == %@", holiday.id as CVarArg)
            do {
                if let entity = try ctx.fetch(req).first {
                    entity.title = holiday.title
                    entity.date = holiday.date
                    entity.year = Int16(holiday.year ?? 0)
                    entity.type = holiday.type.rawValue
                    entity.icon = holiday.icon
                    entity.isRegional = holiday.isRegional
                    entity.isCustom = holiday.isCustom
                }
                try ctx.save()
                #if DEBUG
                print("✅ Core Data: bgContext(updateHoliday) сохранён")
                #endif
            } catch {
                assertionFailure("❌ updateHoliday fetch error: \(error)")
            }
        }
        reloadAfterBackgroundChange()
    }

    func deleteHoliday(_ holiday: Holiday) {
        CoreDataManager.shared.performBackgroundTask(author: "deleteHoliday") { ctx in
            let req: NSFetchRequest<HolidayEntity> = HolidayEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", holiday.id as CVarArg)
            req.fetchLimit = 1
            
            do {
                if let entity = try ctx.fetch(req).first {
                    print("🗑️ ✅ Праздник найден для удаления: \(holiday.id)")
                    ctx.delete(entity)
                    try ctx.save()
                    #if DEBUG
                    print("🗑 Core Data: bgContext(deleteHoliday) сохранён")
                    #endif
                } else {
                    print("🗑️ ❌ Праздник НЕ найден для удаления: \(holiday.id)")
                }
            } catch {
                assertionFailure("❌ deleteHoliday fetch error: \(error)")
            }
        }
        reloadAfterBackgroundChange()
    }

    // MARK: - Private

    private func reloadAfterBackgroundChange() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms, даём времени фоновому контексту сохраниться
            self.loadFromCoreData()
        }
    }

    @MainActor private func loadFromCoreData() {
        guard CoreDataManager.shared.hasLoadedStores else { return }
        let ctx = CoreDataManager.shared.viewContext
        ctx.perform { [weak self] in
            // Загружаем все праздники
            let req: NSFetchRequest<HolidayEntity> = HolidayEntity.fetchRequest()
            do {
                let items = try ctx.fetch(req)
                let mapped = items.map { self?.toModel($0) ?? Holiday(id: UUID(), title: "", date: Date(), year: nil, type: .other, icon: nil, isRegional: false, isCustom: false) }
                Task { @MainActor in
                    self?.holidays = mapped
                }
            } catch {
                print("❌ Не удалось загрузить праздники из Core Data: \(error)")
                Task { @MainActor in
                    self?.holidays = []
                }
            }
        }
    }

    nonisolated private func toModel(_ e: HolidayEntity) -> Holiday {
        let mappedYear: Int? = {
            let y = Int(e.year)
            guard y >= 1900 else { return nil }
            return y
        }()
        return Holiday(
            id: e.id ?? UUID(),
            title: e.title ?? "",
            date: e.date ?? Date(),
            year: mappedYear,
            type: HolidayType(rawValue: e.type ?? "other") ?? .other,
            icon: e.icon,
            isRegional: e.isRegional,
            isCustom: e.isCustom
        )
    }
    
    // MARK: - Storage Mode Observer
    
    private func setupStorageModeObserver() {
        NotificationCenter.default.addObserver(
            forName: .storageModeSwitched,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Перезагружаем данные при смене режима
            Task { @MainActor in
                self?.loadFromCoreData()
            }
        }
    }
}
