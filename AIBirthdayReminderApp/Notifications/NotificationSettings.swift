import Foundation

struct NotificationSettings: Codable, Equatable {
    var enabled: Bool
    var daysBefore: [Int] // например [7,1,0]
    var hour: Int         // 24-часовой формат
    var minute: Int
}

extension NotificationSettings {
    static let `default` = NotificationSettings(
        enabled: true,
        daysBefore: [7,1,0],
        hour: 9,
        minute: 0
    )
}

extension NotificationSettings {
    private static let userDefaultsKey = "notificationSettings"

    static func load() -> NotificationSettings {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            return settings
        } else {
            return .default
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: NotificationSettings.userDefaultsKey)
        }
    }
}
