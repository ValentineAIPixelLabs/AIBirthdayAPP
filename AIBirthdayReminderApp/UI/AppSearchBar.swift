//
//  AppSearchBar.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 10.07.2025.
//


import SwiftUI

struct AppSearchable: ViewModifier {
    @Binding var text: String
    var prompt: String = "Поиск"
    var placement: SearchFieldPlacement = .automatic

    func body(content: Content) -> some View {
        content
            .searchable(text: $text, placement: placement, prompt: prompt)
    }
}

extension View {
    func appSearchable(text: Binding<String>, prompt: String = "Поиск", placement: SearchFieldPlacement = .automatic) -> some View {
        self.modifier(AppSearchable(text: text, prompt: prompt, placement: placement))
    }
}
