import Foundation
// MARK: - Localization helpers (file-local)
private func appLocale() -> Locale {
    if let code = UserDefaults.standard.string(forKey: "app.language.code") {
        return Locale(identifier: code)
    }
    if let code = Bundle.main.preferredLocalizations.first {
        return Locale(identifier: code)
    }
    return .current
}
private func appBundle() -> Bundle {
    if let code = UserDefaults.standard.string(forKey: "app.language.code"),
       let path = Bundle.main.path(forResource: code, ofType: "lproj"),
       let bundle = Bundle(path: path) {
        return bundle
    }
    return .main
}


struct Holiday: Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var title: String
    var date: Date
    var year: Int? = nil
    var type: HolidayType
    var icon: String?
    var isRegional: Bool
    var isCustom: Bool
    var relatedProfession: String?
}

extension Holiday: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, title, date, year, type, icon, isRegional, isCustom, relatedProfession
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        type = try container.decode(HolidayType.self, forKey: .type)
        icon = try? container.decode(String.self, forKey: .icon)
        isRegional = try container.decodeIfPresent(Bool.self, forKey: .isRegional) ?? false
        isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
        relatedProfession = try? container.decode(String.self, forKey: .relatedProfession)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(year, forKey: .year)
        try container.encode(type, forKey: .type)
        try container.encode(icon, forKey: .icon)
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
        let key = "holiday.type.\(self.rawValue)" // e.g. holiday.type.official
        let fallback: String
        switch self {
        case .official:      fallback = "Официальный"
        case .religious:     fallback = "Религиозный"
        case .professional:  fallback = "Профессиональный"
        case .personal:      fallback = "Личный"
        case .other:         fallback = "Другое"
        }
        // Use selected in-app language bundle; fall back to previous Russian title
        let bundle = appBundle()
        return bundle.localizedString(forKey: key, value: fallback, table: "Localizable")
    }
}

// MARK: - Recurrence helper
extension Holiday {
    /// Returns the next calendar date (>= reference day) when this holiday occurs, based on its day and month.
    /// `year` is treated as an optional "foundation" year and does not affect recurrence.
    func nextOccurrence(from reference: Date = .now) -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: reference)
        let comps = cal.dateComponents([.month, .day], from: date)
        // Use nextDate to find the next matching month/day, including today if matches.
        if let next = cal.nextDate(
            after: start.addingTimeInterval(-1), // include today if same day
            matching: comps,
            matchingPolicy: .nextTime,
            direction: .forward
        ) {
            return next
        }
        // Fallback: construct next year with same month/day
        var dc = DateComponents()
        dc.year = cal.component(.year, from: start) + 1
        dc.month = comps.month
        dc.day = comps.day
        return cal.date(from: dc) ?? start
    }
}
