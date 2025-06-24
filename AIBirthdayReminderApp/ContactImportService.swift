//
//  ContactImportService.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 22.06.2025.
//

import Foundation
import Contacts
import ContactsUI
import SwiftUI

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
                viewController.present(picker, animated: true)
            }
        }
    }

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
        let importedContacts = contacts.map { self.convertCNContactToContact($0) }
        completion?(importedContacts)
        completion = nil
    }

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        let importedContact = convertCNContactToContact(contact)
        completion?([importedContact])
        completion = nil
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        completion?([])
        completion = nil
    }

    private func convertCNContactToContact(_ cnContact: CNContact) -> Contact {
        var birthdayValue: Birthday? = nil
        if let bday = cnContact.birthday {
            if let day = bday.day, let month = bday.month, day > 0, month > 0, let year = bday.year {
                birthdayValue = Birthday(day: day, month: month, year: year)
            } else {
                birthdayValue = nil
            }
        }

        return Contact(
            id: UUID(),
            name: cnContact.givenName,
            surname: cnContact.familyName,
            nickname: cnContact.nickname.isEmpty ? nil : cnContact.nickname,
            relationType: nil,
            gender: nil,
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
        var contacts: [Contact] = []
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try store.enumerateContacts(with: request) { (cnContact, _) in
                    let contact = ContactImportService.shared.convertCNContactToContact(cnContact)
                    contacts.append(contact)
                }
                DispatchQueue.main.async {
                    completion(contacts)
                }
            } catch {
                print("Failed to fetch contacts:", error)
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
}
