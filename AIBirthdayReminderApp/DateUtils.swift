//
//  DateUtils.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 19.06.2025.
//

import Foundation

func subtitle(for contact: Contact) -> String {
    var result = ""
    if let relationType = contact.relationType, !relationType.isEmpty {
        result += relationType
    }
    if let nickname = contact.nickname, !nickname.isEmpty {
        if !result.isEmpty { result += " · " }
        result += "«\(nickname)»"
    }
    return result
}

func birthdayTitle(for contact: Contact) -> String {
    let age = ageOnNextBirthday(contact: contact)
    let ageText = age > 0 ? ", \(age)\(ageSuffix(for: age))" : ""
    if let surname = contact.surname, !surname.isEmpty {
        return "\(contact.name) \(surname)\(ageText)"
    } else {
        return "\(contact.name)\(ageText)"
    }
}

func birthdayDateDetails(for birthday: Birthday?) -> String {
    guard let birthday = birthday, (birthday.day != 0 || birthday.month != 0 || birthday.year != nil) else {
        return "Дата рождения не указана"
    }

    let next = nextBirthdayDate(from: birthday)
    let days = daysUntilNextBirthday(from: birthday)

    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "ru_RU")
    dateFormatter.dateFormat = "d MMMM"
    let dateText = dateFormatter.string(from: next)

    let weekdayFormatter = DateFormatter()
    weekdayFormatter.locale = Locale(identifier: "ru_RU")
    weekdayFormatter.dateFormat = "EEEE"
    let weekday = weekdayFormatter.string(from: next).capitalized

    let prefix: String
    if days == 0 {
        prefix = "Сегодня"
    } else if days == 1 {
        prefix = "Завтра"
    } else {
        prefix = "Через \(days) \(daysSuffix(for: days))"
    }

    // Две строки: первая — день, вторая — день недели (жирным стилем вывод можно сделать уже в UI)
    return "\(prefix) · \(dateText)\n\(weekday)"
}

func ageOnNextBirthday(contact: Contact) -> Int {
    guard let birthday = contact.birthday, let year = birthday.year else { return 0 }
    let calendar = Calendar.current
    let next = nextBirthdayDate(from: birthday)
    let age = calendar.component(.year, from: next) - year
    return age
}

func ageSuffix(for age: Int) -> String {
    let lastTwo = age % 100
    let last = age % 10
    if lastTwo >= 11 && lastTwo <= 14 {
        return "-летие"
    }
    switch last {
    case 1: return "-летие"
    case 2, 3, 4: return "-летие"
    default: return "-летие"
    }
}

func daysSuffix(for days: Int) -> String {
    let lastTwo = days % 100
    let last = days % 10
    if lastTwo >= 11 && lastTwo <= 14 {
        return "дней"
    }
    switch last {
    case 1: return "день"
    case 2, 3, 4: return "дня"
    default: return "дней"
    }
}

func nextBirthdayDate(from birthday: Birthday) -> Date {
    let calendar = Calendar.current
    let now = calendar.startOfDay(for: Date())
    let currentYear = calendar.component(.year, from: now)
    var dateComponents = DateComponents()
    dateComponents.day = birthday.day
    dateComponents.month = birthday.month
    dateComponents.year = currentYear
    guard let thisYearBirthday = calendar.date(from: dateComponents) else { return now }
    if thisYearBirthday >= now {
        return thisYearBirthday
    } else {
        dateComponents.year = currentYear + 1
        return calendar.date(from: dateComponents) ?? now
    }
}

func daysUntilNextBirthday(from birthday: Birthday) -> Int {
    let calendar = Calendar.current
    let now = calendar.startOfDay(for: Date())
    let next = nextBirthdayDate(from: birthday)
    let nextDay = calendar.startOfDay(for: next)
    return calendar.dateComponents([.day], from: now, to: nextDay).day ?? 0
}

func dateStringRu(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU")
    formatter.dateFormat = "d MMMM"
    return formatter.string(from: date)
}
