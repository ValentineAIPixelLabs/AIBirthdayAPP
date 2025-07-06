//
//  AppBackground.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 06.07.2025.
//

import SwiftUI

/// Фирменный бэкграунд приложения с градиентом.
/// Используется на главных экранах для создания фирменного стиля.
/// Пример вызова: `AppBackground()` — вставляется в ZStack как первый слой.
struct AppBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.blue.opacity(0.18),
                Color.purple.opacity(0.16),
                Color.teal.opacity(0.14)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
