
import Foundation
import UserNotifications

// MARK: - Localization helpers (match in-app language)
private func appLocale() -> Locale {
    if let code = UserDefaults.standard.string(forKey: "app.language.code") {
        return Locale(identifier: code)
    }
    if let code = Bundle.main.preferredLocalizations.first {
        return Locale(identifier: code)
    }
    return Locale.current
}

private func appBundle() -> Bundle {
    if let code = UserDefaults.standard.string(forKey: "app.language.code"),
       let path = Bundle.main.path(forResource: code, ofType: "lproj"),
       let bundle = Bundle(path: path) {
        return bundle
    }
    return .main
}

@MainActor class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if !granted {
                    print("Push permission denied")
                }
            }
        }
    }

    func scheduleBirthdayNotifications(for contact: Contact, settings: NotificationSettings) {
        removeBirthdayNotifications(for: contact)
        guard settings.enabled else { return }
        
        for daysBefore in settings.daysBefore {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "notification.title.soon", defaultValue: "Скоро День Рождения!", bundle: appBundle(), locale: appLocale())
            
            if daysBefore == 0 {
                // Уведомление на сам день рождения
                content.title = String.localizedStringWithFormat(
                    String(localized: "notification.today.title", defaultValue: "Сегодня День рождения у %@! 🎉", bundle: appBundle(), locale: appLocale()),
                    contact.name
                )
                content.body = String(localized: "notification.today.body", defaultValue: "Отправь поздравление и открытку прямо сейчас! 🎁", bundle: appBundle(), locale: appLocale())
            } else {
                // Уведомление за несколько дней до дня рождения
                if let birthday = contact.birthday {
                    content.body = String.localizedStringWithFormat(
                        String(localized: "notification.upcoming.body.withdate", defaultValue: "%@ празднует День Рождения %@. Не забудь поздравить!", bundle: appBundle(), locale: appLocale()),
                        contact.name,
                        formatDate(birthday)
                    )
                } else {
                    content.body = String.localizedStringWithFormat(
                        String(localized: "notification.upcoming.body.generic", defaultValue: "%@ празднует День Рождения. Не забудь поздравить!", bundle: appBundle(), locale: appLocale()),
                        contact.name
                    )
                }
            }
            
            content.sound = .default

            guard let triggerDate = birthdayTriggerDate(birthday: contact.birthday, daysBefore: daysBefore, hour: settings.hour, minute: settings.minute) else { continue }
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let request = UNNotificationRequest(
                identifier: notificationIdentifier(for: contact, daysBefore: daysBefore),
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    func removeBirthdayNotifications(for contact: Contact) {
        let identifiers = (0...7).map { notificationIdentifier(for: contact, daysBefore: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func notificationIdentifier(for contact: Contact, daysBefore: Int) -> String {
        "birthday_\(contact.id.uuidString)_\(daysBefore)"
    }

    private func birthdayTriggerDate(birthday: Birthday?, daysBefore: Int, hour: Int, minute: Int) -> DateComponents? {
        guard let birthday = birthday, let day = birthday.day, let month = birthday.month else { return nil }
        var comps = DateComponents()
        comps.day = day
        comps.month = month
        let year = Calendar.current.component(.year, from: Date())
        comps.year = year
        comps.hour = hour
        comps.minute = minute

        guard let date = Calendar.current.date(from: comps) else { return nil }
        guard let finalDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: date) else { return nil }
        return Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: finalDate)
    }
    func checkAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }

    private func formatDate(_ birthday: Birthday) -> String {
        guard let day = birthday.day, let month = birthday.month else {
            return String(localized: "contact.birthday.missing", defaultValue: "Дата рождения не указана", bundle: appBundle(), locale: appLocale())
        }
        var comps = DateComponents()
        comps.day = day
        comps.month = month
        comps.year = Calendar.current.component(.year, from: Date())
        let calendar = Calendar.current
        guard let date = calendar.date(from: comps) else {
            return String(localized: "contact.birthday.missing", defaultValue: "Дата рождения не указана", bundle: appBundle(), locale: appLocale())
        }
        let df = DateFormatter()
        df.locale = appLocale()
        df.setLocalizedDateFormatFromTemplate("d MMMM")
        return df.string(from: date)
    }
}

    func checkNotificationAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
