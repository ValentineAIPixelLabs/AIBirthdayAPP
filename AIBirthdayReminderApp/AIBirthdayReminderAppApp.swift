//
//  AIBirthdayReminderAppApp.swift
//  AIBirthdayReminderApp
//
//  Created by Валентин Станков on 11.06.2025.
//

import SwiftUI

@main
struct AIBirthdayReminderAppApp: App {
    init() {
        NotificationManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            AppTabView()
        }
    }
}
