import Foundation


class ChipRelationFilter: ObservableObject {
    @Published var selected: String
    @Published var allRelations: [String]
    let specialAll = "все контакты"
    let specialNoBirthday = "без даты рождения"

    init(relations: [String]) {
        var base = [specialAll]
        if !relations.isEmpty {
            base += relations.map { $0.lowercased() }
        }
        if relations.contains(where: { $0.isEmpty }) == false {
            base.append(specialNoBirthday)
        }
        self.allRelations = base
        self.selected = specialAll
    }

    func toggle(_ relation: String) {
        selected = relation
    }

    func isSelected(_ relation: String) -> Bool {
        selected == relation
    }

    // Фильтрация по выбранному чипу
    func filter(contacts: [Contact]) -> [Contact] {
        switch selected {
        case specialAll:
            return contacts
        case specialNoBirthday:
            return contacts.filter { $0.birthday == nil || !isValidBirthday($0.birthday) }
        default:
            return contacts.filter {
                $0.relationType?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased() == selected.lowercased()
            }
        }
    }

    private func isValidBirthday(_ birthday: Birthday?) -> Bool {
        guard let birthday = birthday else { return false }
        return birthday.day != 0 || birthday.month != 0
    }
}
