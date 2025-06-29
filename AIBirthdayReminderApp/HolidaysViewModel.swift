//
//  HolidaysViewModel.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 25.06.2025.
//

import Foundation
import SwiftUI
import Combine

class HolidaysViewModel: ObservableObject {
    @Published var holidays: [Holiday] = []
    @Published var searchText: String = ""

    private let storageKey = "savedHolidays"

    private func saveHolidays() {
        if let encoded = try? JSONEncoder().encode(holidays) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func loadHolidays() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Holiday].self, from: data) {
            holidays = decoded
        }
    }

    var filteredHolidays: [Holiday] {
        if searchText.isEmpty {
            return holidays
        } else {
            return holidays.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    init() {
        loadHolidays()
    }

    func addHoliday(_ holiday: Holiday) {
        DispatchQueue.main.async {
            let exists = self.holidays.contains { existingHoliday in
                existingHoliday.title == holiday.title &&
                Calendar.current.isDate(existingHoliday.date, inSameDayAs: holiday.date)
            }
            if exists {
                return
            }
            self.holidays = self.holidays + [holiday]
            self.objectWillChange.send()
            self.saveHolidays()
        }
    }

    func updateHoliday(_ holiday: Holiday) {
        DispatchQueue.main.async {
            if let index = self.holidays.firstIndex(where: { $0.id == holiday.id }) {
                self.holidays[index] = holiday
                self.objectWillChange.send()
                self.saveHolidays()
            }
        }
    }

    func hideHoliday(_ holiday: Holiday) {
        DispatchQueue.main.async {
            if let index = self.holidays.firstIndex(where: { $0.id == holiday.id }) {
                self.holidays[index].isHidden = true
                self.objectWillChange.send()
                self.saveHolidays()
            }
        }
    }

    func unhideHoliday(_ holiday: Holiday) {
        DispatchQueue.main.async {
            if let index = self.holidays.firstIndex(where: { $0.id == holiday.id }) {
                self.holidays[index].isHidden = false
                self.objectWillChange.send()
                self.saveHolidays()
            }
        }
    }

    func isHolidayHidden(_ holiday: Holiday) -> Bool {
        if let existingHoliday = holidays.first(where: { $0.id == holiday.id }) {
            return existingHoliday.isHidden
        }
        return false
    }
}
