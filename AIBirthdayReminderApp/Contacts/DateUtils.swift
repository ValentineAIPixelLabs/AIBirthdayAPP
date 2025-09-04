import Foundation

// MARK: - Locale helper synced with in-app language
private func appLocale() -> Locale {
    if let code = UserDefaults.standard.string(forKey: "app.language.code") { // written by LanguageManager
        return Locale(identifier: code)
    }
    if let code = Bundle.main.preferredLocalizations.first {
        return Locale(identifier: code)
    }
    return Locale.current
}

// Resolve a .lproj bundle for the current in-app language, so String(localized:) obeys our picker
private func appBundle() -> Bundle {
    if let code = UserDefaults.standard.string(forKey: "app.language.code"),
       let path = Bundle.main.path(forResource: code, ofType: "lproj"),
       let bundle = Bundle(path: path) {
        return bundle
    }
    return .main
}

func isValidBirthday(_ birthday: Birthday?) -> Bool {
    guard let b = birthday else { return false }
    return (b.day ?? 0) > 0 && (b.month ?? 0) > 0
}

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
    let ageText = age > 0 ? ", \(age)\(ageAnniversarySuffix(for: age))" : ""
    if let surname = contact.surname, !surname.isEmpty {
        return "\(contact.name) \(surname)\(ageText)"
    } else {
        return "\(contact.name)\(ageText)"
    }
}

func birthdayDateDetails(for birthday: Birthday?) -> String {
    guard isValidBirthday(birthday) else {
        return String(localized: "contact.birthday.missing", defaultValue: "Дата рождения не указана", bundle: appBundle(), locale: appLocale())
    }

    let locale = appLocale()
    let next = nextBirthdayDate(from: birthday!)
    let days = daysUntilNextBirthday(from: birthday!)

    let dateFormatter = DateFormatter()
    dateFormatter.locale = locale
    dateFormatter.setLocalizedDateFormatFromTemplate("d MMMM") // localizes month names
    let dateText = dateFormatter.string(from: next)

    let weekdayFormatter = DateFormatter()
    weekdayFormatter.locale = locale
    weekdayFormatter.setLocalizedDateFormatFromTemplate("EEEE")
    let weekday = weekdayFormatter.string(from: next).capitalized(with: locale)

    let prefix: String
    if days == 0 {
        prefix = String(localized: "date.today", defaultValue: "Сегодня", bundle: appBundle(), locale: appLocale())
    } else if days == 1 {
        prefix = String(localized: "date.tomorrow", defaultValue: "Завтра", bundle: appBundle(), locale: appLocale())
    } else {
        let unit = daysSuffix(for: days) // locale-aware
        prefix = String.localizedStringWithFormat(String(localized: "date.in_days", defaultValue: "Через %1$d %2$@", bundle: appBundle(), locale: appLocale()), days, unit)
    }

    // First line — day prefix and date, second line — weekday (UI can style bold as needed)
    return "\(prefix) · \(dateText)\n\(weekday)"
}

func ageOnNextBirthday(contact: Contact) -> Int {
    guard let birthday = contact.birthday, let year = birthday.year else { return 0 }
    let calendar = Calendar.current
    let next = nextBirthdayDate(from: birthday)
    let age = calendar.component(.year, from: next) - year
    return age
}

func ageAnniversarySuffix(for age: Int) -> String {
    // Russian uses "-летие"; English typically omits the suffix in titles (e.g., ", 30").
    let id = appLocale().identifier
    if id.hasPrefix("ru") { return "-летие" }
    return ""
}

func daysSuffix(for days: Int) -> String {
    let locale = appLocale()
    let id = locale.identifier
    if id.hasPrefix("ru") {
        let lastTwo = days % 100
        let last = days % 10
        if lastTwo >= 11 && lastTwo <= 14 { return "дней" }
        switch last {
        case 1: return "день"
        case 2, 3, 4: return "дня"
        default: return "дней"
        }
    } else {
        // English
        return days == 1 ? "day" : "days"
    }
}

func nextBirthdayDate(from birthday: Birthday) -> Date {
    guard isValidBirthday(birthday) else { return Date.distantFuture }
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
    guard isValidBirthday(birthday) else { return 0 }
    let calendar = Calendar.current
    let now = calendar.startOfDay(for: Date())
    let next = nextBirthdayDate(from: birthday)
    let nextDay = calendar.startOfDay(for: next)
    return calendar.dateComponents([.day], from: now, to: nextDay).day ?? 0
}

func dateStringRu(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = appLocale()
    formatter.setLocalizedDateFormatFromTemplate("d MMMM")
    return formatter.string(from: date)
}

// MARK: - Форматирование даты рождения (для ContactDetailView и других вьюшек)

func formattedBirthdayDetails(for birthday: Birthday?) -> String {
    guard let birthday = birthday else { return String(localized: "contact.birthday.missing", defaultValue: "Дата рождения не указана", bundle: appBundle(), locale: appLocale()) }
    if birthday.day == 0 && birthday.month == 0 {
        return String(localized: "contact.birthday.missing", defaultValue: "Дата рождения не указана", bundle: appBundle(), locale: appLocale())
    }
    let calendar = Calendar.current
    var components = DateComponents()
    components.day = birthday.day
    components.month = birthday.month
    components.year = birthday.year ?? 1900
    guard let date = calendar.date(from: components) else {
        return String(localized: "contact.birthday.missing", defaultValue: "Дата рождения не указана", bundle: appBundle(), locale: appLocale())
    }

    let formatter = DateFormatter()
    formatter.locale = appLocale()

    let label = String(localized: "birthday.label", defaultValue: "Дата рождения", bundle: appBundle(), locale: appLocale())

    if let _ = birthday.year {
        formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
        let dateString = formatter.string(from: date)
        let age = calculateAge(from: birthday)
        if age < 0 {
            return "\(label): \(dateString)"
        } else {
            return "\(label): \(dateString) (\(age) \(ageSuffix(for: age)))"
        }
    } else {
        formatter.setLocalizedDateFormatFromTemplate("d MMMM")
        let dateString = formatter.string(from: date)
        return "\(label): \(dateString)"
    }
}

func calculateAge(from birthday: Birthday) -> Int {
    guard let year = birthday.year else { return 0 }
    let calendar = Calendar.current
    let now = Date()
    let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
    var age = todayComponents.year! - year
    if let bMonth = birthday.month as Int?, let bDay = birthday.day as Int? {
        if (todayComponents.month! < bMonth) || (todayComponents.month! == bMonth && todayComponents.day! < bDay) {
            age -= 1
        }
    }
    return age
}

func ageSuffix(for age: Int) -> String {
    let id = appLocale().identifier
    if id.hasPrefix("ru") {
        let lastDigit = age % 10
        let lastTwo = age % 100
        if lastTwo >= 11 && lastTwo <= 14 { return "лет" }
        switch lastDigit {
        case 1: return "год"
        case 2, 3, 4: return "года"
        default: return "лет"
        }
    } else {
        return age == 1 ? "year" : "years"
    }
}
