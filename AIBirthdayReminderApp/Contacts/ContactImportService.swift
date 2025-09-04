import Foundation
import Contacts
import ContactsUI
import SwiftUI
import UIKit

final class ContactImportService: NSObject, CNContactPickerDelegate, ObservableObject {
    static let shared = ContactImportService()

    private var completion: (([Contact]) -> Void)?

    func presentContactPicker(from viewController: UIViewController, completion: @escaping ([Contact]) -> Void) {
        self.completion = completion

        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            DispatchQueue.main.async {
                guard granted, error == nil else {
                    completion([])
                    return
                }
                let picker = CNContactPickerViewController()
                picker.delegate = self
                picker.predicateForSelectionOfProperty = nil
                picker.predicateForEnablingContact = nil
                viewController._topMostViewController().present(picker, animated: true)
            }
        }
    }

    /// Показывает меню выбора: импортировать все контакты или открыть выбор контактов
    func presentImportOptions(from viewController: UIViewController, completion: @escaping ([Contact]) -> Void) {
        self.completion = completion
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            DispatchQueue.main.async {
                guard granted, error == nil else { completion([]); return }
                let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                alert.addAction(UIAlertAction(
                    title: String(localized: "import.contacts.pick.manually"),
                    style: .default
                ) { [weak self] _ in
                    guard let self = self else { return }
                    let picker = CNContactPickerViewController()
                    picker.delegate = self
                    picker.predicateForSelectionOfProperty = nil
                    picker.predicateForEnablingContact = nil
                    DispatchQueue.main.async {
                        viewController._topMostViewController().present(picker, animated: true)
                    }
                })

                alert.addAction(UIAlertAction(
                    title: String(localized: "import.contacts.import.all"),
                    style: .default
                ) { _ in
                    Self.importAllContacts { contacts in
                        completion(contacts)
                    }
                })

                alert.addAction(UIAlertAction(
                    title: String(localized: "common.cancel"),
                    style: .cancel
                ))
                if let pop = alert.popoverPresentationController {
                    pop.sourceView = viewController.view
                    pop.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.maxY - 1, width: 1, height: 1)
                    pop.permittedArrowDirections = []
                }
                viewController.presentSafeAlert(alert)
            }
        }
    }

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
        let importedContacts = contacts.map { self.convertCNContactToContact($0) }
        DispatchQueue.main.async { [weak self] in
            self?.completion?(importedContacts)
            self?.completion = nil
        }
    }

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        let importedContact = convertCNContactToContact(contact)
        DispatchQueue.main.async { [weak self] in
            self?.completion?([importedContact])
            self?.completion = nil
        }
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        DispatchQueue.main.async { [weak self] in
            self?.completion?([])
            self?.completion = nil
        }
    }

    private func convertCNContactToContact(_ cnContact: CNContact) -> Contact {
        var birthdayValue: Birthday? = nil
        if let bday = cnContact.birthday {
            if let day = bday.day, let month = bday.month, day > 0, month > 0 {
                birthdayValue = Birthday(day: day, month: month, year: bday.year)
            }
        }

        let first = cnContact.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last  = cnContact.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nick  = cnContact.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeFirst = first.isEmpty ? (nick.isEmpty ? "Без имени" : nick) : first
        let safeLast  = last // фамилия может быть пустой — допускаем это

        return Contact(
            id: UUID(),
            name: safeFirst,
            surname: safeLast,
            nickname: nick.isEmpty ? nil : nick,
            relationType: Contact.unspecified,
            gender: Contact.unspecified,
            birthday: birthdayValue,
            notificationSettings: .default,
            imageData: cnContact.imageData,
            emoji: nil,
            occupation: cnContact.jobTitle.isEmpty ? nil : cnContact.jobTitle,
            hobbies: nil,
            leisure: nil,
            additionalInfo: nil
        )
    }

    static func importAllContacts(completion: @escaping ([Contact]) -> Void) {
        let store = CNContactStore()
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)

        func proceed() {
            var contacts: [Contact] = []
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try store.enumerateContacts(with: request) { (cnContact, _) in
                        let contact = ContactImportService.shared.convertCNContactToContact(cnContact)
                        contacts.append(contact)
                    }
                    DispatchQueue.main.async { completion(contacts) }
                } catch {
                    print("Failed to fetch contacts:", error)
                    DispatchQueue.main.async { completion([]) }
                }
            }
        }

        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            proceed()
        case .notDetermined:
            store.requestAccess(for: .contacts) { granted, _ in
                if granted { proceed() } else { DispatchQueue.main.async { completion([]) } }
            }
        default:
            DispatchQueue.main.async { completion([]) }
        }
    }

    /// Ключ дедупликации контакта: имя|фамилия|день-месяц-год(или -1)
    static func dedupKey(for c: Contact) -> String {
        let name = c.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sn = (c.surname ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let bd: String
        if let b = c.birthday {
            let d = b.day ?? -1
            let m = b.month ?? -1
            let y = b.year ?? -1
            bd = "\(d)-\(m)-\(y)"
        } else {
            bd = "-"
        }
        return "\(name)|\(sn)|\(bd)"
    }

    /// Разделить кандидатов на новых и дубликаты, сравнивая с текущим списком
    static func splitDuplicates(existing: [Contact], candidates: [Contact]) -> (new: [Contact], duplicates: [Contact]) {
        let existingKeys = Set(existing.map { dedupKey(for: $0) })
        var newContacts: [Contact] = []
        var duplicates: [Contact] = []
        for c in candidates {
            if existingKeys.contains(dedupKey(for: c)) {
                duplicates.append(c)
            } else {
                newContacts.append(c)
            }
        }
        return (newContacts, duplicates)
    }

    /// Импорт всех контактов с дедупликацией по (имя+фамилия+ДР)
    static func importAllContactsDeduplicated(existing: [Contact], completion: @escaping ([Contact]) -> Void) {
        importAllContacts { imported in
            let existingKeys = Set(existing.map { dedupKey(for: $0) })
            let filtered = imported.filter { !existingKeys.contains(dedupKey(for: $0)) }
            completion(filtered)
        }
    }
}

// MARK: - Safe alert presentation when CNContactPicker is on screen
private extension UIViewController {
    func presentSafeAlert(_ alert: UIAlertController,
                          animated: Bool = true,
                          completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let presenter = self._topMostViewController()
            if presenter is CNContactPickerViewController {
                presenter.dismiss(animated: true) { [weak self] in
                    guard let self else { return }
                    self._topMostViewController().present(alert, animated: animated, completion: completion)
                }
            } else {
                presenter.present(alert, animated: animated, completion: completion)
            }
        }
    }

    func _topMostViewController() -> UIViewController {
        var vc: UIViewController = self
        while let presented = vc.presentedViewController {
            vc = presented
        }
        return vc
    }
}
