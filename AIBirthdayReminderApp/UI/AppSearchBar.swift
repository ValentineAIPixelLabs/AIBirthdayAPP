//
//  AppSearchBar.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 10.07.2025.
//


import SwiftUI

struct AppSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Поиск"
    var onCommit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppButtonStyle.SearchBar.iconColor)
            TextField(placeholder, text: $text, onCommit: {
                onCommit?()
            })
            .font(AppButtonStyle.SearchBar.font)
            .foregroundColor(AppButtonStyle.SearchBar.textColor)
            .autocapitalization(.none)
            .disableAutocorrection(true)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppButtonStyle.SearchBar.iconColor)
                        .font(.system(size: 18, weight: .regular))
                }
            }
        }
        .padding(.vertical, AppButtonStyle.SearchBar.verticalPadding)
        .padding(.horizontal, AppButtonStyle.SearchBar.horizontalPadding)
        .background(
            RoundedRectangle(cornerRadius: AppButtonStyle.SearchBar.cornerRadius, style: .continuous)
                .fill(AppButtonStyle.SearchBar.background)
                .shadow(color: AppButtonStyle.SearchBar.shadow, radius: AppButtonStyle.SearchBar.shadowRadius)
        )
        .animation(AppButtonStyle.SearchBar.animation, value: text)
    }
}
