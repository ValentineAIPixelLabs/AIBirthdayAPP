//
//  Holiday.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 25.06.2025.
//

import Foundation

struct Holiday: Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var title: String
    var date: Date
    var type: HolidayType
    var icon: String?
    var isHidden: Bool = false
    var isRegional: Bool
    var isCustom: Bool
    var relatedProfession: String?
}

extension Holiday: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, title, date, type, icon, isHidden, isRegional, isCustom, relatedProfession
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        type = try container.decode(HolidayType.self, forKey: .type)
        icon = try? container.decode(String.self, forKey: .icon)
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        isRegional = try container.decodeIfPresent(Bool.self, forKey: .isRegional) ?? false
        isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
        relatedProfession = try? container.decode(String.self, forKey: .relatedProfession)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(date, forKey: .date)
        try container.encode(type, forKey: .type)
        try container.encode(icon, forKey: .icon)
        try container.encode(isHidden, forKey: .isHidden)
        try container.encode(isRegional, forKey: .isRegional)
        try container.encode(isCustom, forKey: .isCustom)
        try container.encode(relatedProfession, forKey: .relatedProfession)
    }
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
