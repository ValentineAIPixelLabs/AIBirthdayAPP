//
//  Holiday.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 25.06.2025.
//

import Foundation

struct Holiday: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var title: String
    var date: Date
    var type: HolidayType
    var icon: String?
    var isRegional: Bool
    var isCustom: Bool
    var relatedProfession: String?
}

enum HolidayType: String, Codable, CaseIterable {
    case official
    case religious
    case professional
    case personal
    case other

    var title: String {
        switch self {
        case .official: return "Официальный"
        case .religious: return "Религиозный"
        case .professional: return "Профессиональный"
        case .personal: return "Личный"
        case .other: return "Другое"
        }
    }
}
