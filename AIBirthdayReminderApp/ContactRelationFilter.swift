//
//  ContactRelationFilter.swift
//  AIBirthdayReminderApp
//
//  Created by Валентин Станков on 27.06.2025.
//


import Foundation


class ChipRelationFilter: ObservableObject {
    @Published var selected: String
    let allRelations: [String] // маленькими!
    let specialAll = "все контакты"
    let specialNoBirthday = "без даты рождения"

    init(relations: [String]) {
        let chips = relations.map { $0.lowercased() }
        self.allRelations = [specialAll] + chips + [specialNoBirthday]
        self.selected = specialAll
    }

    func toggle(_ relation: String) {
        selected = relation
    }

    func isSelected(_ relation: String) -> Bool {
        selected == relation
    }

    // Фильтрация по выбранному чипу
    func filter(contacts: [Contact]) -> [Contact] {
        if selected == specialAll {
            return contacts
        }
        if selected == specialNoBirthday {
            return contacts.filter { $0.birthday == nil }
        }
        // Обычный фильтр по отношению
        return contacts.filter { $0.relationType?.lowercased() == selected }
    }
}
