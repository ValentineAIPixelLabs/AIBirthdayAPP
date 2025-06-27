//
//  AIBirthdayReminderAppApp.swift
//  AIBirthdayReminderApp
//
//  Created by Валентин Станков on 11.06.2025.
//

import SwiftUI
import UIKit

@main
struct AIBirthdayReminderAppApp: App {
    init() {
        NotificationManager.shared.requestAuthorization()
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = .clear
        appearance.shadowImage = nil
        appearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    var body: some Scene {
        WindowGroup {
            AppTabView()
                .environmentObject(HolidaysViewModel())
        }
    }
}
