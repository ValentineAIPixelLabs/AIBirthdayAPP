import SwiftUI

struct EditHolidayView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var date: Date
    @State private var type: HolidayType
    @State private var icon: String
    @State private var relatedProfession: String
    @State private var showEmojiPicker = false

    let holidayId: UUID
    let isCustom: Bool
    let isRegional: Bool
    let onSave: (Holiday) -> Void

    init(holiday: Holiday, onSave: @escaping (Holiday) -> Void, onCancel: @escaping () -> Void) {
        self.holidayId = holiday.id
        _title = State(initialValue: holiday.title)
        _date = State(initialValue: holiday.date)
        _type = State(initialValue: holiday.type)
        _icon = State(initialValue: holiday.icon ?? "")
        _relatedProfession = State(initialValue: holiday.relatedProfession ?? "")
        self.isCustom = holiday.isCustom
        self.isRegional = holiday.isRegional
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            AppBackground()
            NavigationStack {
                VStack(spacing: 12) {
                    // Эмодзи-аватар
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 98, height: 98)
                            .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 2)
                        Text(icon.isEmpty ? "🎉" : icon)
                            .font(.system(size: 54))
                            .frame(width: 98, height: 98)
                    }
                    .padding(.top, 36)
                    .padding(.bottom, 18)
                    .onTapGesture {
                        showEmojiPicker = true
                    }

                    // Основная форма
                    Form {
                        Section(header: Text("Основная информация"), footer: Text("Введите название праздника и выберите дату и тип.")) {
                            TextField("Название праздника", text: $title)
                                .textContentType(.name)
                            DatePicker("Дата", selection: $date, displayedComponents: .date)
                            Picker("Тип", selection: $type) {
                                ForEach(HolidayType.allCases, id: \.self) { value in
                                    Text(value.title).tag(value)
                                }
                            }
                        }
                        if type == .professional {
                            Section(header: Text("Профессия"), footer: Text("Укажите профессию, связанную с праздником.")) {
                                TextField("Профессия (например, врач, педагог…)", text: $relatedProfession)
                            }
                        }
                        if isCustom {
                            Section(header: Text("Особенности"), footer: Text("Это пользовательский праздник, добавленный вами.")) {
                                Text("Это пользовательский праздник").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
                //.background(Color(.systemGroupedBackground))
                //.navigationTitle("Редактировать")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Сохранить") {
                            let updatedHoliday = Holiday(
                                id: holidayId,
                                title: title,
                                date: date,
                                type: type,
                                icon: icon.isEmpty ? nil : icon,
                                isHidden: false,
                                isRegional: isRegional,
                                isCustom: isCustom,
                                relatedProfession: relatedProfession.isEmpty ? nil : relatedProfession
                            )
                            onSave(updatedHoliday)
                            dismiss()
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.backward")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color.accentColor)
                        }
                    }
                }
                .navigationBarBackButtonHidden(true)
                .sheet(isPresented: $showEmojiPicker) {
                    EmojiPickerView { emoji in
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
