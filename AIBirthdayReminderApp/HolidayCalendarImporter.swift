//
//  HolidayCalendarImporter.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 25.06.2025.
//

import Foundation
import EventKit

class HolidayCalendarImporter {
    let eventStore = EKEventStore()
    
    /// Запросить доступ к календарю пользователя
    func requestAccess(completion: @escaping (Bool) -> Void) {
        eventStore.requestFullAccessToEvents { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    /// Получить события, которые похожи на праздники
    func fetchHolidayEvents(completion: @escaping ([Holiday]) -> Void) {
        var holidays: [Holiday] = []
        
        // Фильтруем календари по названию (регистронезависимо)
        let calendars = eventStore.calendars(for: .event).filter {
            let lowerName = $0.title.lowercased()
            return lowerName.contains("holiday") || lowerName.contains("праздник") || lowerName.contains("праздники")
        }
        
        let calendar = Calendar.current
        let startDate = calendar.date(from: calendar.dateComponents([.year], from: Date()))!
        let endDate = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: startDate)!
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let events = eventStore.events(matching: predicate)
        
        for event in events {
            if event.isAllDay {
                holidays.append(
                    Holiday(
                        title: event.title,
                        date: event.startDate,
                        type: .official,
                        icon: nil,
                        isRegional: false,
                        isCustom: false,
                        relatedProfession: nil
                    )
                )
            }
        }
        completion(holidays)
    }
}
