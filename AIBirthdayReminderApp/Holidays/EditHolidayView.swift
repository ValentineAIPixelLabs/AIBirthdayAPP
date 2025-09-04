import SwiftUI

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


@MainActor struct EditHolidayView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var icon: String
    @State private var holidayBirthday: Birthday
    @State private var type: HolidayType
    @State private var showEmojiPicker = false

    let holidayId: UUID
    let isCustom: Bool
    let isRegional: Bool
    let onSave: (Holiday) -> Void

    init(holiday: Holiday, onSave: @escaping (Holiday) -> Void, onCancel: @escaping () -> Void) {
        self.holidayId = holiday.id
        _title = State(initialValue: holiday.title)
        _icon = State(initialValue: holiday.icon ?? "")
        _type = State(initialValue: holiday.type)
        let comps = Calendar.current.dateComponents([.day, .month], from: holiday.date)
        _holidayBirthday = State(initialValue: Birthday(
            day: comps.day ?? 1,
            month: comps.month ?? 1,
            year: holiday.year
        ))
        self.isCustom = holiday.isCustom
        self.isRegional = holiday.isRegional
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            EditorTheme.background.ignoresSafeArea()
            Form {
                AvatarHeaderSection(
                    source: {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedIcon.isEmpty {
                            return .emoji(trimmedIcon)
                        } else {
                            let initial = trimmedTitle.first.map { String($0).uppercased() } ?? "?"
                            return .monogram(initial)
                        }
                    }(),
                    shape: .circle,
                    size: .headerXL,
                    buttonTitle: String(localized: "holiday.icon.select", defaultValue: "Выбрать иконку", bundle: appBundle(), locale: appLocale()),
                    onTap: { showEmojiPicker = true }
                )
                
                // Основная информация
                Section(
                    header: Text(String(localized: "add.section.main_info", defaultValue: "Основная информация", bundle: appBundle(), locale: appLocale())),
                    footer: Text(String(localized: "edit_holiday.section.main.footer", defaultValue: "Введите название праздника и выберите дату и тип.", bundle: appBundle(), locale: appLocale()))
                ) {
                    TextField(String(localized: "add_holiday.title.placeholder", defaultValue: "Название праздника", bundle: appBundle(), locale: appLocale()), text: $title)
                        .textContentType(.name)

                    BirthdayField(birthday: $holidayBirthday, titleKey: "add_holiday.date")

                    Picker(String(localized: "add_holiday.type", defaultValue: "Тип", bundle: appBundle(), locale: appLocale()), selection: $type) {
                        ForEach(HolidayType.allCases, id: \.self) { value in
                            Text(value.title).tag(value)
                        }
                    }
                }
                
                // Особенности (для пользовательских праздников)
                if isCustom {
                    Section(
                        header: Text(String(localized: "edit_holiday.section.special", defaultValue: "Особенности", bundle: appBundle(), locale: appLocale())),
                        footer: Text(String(localized: "edit_holiday.custom.footer", defaultValue: "Это пользовательский праздник, добавленный вами.", bundle: appBundle(), locale: appLocale()))
                    ) {
                        Text(String(localized: "edit_holiday.custom.badge", defaultValue: "Это пользовательский праздник", bundle: appBundle(), locale: appLocale()))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            //.background(Color(.systemGroupedBackground))
            //.navigationTitle("Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save", defaultValue: "Сохранить", bundle: appBundle(), locale: appLocale())) {
                        let parsedYear: Int? = holidayBirthday.year
                        let baseYear = 2000
                        var dc = DateComponents()
                        dc.year = baseYear
                        dc.month = holidayBirthday.month
                        dc.day = holidayBirthday.day
                        let normalizedDate = Calendar.current.startOfDay(for: Calendar.current.date(from: dc) ?? Date())
                        let updatedHoliday = Holiday(
                            id: holidayId,
                            title: title,
                            date: normalizedDate,
                            year: parsedYear,
                            type: type,
                            icon: icon.isEmpty ? nil : icon,
                            isRegional: isRegional,
                            isCustom: isCustom
                        )
                        onSave(updatedHoliday)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", defaultValue: "Отмена", bundle: appBundle(), locale: appLocale())) { dismiss() }
                }
            }
            .navigationBarBackButtonHidden(true)
            .sheet(isPresented: $showEmojiPicker) {
                EmojiPickerView { emoji in
                    DispatchQueue.main.async {
                        if let emoji = emoji {
                            icon = emoji
                        }
                        showEmojiPicker = false
                    }
                }
            }
        }
    }
}
