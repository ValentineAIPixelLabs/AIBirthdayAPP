import SwiftUI

// MARK: - Localization helpers (file-local)
private func appLocale() -> Locale {
    if let code = UserDefaults.standard.string(forKey: "app.language.code") { return Locale(identifier: code) }
    if let code = Bundle.main.preferredLocalizations.first { return Locale(identifier: code) }
    return .current
}
private func appBundle() -> Bundle {
    if let code = UserDefaults.standard.string(forKey: "app.language.code"),
       let path = Bundle.main.path(forResource: code, ofType: "lproj"),
       let bundle = Bundle(path: path) { return bundle }
    return .main
}

struct BirthdayField: View {
    @Binding var birthday: Birthday?
    var titleKey: LocalizedStringKey = "add.section.birthday"

    init(birthday: Binding<Birthday?>, titleKey: LocalizedStringKey = "add.section.birthday") {
        self._birthday = birthday
        self.titleKey = titleKey
    }

    init(birthday: Binding<Birthday>, titleKey: LocalizedStringKey = "add.section.birthday") {
        self._birthday = Binding<Birthday?>(get: {
            birthday.wrappedValue
        }, set: { newValue in
            if let newValue { birthday.wrappedValue = newValue }
        })
        self.titleKey = titleKey
    }

    @State private var isExpanded = false
    @State private var tempDay: Int = Calendar.current.component(.day, from: Date())
    @State private var tempMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var tempYear: Int? = Calendar.current.component(.year, from: Date())

    let currentYear = Calendar.current.component(.year, from: Date())
    let minYear = 1900

    private var years: [Int?] {
        [nil] + (stride(from: currentYear, through: minYear, by: -1).map { Optional($0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(titleKey)
                Spacer()
                Button(action: {
                    prepareTempValues()
                    isExpanded.toggle()
                }) {
                    Text(displayedDate())
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                prepareTempValues()
                isExpanded.toggle()
            }

            if isExpanded {
                HStack(spacing: 0) {
                    Picker("", selection: $tempDay) {
                        ForEach(1...daysIn(month: tempMonth, year: tempYear), id: \.self) {
                            Text("\($0)").tag($0)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 70)
                    .clipped()

                    Picker("", selection: $tempMonth) {
                        ForEach(1...12, id: \.self) { m in
                            Text(Self.localizedMonthStandalone(m)).tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Picker("", selection: Binding(
                        get: { tempYear ?? -1 },
                        set: { tempYear = $0 == -1 ? nil : $0 }
                    )) {
                        ForEach(years, id: \.self) { year in
                            if let year {
                                Text("\(year)").tag(year)
                            } else {
                                Text("—").tag(-1)
                            }
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 90)
                    .clipped()
                }
                .frame(height: 216)
                .onChange(of: tempMonth) { _ in
                    adjustDay()
                    save()
                }
                .onChange(of: tempYear) { _ in
                    adjustDay()
                    save()
                }
                .onChange(of: tempDay) { _ in
                    save()
                }
            }
        }
        .padding(.vertical, 8)
        .animation(nil, value: isExpanded)
    }

    private func prepareTempValues() {
        if let b = birthday {
            if let day = b.day {
                tempDay = day
            }
            if let month = b.month {
                tempMonth = month
            }
            tempYear = b.year
        } else {
            let now = Date()
            let cal = Calendar.current
            tempDay = cal.component(.day, from: now)
            tempMonth = cal.component(.month, from: now)
            tempYear = cal.component(.year, from: now)
        }
    }

    private func save() {
        birthday = Birthday(day: tempDay, month: tempMonth, year: tempYear)
    }

    private func displayedDate() -> String {
        guard let b = birthday, let day = b.day, let month = b.month else {
            let bundle = appBundle()
            return bundle.localizedString(forKey: "common.specify", value: "Указать", table: "Localizable")
        }
        var comps = DateComponents()
        comps.day = day
        comps.month = month
        // If year is nil or below 1900, show only day + month in a locale-correct form
        let df = DateFormatter()
        df.locale = appLocale()
        if let year = b.year, year >= 1900 {
            comps.year = year
            if let date = Calendar.current.date(from: comps) {
                df.setLocalizedDateFormatFromTemplate("d MMMM y")
                return df.string(from: date)
            }
        } else {
            // Use a dummy leap-safe year to format without year
            comps.year = 2020
            if let date = Calendar.current.date(from: comps) {
                df.setLocalizedDateFormatFromTemplate("d MMMM")
                return df.string(from: date)
            }
        }
        let bundle = appBundle()
        return bundle.localizedString(forKey: "common.specify", value: "Указать", table: "Localizable")
    }

    private func adjustDay() {
        let maxDay = daysIn(month: tempMonth, year: tempYear)
        if tempDay > maxDay {
            tempDay = maxDay
        }
    }

    private func daysIn(month: Int, year: Int?) -> Int {
        var comps = DateComponents()
        comps.month = month
        comps.year = year ?? 2020
        let calendar = Calendar.current
        return calendar.range(of: .day, in: .month, for: calendar.date(from: comps)!)?.count ?? 31
    }

    static func localizedMonthStandalone(_ month: Int) -> String {
        let df = DateFormatter()
        df.locale = appLocale()
        let symbols = df.standaloneMonthSymbols ?? df.monthSymbols ?? []
        if (1...12).contains(month), month-1 < symbols.count {
            return symbols[month - 1].capitalized(with: appLocale())
        }
        return ""
    }
    
    
}
