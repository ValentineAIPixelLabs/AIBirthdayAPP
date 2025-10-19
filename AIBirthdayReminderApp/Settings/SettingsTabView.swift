import SwiftUI
@preconcurrency import Contacts
import ContactsUI

@MainActor struct SettingsTabView: View {
    @ObservedObject var vm: ContactsViewModel
    @EnvironmentObject var holidaysVM: HolidaysViewModel
    @EnvironmentObject var lang: LanguageManager
    @State private var showNotificationSettings = false
    @State private var isMultiPickerPresented = false
    @State private var showImportAlert = false
    @State private var importAlertMessage = ""
    @State private var showSubscription = false
    @State private var showImportOptions = false
    @State private var showSupport = false

    var body: some View {
        NavigationStack {
            List {

                Section(header: Text("settings.purchases.header")) {
                    Button {
                        showSubscription = true
                    } label: {
                        Label(LocalizedStringKey("settings.subscription"), systemImage: "star.circle")
                            .font(.headline)
                            .padding(.vertical, 8)
                    }
                    .foregroundColor(.primary)

                    Button {
                        showSupport = true
                    } label: {
                        Label(LocalizedStringKey("settings.support"), systemImage: "questionmark.circle")
                            .font(.headline)
                            .padding(.vertical, 8)
                    }
                    .foregroundColor(.primary)
                }

                Section {
                    Button {
                        showNotificationSettings = true
                    } label: {
                        Label("notifications.configure", systemImage: "bell.badge")
                            .font(.headline)
                            .padding(.vertical, 8)
                    }
                    .foregroundColor(.primary)
                } header: {
                    Text("notifications.title")
                }

                Section(header: Text("settings.language")) {
                    Picker("settings.language", selection: $lang.current) {
                        ForEach(AppLanguage.allCases) { l in
                            Text(l.displayName).tag(l)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("theme.title")) {
                    Picker("theme.picker", selection: $vm.colorScheme) {
                        ForEach(ContactsViewModel.AppColorScheme.allCases) { scheme in
                            Text(scheme.labelKey).tag(scheme)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("import.contacts.title")) {

                    Button {
                        showImportOptions = true
                    } label: {
                        Label("import.contacts.button", systemImage: "tray.and.arrow.down")
                            .font(.headline)
                            .padding(.vertical, 8)
                    }
                    .foregroundColor(.primary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle(Text("settings.title"))
            .id(lang.current)
            .background(AppBackground().ignoresSafeArea())
            .sheet(isPresented: $showNotificationSettings) {
                NavigationStack {
                    NotificationSettingsView(settings: $vm.globalNotificationSettings)
                }
            }
            .sheet(isPresented: $isMultiPickerPresented) {
                SystemContactsPickerViewMultiple { selectedContacts in
                    DispatchQueue.main.async {
                        // Разделяем на новых и дублирующих (гарантированно на главном потоке)
                        let importedContacts = selectedContacts.map { convertCNContactToContact($0) }
                        var added = 0
                        var dups = 0
                        for contact in importedContacts {
                            if !vm.contacts.contains(where: { $0.name == contact.name && $0.surname == contact.surname && $0.birthday == contact.birthday }) {
                                vm.addContact(contact)
                                added += 1
                            } else {
                                dups += 1
                            }
                        }
                        if importedContacts.count == 1 && added == 0 {
                            importAlertMessage = String(localized: "import.result.single.already", locale: lang.locale)
                        } else if added == 0 {
                            importAlertMessage = String(localized: "import.result.none.already", locale: lang.locale)
                        } else if dups > 0 {
                            importAlertMessage = String.localizedStringWithFormat(
                                String(localized: "import.result.mixed", locale: lang.locale),
                                added, dups
                            )
                        } else {
                            importAlertMessage = String.localizedStringWithFormat(
                                String(localized: "import.result.count", locale: lang.locale),
                                added
                            )
                        }
                        showImportAlert = true
                    }
                }
            }
            .confirmationDialog("import.contacts.title", isPresented: $showImportOptions, titleVisibility: .visible) {
                Button("import.contacts.pick.manually") {
                    isMultiPickerPresented = true
                }
                Button("import.contacts.import.all") {
                    importAllContacts()
                }
                Button("common.cancel", role: .cancel) { }
            }
            .alert(isPresented: $showImportAlert) {
                Alert(title: Text("import.contacts.title"), message: Text(importAlertMessage), dismissButton: .default(Text("common.ok")))
            }
            .fullScreenCover(isPresented: $showSubscription) {
                PaywallView()
            }
            .sheet(isPresented: $showSupport) {
                SupportView()
            }
        }
    }

    func importAllContacts() {
        CNContactStore().requestAccess(for: .contacts) { granted, error in
            guard granted, error == nil else { return }
            // Create the store inside the completion to avoid capturing a non-Sendable value in a @Sendable closure
            let store = CNContactStore()
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
                    var added = 0
                    for contact in importedContacts {
                        if !vm.contacts.contains(where: { $0.name == contact.name && $0.surname == contact.surname && $0.birthday == contact.birthday }) {
                            vm.addContact(contact)
                            added += 1
                        }
                    }
                    if added == 0 {
                        importAlertMessage = String(localized: "import.result.none.already", locale: lang.locale)
                    } else {
                        importAlertMessage = String.localizedStringWithFormat(
                            String(localized: "import.result.count", locale: lang.locale),
                            added
                        )
                    }
                    showImportAlert = true
                }
            }
        }
    }

    nonisolated func convertCNContactToContact(_ cnContact: CNContact) -> Contact {
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

struct SystemContactsPickerViewMultiple: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    var onSelectContacts: ([CNContact]) -> Void

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
        let parent: SystemContactsPickerViewMultiple
        init(_ parent: SystemContactsPickerViewMultiple) { self.parent = parent }

        // iOS supports selecting multiple contacts; this delegate will be called with an array if user selects several
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            DispatchQueue.main.async {
                self.parent.onSelectContacts(contacts)
                self.parent.presentationMode.wrappedValue.dismiss()
            }
        }

        // Fallback: single contact selected
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            DispatchQueue.main.async {
                self.parent.onSelectContacts([contact])
                self.parent.presentationMode.wrappedValue.dismiss()
            }
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            DispatchQueue.main.async {
                self.parent.presentationMode.wrappedValue.dismiss()
            }
        }
    }
}



struct SupportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: StoreKitManager
    @State private var isRequestingRefund = false

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("settings.support")) {
                    Text("support.body")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Section(footer: Text("support.refund.footer")) {
                    Button {
                        Task { await requestRefund() }
                    } label: {
                        HStack {
                            if isRequestingRefund {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            }
                            Text("support.refund.request")
                        }
                    }
                    .disabled(isRequestingRefund)
                }
            }
            .navigationTitle("support.nav.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }

    private func requestRefund() async {
        guard !isRequestingRefund else { return }
        isRequestingRefund = true
        defer { isRequestingRefund = false }
        await store.requestRefund()
    }
}
