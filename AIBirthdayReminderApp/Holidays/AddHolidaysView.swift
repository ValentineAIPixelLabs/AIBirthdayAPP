import SwiftUI
import Foundation

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

struct AddHolidaysView: View {
    @Binding var isPresented: Bool
    let onAdd: (Holiday) -> Void

    @State private var title: String = ""
    @State private var icon: String = ""
    @State private var holidayBirthday = Birthday(
        day: Calendar.current.component(.day, from: Date()),
        month: Calendar.current.component(.month, from: Date()),
        year: nil
    )
    @State private var type: HolidayType = .personal
    @FocusState private var titleFocused: Bool

    var body: some View {
        ZStack {
            AppBackground()
            Form {
                Section(header: Text(String(localized: "add_holiday.section.main", defaultValue: "Основное", bundle: appBundle(), locale: appLocale()))) {
                    TextField(String(localized: "add_holiday.title.placeholder", defaultValue: "Название праздника", bundle: appBundle(), locale: appLocale()), text: $title)
                        .focused($titleFocused)
                    BirthdayField(birthday: $holidayBirthday, titleKey: "add_holiday.date")
                    Picker(String(localized: "add_holiday.type", defaultValue: "Тип", bundle: appBundle(), locale: appLocale()), selection: $type) {
                        ForEach(HolidayType.allCases, id: \.self) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    TextField(String(localized: "add_holiday.emoji.placeholder", defaultValue: "Эмодзи", bundle: appBundle(), locale: appLocale()), text: $icon)
                        .onChange(of: icon) { newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { icon = ""; return }
                            // Разрешаем только одно расширенное графемное кластер (обычно одно эмодзи)
                            let first = String(trimmed.prefix(1))
                            icon = first
                        }
                }
            }
            .navigationTitle(String(localized: "add_holiday.nav.title", defaultValue: "Новый праздник", bundle: appBundle(), locale: appLocale()))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.add", defaultValue: "Добавить", bundle: appBundle(), locale: appLocale())) {
                        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let emoji = icon.trimmingCharacters(in: .whitespacesAndNewlines)
                        let baseYear = 2000
                        var dc = DateComponents()
                        dc.year = baseYear
                        dc.month = holidayBirthday.month
                        dc.day = holidayBirthday.day
                        let normalizedDate = Calendar.current.startOfDay(for: Calendar.current.date(from: dc) ?? Date())
                        let parsedYear: Int? = holidayBirthday.year
                        let holiday = Holiday(
                            title: name,
                            date: normalizedDate,
                            year: parsedYear,
                            type: type,
                            icon: emoji.isEmpty ? nil : emoji,
                            isRegional: false,
                            isCustom: true
                        )
                        onAdd(holiday)
                        // reset state
                        title = ""
                        type = .personal
                        icon = ""
                        holidayBirthday = Birthday(
                            day: Calendar.current.component(.day, from: Date()),
                            month: Calendar.current.component(.month, from: Date()),
                            year: nil
                        )
                        isPresented = false
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { titleFocused = true }
        }
    }
}
