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
    @Published var deletedHolidays: [Holiday] = []
    
    private let storageKey = "savedHolidays"
    private let deletedStorageKey = "deletedHolidays"

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

    private func loadDeletedHolidays() {
        if let data = UserDefaults.standard.data(forKey: deletedStorageKey),
           let decoded = try? JSONDecoder().decode([Holiday].self, from: data) {
            deletedHolidays = decoded
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
        loadDeletedHolidays()
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
            let deletedExists = self.deletedHolidays.contains { deletedHoliday in
                deletedHoliday.title == holiday.title &&
                Calendar.current.isDate(deletedHoliday.date, inSameDayAs: holiday.date)
            }
            if deletedExists {
                return
            }
            self.holidays = self.holidays + [holiday]
            self.objectWillChange.send()
            self.saveHolidays()
        }
    }

    func deleteHoliday(_ holiday: Holiday) {
        DispatchQueue.main.async {
            print("deleteHoliday called for: \(holiday.title)")
            if let index = self.holidays.firstIndex(where: { $0.id == holiday.id }) {
                var newHolidays = self.holidays
                newHolidays.remove(at: index)
                self.deletedHolidays = self.deletedHolidays + [holiday]
                self.holidays = newHolidays
                self.objectWillChange.send()
                self.saveHolidays()
                self.saveDeletedHolidays()
            }
        }
    }

    func saveDeletedHolidays() {
        if let encoded = try? JSONEncoder().encode(deletedHolidays) {
            UserDefaults.standard.set(encoded, forKey: deletedStorageKey)
        }
    }

    func restoreHoliday(_ holiday: Holiday) {
        DispatchQueue.main.async {
            print("restoreHoliday called for: \(holiday.title)")
            if let index = self.deletedHolidays.firstIndex(where: { $0.id == holiday.id }) {
                var newDeleted = self.deletedHolidays
                newDeleted.remove(at: index)
                self.deletedHolidays = newDeleted
                self.holidays = (self.holidays + [holiday]).sorted { $0.date < $1.date }
                self.objectWillChange.send()
                self.saveDeletedHolidays()
                self.saveHolidays()
            }
        }
    }

    func removeHoliday(id: UUID) {
        holidays.removeAll { $0.id == id }
        saveHolidays()
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
    
    // TODO: Интеграция с системным календарём
    // TODO: Автоматическое добавление региональных и профессиональных праздников

    func removeDeletedHoliday(_ holiday: Holiday) {
        DispatchQueue.main.async {
            print("removeDeletedHoliday called for: \(holiday.title)")
            self.deletedHolidays = self.deletedHolidays.filter { $0.id != holiday.id }
            self.objectWillChange.send()
            self.saveDeletedHolidays()
        }
    }
}
