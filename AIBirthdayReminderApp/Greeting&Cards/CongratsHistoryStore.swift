import Foundation

final class CongratsHistoryStore: ObservableObject {   
    private let contactId: UUID
    private let fileManager = FileManager.default

    private var fileURL: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("CongratsHistory_\(contactId.uuidString).json")
    }

    init(contactId: UUID) {
        self.contactId = contactId
    }

    func loadHistory() -> [CongratsHistoryItem] {
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let history = try? JSONDecoder().decode([CongratsHistoryItem].self, from: data) else {
            return []
        }
        return history
    }

    func saveHistory(_ history: [CongratsHistoryItem]) {
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: fileURL)
        }
    }
}
