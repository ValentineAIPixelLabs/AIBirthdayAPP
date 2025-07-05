//
//  CardHistoryStore.swift
//  AIBirthdayReminderApp
//
//  Created by Валентин Станков on 04.07.2025.
//


import Foundation

final class CardHistoryStore: ObservableObject {
    private let contactId: UUID
    @Published var savedCards: [URL] = []

    private let directoryName = "Cards"

    init(contactId: UUID) {
        self.contactId = contactId
        loadSavedCards()
    }

    func loadSavedCards() {
        do {
            let fileManager = FileManager.default
            let documentsURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let cardsDirectory = documentsURL.appendingPathComponent(directoryName)
            if fileManager.fileExists(atPath: cardsDirectory.path) {
                let contents = try fileManager.contentsOfDirectory(at: cardsDirectory, includingPropertiesForKeys: nil)
                let pngFiles = contents
                    .filter {
                        $0.pathExtension.lowercased() == "png"
                        && fileManager.fileExists(atPath: $0.path)
                        && $0.lastPathComponent.hasPrefix(contactId.uuidString)
                    }
                    .sorted {
                        let date1 = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                        let date2 = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                        return date1 > date2
                    }
                DispatchQueue.main.async {
                    self.savedCards = pngFiles
                }
            } else {
                savedCards = []
            }
        } catch {
            print("Failed to load saved cards: \(error)")
            savedCards = []
        }
    }

    func deleteCard(at index: Int) {
        guard savedCards.indices.contains(index) else { return }
        let url = savedCards[index]
        do {
            try FileManager.default.removeItem(at: url)
            savedCards.remove(at: index)
        } catch {
            print("Failed to delete card: \(error)")
        }
    }
}
