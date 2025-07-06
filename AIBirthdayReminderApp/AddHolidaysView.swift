//
//  AddHolidaysView.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 05.07.2025.
//


import SwiftUI

struct AddHolidaysView: View {
    @Binding var isPresented: Bool
    let onAdd: (Holiday) -> Void

    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var type: HolidayType = .personal
    @State private var icon: String = ""

    var body: some View {
        ZStack {
            AppBackground()
            NavigationStack {
            Form {
                Section(header: Text("Основное")) {
                    TextField("Название праздника", text: $title)
                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                    Picker("Тип", selection: $type) {
                        ForEach(HolidayType.allCases, id: \.self) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    TextField("Эмодзи", text: $icon)
                }
            }
            .navigationTitle("Новый праздник")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        let holiday = Holiday(
                            title: title,
                            date: date,
                            type: type,
                            icon: icon.isEmpty ? nil : icon,
                            isRegional: false,
                            isCustom: true,
                            relatedProfession: nil
                        )
                        onAdd(holiday)
                        title = ""
                        date = Date()
                        type = .personal
                        icon = ""
                        isPresented = false
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            }
        }
    }
}
