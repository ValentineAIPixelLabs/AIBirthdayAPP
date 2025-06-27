//
//  RegionalHolidaysPickerView.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 25.06.2025.
//

import SwiftUI
import Foundation
// TODO: Импортируйте Holiday, если требуется: import Holiday

struct RegionalHolidaysPickerView: View {
    @Binding var isPresented: Bool
    var onAdd: ([Holiday]) -> Void

    @State private var selectedRegion: String = "Россия"
    @State private var showProfessional: Bool = false
    @State private var selectedHolidays: Set<UUID> = []

    // Примеры регионов и праздничных дней
    let regions = ["Россия", "США", "Молдова"]
    let regionalHolidays: [String: [Holiday]] = [
        "Россия": [
            Holiday(title: "День России", date: Date(), type: .official, icon: "🇷🇺", isRegional: true, isCustom: false, relatedProfession: nil)
        ],
        "США": [
            Holiday(title: "День независимости", date: Date(), type: .official, icon: "🇺🇸", isRegional: true, isCustom: false, relatedProfession: nil)
        ],
        "Молдова": [
            Holiday(title: "День независимости Молдовы", date: Date(), type: .official, icon: "🇲🇩", isRegional: true, isCustom: false, relatedProfession: nil)
        ]
    ]
    let professionalHolidays: [String: [Holiday]] = [
        "Россия": [
            Holiday(title: "День медика", date: Date(), type: .professional, icon: "🩺", isRegional: true, isCustom: false, relatedProfession: "Врач")
        ],
        "США": [
            Holiday(title: "День учителя", date: Date(), type: .professional, icon: "🍎", isRegional: true, isCustom: false, relatedProfession: "Учитель")
        ],
        "Молдова": [
            Holiday(title: "День бухгалтера", date: Date(), type: .professional, icon: "🧮", isRegional: true, isCustom: false, relatedProfession: "Бухгалтер")
        ]
    ]
    // TODO: Загрузка реальных данных для праздников

    var body: some View {
        NavigationStack {
            Form {
                Picker("Регион", selection: $selectedRegion) {
                    ForEach(regions, id: \.self) { region in
                        Text(region).tag(region)
                    }
                }
                Section(header: Text("Праздники региона")) {
                    ForEach(regionalHolidays[selectedRegion] ?? []) { holiday in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { selectedHolidays.contains(holiday.id) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedHolidays.insert(holiday.id)
                                    } else {
                                        selectedHolidays.remove(holiday.id)
                                    }
                                }
                            )) {
                                Label(holiday.title, systemImage: holiday.icon ?? "calendar")
                            }
                        }
                    }
                }
                Toggle("Показать профессиональные праздники", isOn: $showProfessional)
                if showProfessional {
                    Section(header: Text("Проф. праздники")) {
                        ForEach(professionalHolidays[selectedRegion] ?? []) { holiday in
                            HStack {
                                Toggle(isOn: Binding(
                                    get: { selectedHolidays.contains(holiday.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedHolidays.insert(holiday.id)
                                        } else {
                                            selectedHolidays.remove(holiday.id)
                                        }
                                    }
                                )) {
                                    Label(holiday.title, systemImage: holiday.icon ?? "calendar")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Праздники по региону")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить выбранные") {
                        let regionHols = regionalHolidays[selectedRegion] ?? []
                        let profHols = showProfessional ? (professionalHolidays[selectedRegion] ?? []) : []
                        let allHolidays = (regionHols + profHols).filter { selectedHolidays.contains($0.id) }
                        onAdd(allHolidays)
                        isPresented = false
                    }.disabled(selectedHolidays.isEmpty)
                }
            }
        }
    }
}
