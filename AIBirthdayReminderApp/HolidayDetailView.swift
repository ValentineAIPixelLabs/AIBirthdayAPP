//
//  HolidayDetailView.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 25.06.2025.
//

import SwiftUI
//import Holiday

struct HolidayDetailView: View {
    let holiday: Holiday

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(holiday.icon ?? "🎈")
                        .font(.system(size: 80))
                    Text(holiday.title)
                        .font(.largeTitle)
                        .bold()
                    Text(holiday.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(holiday.type.title)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
            }
        }
        .navigationTitle("Праздник")
        .navigationBarTitleDisplayMode(.inline)
    }
}
