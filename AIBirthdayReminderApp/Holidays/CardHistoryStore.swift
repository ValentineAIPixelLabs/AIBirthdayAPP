//
//  CardHistoryStore.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 22.07.2025.
//



import Foundation
import UIKit

class CardHistoryStore: ObservableObject {
    // Генерация уникального ключа для хранения истории по каждому празднику
    static func historyKey(for holidayID: String) -> String {
        "holidayCardHistory_\(holidayID)"
    }

    // Загрузить историю (массив открыток-изображений) для праздника
    static func loadHistory(for holidayID: String) -> [UIImage] {
        guard let dataArray = UserDefaults.standard.array(forKey: historyKey(for: holidayID)) as? [Data] else {
            return []
        }
        return dataArray.compactMap { UIImage(data: $0) }
    }

    // Сохранить историю (массив открыток-изображений) для праздника
    static func saveHistory(_ images: [UIImage], for holidayID: String) {
        let dataArray = images.compactMap { $0.pngData() }
        UserDefaults.standard.set(dataArray, forKey: historyKey(for: holidayID))
    }

    // Добавить новую открытку в историю для праздника
    static func addCard(_ image: UIImage, for holidayID: String) {
        var images = loadHistory(for: holidayID)
        images.insert(image, at: 0) // Новые открытки — в начало списка
        saveHistory(images, for: holidayID)
    }

    // Удалить открытку из истории для праздника
    static func deleteCard(_ image: UIImage, for holidayID: String) {
        var images = loadHistory(for: holidayID)
        if let index = images.firstIndex(of: image) {
            images.remove(at: index)
            saveHistory(images, for: holidayID)
        }
    }
}

// MARK: - Текстовые поздравления для праздников

extension CardHistoryStore {
    /// Ключ для хранения истории текстовых поздравлений по празднику
    static func congratsHistoryKey(for holidayID: String) -> String {
        "holidayCongratsHistory_\(holidayID)"
    }

    /// Загрузить историю текстовых поздравлений
    static func loadCongratsHistory(for holidayID: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: congratsHistoryKey(for: holidayID)) ?? []
    }

    /// Сохранить историю текстовых поздравлений
    static func saveCongratsHistory(_ congrats: [String], for holidayID: String) {
        UserDefaults.standard.set(congrats, forKey: congratsHistoryKey(for: holidayID))
    }

    /// Добавить новое поздравление в историю
    static func addCongrats(_ text: String, for holidayID: String) {
        var current = loadCongratsHistory(for: holidayID)
        current.insert(text, at: 0)
        saveCongratsHistory(current, for: holidayID)
    }

    /// Удалить поздравление из истории
    static func deleteCongrats(_ text: String, for holidayID: String) {
        var current = loadCongratsHistory(for: holidayID)
        if let idx = current.firstIndex(of: text) {
            current.remove(at: idx)
            saveCongratsHistory(current, for: holidayID)
        }
    }
}
