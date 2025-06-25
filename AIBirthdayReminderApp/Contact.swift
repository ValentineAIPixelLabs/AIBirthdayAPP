//
//  Contact.swift
//  AIBirthdayReminderApp
//
//  Created by Валентин Станков on 11.06.2025.
//
import Foundation

struct Contact: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var surname: String?
    var nickname: String?
    
    var fullName: String {
        if let surname = surname, !surname.isEmpty {
            return "\(name) \(surname)"
        } else {
            return name
        }
    }
    
    var relationType: String?
    var gender: String?
    var birthday: Birthday?
    var notificationSettings: NotificationSettings = .default
    var imageData: Data?
    var emoji: String?
    var occupation: String?
    var hobbies: String?
    var leisure: String?
    var additionalInfo: String?
    
    var age: Int? {
        guard let birthday = birthday, let year = birthday.year else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        return currentYear - year
    }
    
    static func == (lhs: Contact, rhs: Contact) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.surname == rhs.surname &&
        lhs.nickname == rhs.nickname &&
        lhs.relationType == rhs.relationType &&
        lhs.gender == rhs.gender &&
        lhs.birthday == rhs.birthday &&
        lhs.notificationSettings == rhs.notificationSettings &&
        lhs.emoji == rhs.emoji &&
        lhs.imageData == rhs.imageData &&
        lhs.occupation == rhs.occupation &&
        lhs.hobbies == rhs.hobbies &&
        lhs.leisure == rhs.leisure &&
        lhs.additionalInfo == rhs.additionalInfo
    }
}

struct Birthday: Codable, Equatable {
    var day: Int?
    var month: Int?
    var year: Int? // Optional year
}
extension Contact: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
