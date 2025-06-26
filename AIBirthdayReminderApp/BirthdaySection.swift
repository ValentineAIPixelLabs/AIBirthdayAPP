//
//  BirthdaySection.swift
//  AIBirthdayReminderApp
//
//  Created by Валентин Станков on 26.06.2025.
//

import Foundation

enum BirthdaySection: Hashable {
    case today // "Сегодня"
    case upcoming // "Скоро"
    case month(month: Int, year: Int)
    case noBirthday // "Без даты рождения"
}

struct SectionedContacts: Hashable {
    let section: BirthdaySection
    let contacts: [Contact]
}

class BirthdaySectionsViewModel {
    let contacts: [Contact]
    let calendar = Calendar.current
    let now: Date = Calendar.current.startOfDay(for: Date())
    let maxUpcomingDays: Int = 30

    init(contacts: [Contact]) {
        self.contacts = contacts
    }

    /// Главная функция: секционирует контакты по правилам
    func sectionedContacts() -> [SectionedContacts] {
        // Контакты без даты рождения
        let noBirthdayContacts = contacts.filter { $0.birthday == nil }

        // Для каждого контакта ищем следующий ДР и сколько дней до него
        let birthdayTuples = contacts.compactMap { contact -> (Contact, Date, Int)? in
            guard let bday = contact.birthday else { return nil }
            let nextDate = nextBirthdayDate(from: bday, now: now)
            let days = calendar.dateComponents([.day], from: now, to: nextDate).day ?? 9999
            return (contact, nextDate, days)
        }

        // "Сегодня": дни рождения сегодня (days == 0)
        let today = birthdayTuples
            .filter { $0.2 == 0 }
            .sorted { $0.0.name < $1.0.name } // сортировка по имени для стабильности
            .map { $0.0 }

        // "Скоро": дни рождения в ближайшие 30 дней, кроме сегодняшних
        let upcoming = birthdayTuples
            .filter { $0.2 > 0 && $0.2 <= maxUpcomingDays }
            .sorted { $0.2 < $1.2 }
            .map { $0.0 }

        // Группируем остальные по месяцам и годам
        var contactsByMonthYear: [BirthdaySection: [Contact]] = [:]
        for (contact, nextDate, days) in birthdayTuples {
            if days <= maxUpcomingDays && days >= 0 {
                continue // Уже в today или upcoming
            }
            let comps = calendar.dateComponents([.month, .year], from: nextDate)
            guard let month = comps.month, let year = comps.year else { continue }
            let key = BirthdaySection.month(month: month, year: year)
            contactsByMonthYear[key, default: []].append(contact)
        }

        // Сортируем секции по возрастанию (от ближайших месяцев)
        let sortedSections = contactsByMonthYear.keys.sorted {
            sectionSortKey($0) < sectionSortKey($1)
        }

        // Сортируем контакты внутри секции по дате следующего дня рождения
        let monthSections = sortedSections.compactMap { section -> SectionedContacts? in
            guard let list = contactsByMonthYear[section] else { return nil }
            let sortedContacts = list.sorted {
                let d1 = nextBirthdayDate(from: $0.birthday!, now: now)
                let d2 = nextBirthdayDate(from: $1.birthday!, now: now)
                return d1 < d2
            }
            return SectionedContacts(section: section, contacts: sortedContacts)
        }

        // Итоговый список секций
        var result: [SectionedContacts] = []
        if !today.isEmpty {
            result.append(SectionedContacts(section: .today, contacts: today))
        }
        if !upcoming.isEmpty {
            result.append(SectionedContacts(section: .upcoming, contacts: upcoming))
        }
        result.append(contentsOf: monthSections)
        if !noBirthdayContacts.isEmpty {
            result.append(SectionedContacts(section: .noBirthday, contacts: noBirthdayContacts))
        }
        return result
    }

    /// Сортировка секций: сперва "Сегодня", потом "Скоро", потом текущий месяц, потом все последующие по порядку
    private func sectionSortKey(_ section: BirthdaySection) -> Int {
        switch section {
        case .today: return -2
        case .upcoming: return -1
        case .month(let month, let year):
            let currComps = calendar.dateComponents([.month, .year], from: now)
            let currYear = currComps.year ?? 0
            let currMonth = currComps.month ?? 1
            return (year - currYear) * 12 + (month - currMonth)
        case .noBirthday: return 10000
        }
    }

    /// Следующий день рождения (дата в будущем)
    func nextBirthdayDate(from birthday: Birthday, now: Date) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: now)
        comps.month = birthday.month
        comps.day = birthday.day
        // Если в этом году уже прошёл — берём следующий год
        if let dt = calendar.date(from: comps), dt >= now {
            return dt
        } else {
            comps.year = (comps.year ?? 0) + 1
            return calendar.date(from: comps)!
        }
    }

    /// Для отображения заголовка секции
    func sectionTitle(_ section: BirthdaySection) -> String {
        switch section {
        case .today:
            return "Сегодня"
        case .upcoming:
            return "Скоро"
        case .month(let month, let year):
            let df = DateFormatter()
            df.locale = Locale(identifier: "ru_RU")
            df.dateFormat = "LLLL" // именительный падеж
            let monthName = df.standaloneMonthSymbols[(month-1) % 12].capitalized
            let currComps = calendar.dateComponents([.month, .year], from: now)
            let currMonth = currComps.month ?? 0
            let currYear = currComps.year ?? 0
            if currMonth == month && year > currYear {
                return "\(monthName) \(year)"
            } else {
                return monthName
            }
        case .noBirthday:
            return "Без даты рождения"
        }
    }
}
