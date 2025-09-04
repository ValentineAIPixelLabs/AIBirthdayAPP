import Foundation
import EventKit

class HolidayCalendarImporter {
    let eventStore = EKEventStore()

    // MARK: - Private helpers
    private func hasReadAccess() -> Bool {
        if #available(iOS 17.0, *) {
            return EKEventStore.authorizationStatus(for: .event) == .fullAccess
        } else {
            return EKEventStore.authorizationStatus(for: .event) == .authorized
        }
    }

    // MARK: - Birthday filters (RU/EN/ES)
    private func normalizedLowercased(_ string: String) -> String {
        string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX")).lowercased()
    }

    private func isBirthdayTitle(_ raw: String) -> Bool {
        let s = normalizedLowercased(raw)
        // EN
        if s.contains("birthday") || s.contains("b-day") || s.contains("bday") { return true }
        // RU (use broader root to catch variants like "День рожд. Пети")
        if s.contains("день рожд") || s.contains("именин") { return true }
        // common short RU slang "др" as a separate word (split by non-alphanumerics)
        let tokens = s.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        if tokens.contains("др") { return true }
        // ES (normalize diacritics: cumpleaños -> cumpleanos)
        if s.contains("cumpleanos") || s.range(of: "(^|\\b)cumple(\\b|[^a-z])", options: [.regularExpression]) != nil { return true }
        // Spanish onomastic/name-day
        if s.contains("onomast") { return true }
        return false
    }

    private func isBirthdayCalendar(_ calendar: EKCalendar) -> Bool {
        if calendar.type == .birthday { return true }
        return isBirthdayTitle(calendar.title)
    }

    private func isBirthdayEvent(_ event: EKEvent) -> Bool {
        if isBirthdayCalendar(event.calendar) { return true }
        if isBirthdayTitle(event.title) { return true }
        if let url = event.url?.absoluteString.lowercased(), url.contains("x-apple-contact") { return true }
        return false
    }

    private func mapType(for calendar: EKCalendar) -> HolidayType {
        let name = calendar.title.lowercased()
        if name.contains("религ") || name.contains("relig") || name.contains("church") {
            return .religious
        }
        if name.contains("проф") || name.contains("professional") || name.contains("work") {
            return .professional
        }
        if name.contains("birthday") || name.contains("день рождения") {
            return .personal
        }
        return .official
    }
    
    /// Запросить доступ к календарю пользователя
    func requestAccess(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }
    
    /// Получить события, которые похожи на праздники
    func fetchHolidayEvents(completion: @escaping ([Holiday]) -> Void) {
        guard hasReadAccess() else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            var holidays: [Holiday] = []

            // Фильтруем календари: выбираем праздничные и исключаем дни рождения (RU/EN/ES)
            var calendars = self.eventStore.calendars(for: .event).filter { cal in
                let name = self.normalizedLowercased(cal.title)
                let looksHoliday = name.contains("holiday") || name.contains("праздник") || name.contains("праздники")
                return looksHoliday && !self.isBirthdayCalendar(cal)
            }
            if calendars.isEmpty {
                calendars = self.eventStore.calendars(for: .event)
                    .filter { !self.isBirthdayCalendar($0) } // fallback: все, но без календаря дней рождений
            }

            let calendar = Calendar.current
            let startDate = calendar.date(from: calendar.dateComponents([.year], from: Date()))!
            let endDate = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: startDate)!

            let predicate = self.eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
            let events = self.eventStore.events(matching: predicate)

            var seen: Set<String> = []
            for event in events {
                // Исключаем события, распознанные как дни рождения (RU/EN/ES)
                if self.isBirthdayEvent(event) { continue }
                guard event.isAllDay else { continue }
                let day = calendar.startOfDay(for: event.startDate)
                let key = "\(event.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))|\(day.timeIntervalSince1970)"
                if seen.contains(key) { continue }
                seen.insert(key)

                holidays.append(
                    Holiday(
                        title: event.title,
                        date: day,
                        year: nil,
                        type: self.mapType(for: event.calendar),
                        icon: nil,
                        isRegional: false,
                        isCustom: false
                    )
                )
            }
            holidays.sort { $0.nextOccurrence() < $1.nextOccurrence() }

            DispatchQueue.main.async {
                completion(holidays)
            }
        }
    }
}
