import SwiftUI
import Contacts
import ContactsUI

@MainActor struct SettingsTabView: View {
    @ObservedObject var vm: ContactsViewModel
    @EnvironmentObject var holidaysVM: HolidaysViewModel
    @EnvironmentObject var lang: LanguageManager
    @State private var showNotificationSettings = false
    @State private var isMultiPickerPresented = false
    @State private var showImportAlert = false
    @State private var importAlertMessage = ""
    @State private var showStore = false
    @State private var showStoreAuthAlert = false
    @State private var showImportOptions = false
    @AppStorage("apple_id") private var appleId: String?
    @State private var showAuthScreen = false
    @State private var authCoverSignedIn = false
    @State private var showSignOutAlert = false
    @State private var suppressAuthAfterSignOut = false

    var body: some View {
        NavigationStack {
            List {

                Section(header: Text("settings.purchases.header")) {
                    Button {
                        if appleId == nil {
                            showStoreAuthAlert = true
                        } else {
                            showStore = true
                        }
                    } label: {
                        Label("store.title", systemImage: "cart")
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
                
                Section(header: Text("settings.account")) {
                    if appleId == nil {
                        Button {
                            // Present the same full-screen SignInView we use on first launch
                            showAuthScreen = true
                        } label: {
                            Label("settings.account.signin",
                                  systemImage: "person.crop.circle.badge.plus")
                                .font(.headline)
                                .padding(.vertical, 8)
                        }
                        .foregroundColor(.primary)
                    } else {
                        Button {
                            // Ask user to confirm sign-out
                            showSignOutAlert = true
                        } label: {
                            Label("settings.account.signout.apple",
                                  systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.headline)
                                .padding(.vertical, 8)
                        }
                        .foregroundColor(.primary)
                    }
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
            .alert(
                "store.auth.required.title",
                isPresented: $showStoreAuthAlert
            ) {
                Button("common.cancel", role: .cancel) { }
                Button("common.signin") {
                    showAuthScreen = true
                }
            } message: {
                Text("store.auth.required.message")
            }
            .sheet(isPresented: $showStore) {
                // Present StoreView modally; it already manages its own navigation
                StoreView()
            }
            .fullScreenCover(isPresented: $showAuthScreen) {
                SignInView(isSignedIn: Binding(
                    get: { authCoverSignedIn },
                    set: { newValue in
                        // Dismiss the auth sheet when SignInView reports success OR user chose to defer
                        if newValue {
                            showAuthScreen = false
                        }
                        // Mirror the value for completeness
                        authCoverSignedIn = newValue
                        // Sync appleId in case of real sign-in
                        appleId = AppleSignInManager.shared.currentAppleId
                    }
                ))
            }
            .onChange(of: appleId) { newValue in
                authCoverSignedIn = (newValue != nil)
                if newValue == nil {
                    // Do not auto-present auth after explicit sign-out
                    showAuthScreen = false
                    suppressAuthAfterSignOut = false
                }
            }
            .onChange(of: authCoverSignedIn) { newValue in
                if newValue { showAuthScreen = false }
            }
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
                .receive(on: DispatchQueue.main)) { _ in
                if showAuthScreen {
                    let deferred = UserDefaults.standard.bool(forKey: "auth.deferredSignIn")
                    if deferred {
                        authCoverSignedIn = true
                        showAuthScreen = false
                    }
                }
            }
            .alert(
                "signout.confirm.title",
                isPresented: $showSignOutAlert
            ) {
                Button("common.no", role: .cancel) { }
                Button("signout.confirm.ok", role: .destructive) {
                    Task { @MainActor in
                        await AppleSignInManager.shared.signOut()
                        appleId = nil
                        authCoverSignedIn = false
                        showAuthScreen = false
                        suppressAuthAfterSignOut = true
                    }
                }
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
