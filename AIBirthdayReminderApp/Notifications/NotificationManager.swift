import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if !granted {
                print("Push permission denied")
            }
        }
    }

    func scheduleBirthdayNotifications(for contact: Contact, settings: NotificationSettings) {
        removeBirthdayNotifications(for: contact)
        guard settings.enabled else { return }
        
        for daysBefore in settings.daysBefore {
            let content = UNMutableNotificationContent()
            content.title = "Скоро День Рождения!"
            
            if daysBefore == 0 {
                // Уведомление на сам день рождения
                content.title = "Сегодня День рождения у \(contact.name)! 🎉"
                content.body = "Отправь поздравление и открытку прямо сейчас! 🎁"
            } else {
                // Уведомление за несколько дней до дня рождения
                if let birthday = contact.birthday {
                    content.body = "\(contact.name) празднует День Рождения \(formatDate(birthday)). Не забудь поздравить!"
                } else {
                    content.body = "\(contact.name) празднует День Рождения. Не забудь поздравить!"
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
        guard let birthday = birthday else { return nil }
        var comps = DateComponents()
        comps.day = birthday.day
        comps.month = birthday.month
        let year = Calendar.current.component(.year, from: Date())
        comps.year = year
        comps.hour = hour
        comps.minute = minute

        guard let date = Calendar.current.date(from: comps) else { return nil }
        guard let finalDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: date) else { return nil }
        return Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: finalDate)
    }

    private func formatDate(_ birthday: Birthday) -> String {
        let monthsRu = [
            "января", "февраля", "марта", "апреля", "мая", "июня",
            "июля", "августа", "сентября", "октября", "ноября", "декабря"
        ]
        guard let day = birthday.day, let month = birthday.month else {
            return "Дата рождения не указана"
        }
        let monthName = monthsRu[month - 1]
        return String(format: "%d %@", day, monthName)
    }
}

    func checkNotificationAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
