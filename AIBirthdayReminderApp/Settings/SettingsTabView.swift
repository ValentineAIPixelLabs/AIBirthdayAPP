import SwiftUI
import Contacts
import ContactsUI

struct SettingsTabView: View {
    @ObservedObject var vm: ContactsViewModel
    @EnvironmentObject var holidaysVM: HolidaysViewModel
    @State private var showNotificationSettings = false
    @State private var isContactPickerPresented = false
    @State private var showImportAlert = false
    @State private var importAlertMessage = ""

    var body: some View {
        
        NavigationStack {
            
            List {
                
                Section {
                    Button {
                        showNotificationSettings = true
                    } label: {
                        Label("Настроить напоминания", systemImage: "bell.badge")
                            .font(.headline)
                            .padding(.vertical, 8)
                    }
                    .foregroundColor(.primary)
                } header: {
                    Text("Уведомления")
                }
                Section(header: Text("Тема оформления")) {
                    Picker("Тема", selection: $vm.colorScheme) {
                        ForEach(ContactsViewModel.AppColorScheme.allCases) { scheme in
                            Text(scheme.label).tag(scheme)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section(header: Text("Импорт контактов")) {
                    Button {
                        isContactPickerPresented = true
                    } label: {
                        Label("Импортировать контакт", systemImage: "person.crop.circle.badge.plus")
                            .font(.headline)
                            .padding(.vertical, 8)
                    }
                    .foregroundColor(.primary)

                    Button {
                        importAllContacts()
                    } label: {
                        Label("Импортировать все контакты", systemImage: "tray.and.arrow.down")
                            .font(.headline)
                            .padding(.vertical, 8)
                    }
                    .foregroundColor(.primary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Настройки")
            .background(AppBackground())
            .sheet(isPresented: $showNotificationSettings) {
                NavigationStack {
                    NotificationSettingsView(settings: $vm.globalNotificationSettings)
                }
            }
            .sheet(isPresented: $isContactPickerPresented) {
                SystemContactPickerView { selectedContact in
                    let contact = convertCNContactToContact(selectedContact)
                    if !vm.contacts.contains(where: { $0.name == contact.name && $0.surname == contact.surname && $0.birthday == contact.birthday }) {
                        vm.addContact(contact)
                        importAlertMessage = "Контакт \"\(contact.name)\" успешно добавлен."
                    } else {
                        importAlertMessage = "Контакт \"\(contact.name)\" уже существует."
                    }
                    showImportAlert = true
                }
            }
            .alert(isPresented: $showImportAlert) {
                Alert(title: Text("Импорт контактов"), message: Text(importAlertMessage), dismissButton: .default(Text("Ок")))
            }
        }
    }

    func importAllContacts() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            guard granted, error == nil else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactBirthdayKey, CNContactImageDataKey, CNContactNicknameKey, CNContactJobTitleKey] as [CNKeyDescriptor]
                let request = CNContactFetchRequest(keysToFetch: keys)
                var importedContacts: [Contact] = []
                do {
                    try store.enumerateContacts(with: request) { cnContact, _ in
                        let contact = convertCNContactToContact(cnContact)
                        importedContacts.append(contact)
                    }
                } catch {
                    print("Ошибка импорта контактов: \(error)")
                }
                DispatchQueue.main.async {
                    for contact in importedContacts {
                        if !vm.contacts.contains(where: { $0.name == contact.name && $0.surname == contact.surname && $0.birthday == contact.birthday }) {
                            vm.addContact(contact)
                        }
                    }
                    importAlertMessage = "Все контакты успешно импортированы."
                    showImportAlert = true
                }
            }
        }
    }

    func convertCNContactToContact(_ cnContact: CNContact) -> Contact {
        var birthdayValue: Birthday? = nil
        if let bday = cnContact.birthday,
           let day = bday.day, day > 0,
           let month = bday.month, month > 0 {
            birthdayValue = Birthday(
                day: day,
                month: month,
                year: bday.year
            )
        } else {
            birthdayValue = nil
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
}

struct SystemContactPickerView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    var onSelectContact: (CNContact) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {
        // no update needed
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: SystemContactPickerView

        init(_ parent: SystemContactPickerView) {
            self.parent = parent
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onSelectContact(contact)
            parent.presentationMode.wrappedValue.dismiss()
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
