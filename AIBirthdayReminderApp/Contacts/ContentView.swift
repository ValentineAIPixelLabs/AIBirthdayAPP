
import Contacts
import SwiftUI
import Foundation
import UIKit

// MARK: - Localization helpers for this file
private func appLanguageCode() -> String {
    // 1) User override (if you add a manual switch later)
    if let code = UserDefaults.standard.string(forKey: "app.language.code") {
        return code
    }
    // 2) Auto-pick: RU for any system language starting with "ru", else EN
    let sys = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
    return sys.hasPrefix("ru") ? "ru" : "en"
}

private func appLocale() -> Locale {
    Locale(identifier: appLanguageCode())
}

private func appBundle() -> Bundle {
    let code = appLanguageCode()
    if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
       let bundle = Bundle(path: path) {
        return bundle
    }
    return .main
}

extension View {
    func glassCircleStyle() -> some View {
        self
            .background(
                Circle()
                    .fill(.thinMaterial)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1.2)
                    )
            )
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.13), radius: 10, x: 0, y: 4)
    }
}

extension Birthday {
    func toDate() -> Date? {
        if let day = self.day, let month = self.month {
            var components = DateComponents()
            components.day = day
            components.month = month
            components.year = self.year ?? Calendar.current.component(.year, from: Date())
            return Calendar.current.date(from: components)
        } else {
            return nil
        }
    }
}

struct ContactCardView: View {
    @Binding var contact: Contact
    @Binding var path: NavigationPath
    @Binding var contactForCongrats: Contact?

    var title: String { birthdayTitle(for: contact) }
    var details: String {
        return birthdayDateDetails(for: contact.birthday)
    }
    var subtitleText: String { subtitle(for: contact) }

    var body: some View {
        CardPresetView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 16) {
                    // Централизованный аватар из AvatarKit
                    let avatarSource: AvatarSource = {
                        if let data = contact.imageData, let img = UIImage(data: data) {
                            return .image(img)
                        } else if let e = contact.emoji, !e.isEmpty {
                            return .emoji(e)
                        } else {
                            let initial = contact.name.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "?"
                            return .monogram(initial)
                        }
                    }()
                    AppAvatarView(source: avatarSource, shape: .circle, size: .listLarge)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(CardStyle.Title.font)
                            .foregroundColor(CardStyle.Title.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.88)
                        if let birthday = contact.birthday, isValidBirthday(birthday) {
                            // Разбиваем строку вида "Через N дней · 29 августа, Пятница" и формируем две строки:
                            // 1) "Через N дней · 29 августа"
                            // 2) "Пятница"
                            let full = birthdayDateDetails(for: birthday)
                            let parts = full.components(separatedBy: " · ")
                            let left = parts.first ?? full
                            let right = parts.count > 1 ? parts[1] : ""
                            let dateParts = right.components(separatedBy: ", ")
                            let dateText = dateParts.first ?? right
                            let weekday = dateParts.count > 1 ? dateParts[1] : ""
                            let firstLineCombined = "\(left) · \(dateText)"
                            let twoLineText = weekday.isEmpty ? firstLineCombined : "\(firstLineCombined)\n\(weekday)"
                            Text(twoLineText)
                                .font(CardStyle.Subtitle.font)
                                .foregroundColor(CardStyle.Subtitle.color)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(String(localized: "contact.birthday.missing", bundle: appBundle(), locale: appLocale()))
                                .font(CardStyle.Subtitle.font)
                                .foregroundColor(CardStyle.Subtitle.color)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
                .padding(.bottom, 0)

                CongratulateButton {
                    contactForCongrats = contact
                }
                .font(CardStyle.ButtonTitle.font)
                .frame(maxWidth: .infinity)
                .padding(.top, CardStyle.CTA.topPadding)
                .padding(.bottom, CardStyle.CTA.bottomPadding)
            }
            .padding(.horizontal, CardStyle.horizontalPadding)
            .padding(.top, CardStyle.verticalPadding)
            .padding(.bottom, 0)
            .cardBackground()
        }
    }
}

struct ContentView: View {
    // Парсер для destination вида "congrats_<UUID>_<type>"
    func parseCongratsDestination(_ destination: String) -> (UUID, String)? {
        let prefix = "congrats_"
        guard destination.hasPrefix(prefix) else { return nil }
        let stripped = destination.dropFirst(prefix.count)
        guard let underscoreIndex = stripped.firstIndex(of: "_") else { return nil }
        let idString = String(stripped.prefix(upTo: underscoreIndex))
        let type = String(stripped.suffix(from: stripped.index(after: underscoreIndex)))
        guard let uuid = UUID(uuidString: idString) else { return nil }
        return (uuid, type)
    }

    @StateObject var vm = ContactsViewModel()
    @StateObject var chipFilter = ChipRelationFilter(relations: [])
    @State private var contactToDelete: Contact?
    @State private var showDeleteAlert = false
    @State private var highlightedContactID: UUID?
    @State private var isContactPickerPresented = false
    @State private var path = NavigationPath()
    @State private var searchText: String = ""
    @State private var contactForCongrats: Contact?
    @State private var isSelectionMode: Bool = false
    @State private var selectedContacts: Set<UUID> = []
    @State private var showBulkDeleteAlert: Bool = false
    @State private var pendingDeleteIDs: Set<UUID> = []

    private var filteredContacts: [Contact] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Special chip raw titles (internal values kept in chipFilter)
        let allKey = "Все контакты"
        let noBirthdayKey = "Без даты рождения"

        // Determine if any non-special relation chips are selected
        let selectedNonSpecialExists: Bool = chipFilter.allRelations.contains { rel in
            guard chipFilter.isSelected(rel) else { return false }
            return rel != allKey && rel != noBirthdayKey
        }

        // Base list: if there are any relation chips selected, use relation filtering; otherwise, take all
        var base: [Contact]
        if selectedNonSpecialExists {
            base = chipFilter.filter(contacts: vm.sortedContacts)
        } else {
            base = vm.sortedContacts
        }

        // Narrow down to contacts without birthday if the special chip is selected
        if chipFilter.isSelected(noBirthdayKey) {
            base = base.filter { contact in
                contact.birthday == nil || !isValidBirthday(contact.birthday)
            }
        }

        // Apply search if needed
        if query.isEmpty { return base }
        return base.filter { contact in
            let nameMatch = contact.name.lowercased().contains(query)
            let surnameMatch = (contact.surname?.lowercased().contains(query) ?? false)
            let nicknameMatch = (contact.nickname?.lowercased().contains(query) ?? false)
            let relationMatch = (contact.relationType?.lowercased().contains(query) ?? false)
            return nameMatch || surnameMatch || nicknameMatch || relationMatch
        }
    }

    private var sectionedContacts: [SectionedContacts] {
        BirthdaySectionsViewModel(contacts: filteredContacts).sectionedContacts()
    }

    var body: some View { root }

    // MARK: - Extracted root to help the compiler
    @ViewBuilder
    private var root: some View {
        Group {
            navigationContent
        }
    }

    // MARK: - Navigation content extracted
    @ViewBuilder
    private var navigationContent: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppBackground()
                mainContent()
            }
            .toolbar { contactsToolbar() }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { destination in
                destinationView(for: destination)
            }
        }
        .alert(
            Text(String(localized: "contact.delete.title", bundle: appBundle(), locale: appLocale())),
            isPresented: $showDeleteAlert,
            presenting: contactToDelete
        ) { contact in
            Button(role: .destructive) {
                vm.removeContact(contact)
            } label: {
                Text(String(localized: "common.delete", bundle: appBundle(), locale: appLocale()))
            }
            Button(role: .cancel) { } label: {
                Text(String(localized: "common.cancel", bundle: appBundle(), locale: appLocale()))
            }
        } message: { contact in
            Text(
                String.localizedStringWithFormat(
                    String(localized: "contact.delete.message", bundle: appBundle(), locale: appLocale()),
                    contact.name
                )
            )
        }
        .alert(isPresented: $showBulkDeleteAlert) {
            bulkDeleteAlert()
        }
        .sheet(isPresented: $isContactPickerPresented) {
            SystemContactsPickerViewMultiple { selected in
                DispatchQueue.main.async {
                    selected.forEach { importedCNContact in
                        handleImportedContact(importedCNContact)
                    }
                }
            }
        }
        // Редактирование контакта
        .sheet(isPresented: $vm.isEditingContactPresented, onDismiss: {
            vm.editingContact = nil
        }) {
            editSheetContent()
        }
        // Экшн-лист поздравлений
        .sheet(item: $contactForCongrats) { contact in
            congratsSheet(for: contact)
        }
        .onAppear {
            var allRelations = Set<String>()
            var hasNoBirthday = false

            for contact in vm.sortedContacts {
                if let relation = contact.relationType?.trimmingCharacters(in: .whitespacesAndNewlines), !relation.isEmpty {
                    allRelations.insert(relation)
                }
                if contact.birthday == nil || !isValidBirthday(contact.birthday) {
                    hasNoBirthday = true
                }
            }

            var chipList = ["Все контакты"]
            chipList.append(contentsOf: allRelations.sorted())

            if hasNoBirthday {
                chipList.append("Без даты рождения")
            }

            chipFilter.allRelations = chipList

            // Ensure default selection is "Все контакты" (to match Holidays behavior)
            if !chipFilter.isSelected("Все контакты") {
                chipFilter.toggle("Все контакты")
            }
        }
    }

    // MARK: - Extracted destination view
    @ViewBuilder
    private func destinationView(for destination: String) -> some View {
        switch destination {
        case "add":
            AddContactView(vm: vm)
        case _ where destination.hasPrefix("congrats_"):
            if let (uuid, type) = parseCongratsDestination(destination),
               let idx = vm.contacts.firstIndex(where: { $0.id == uuid }) {
                ContactCongratsView(
                    contact: $vm.contacts[idx],
                    selectedMode: type
                )
            } else {
                Text("contacts.not_found")
            }
        case _ where destination.hasPrefix("contact_"):
            if let uuid = UUID(uuidString: String(destination.dropFirst("contact_".count))),
               let _ = vm.contacts.firstIndex(where: { $0.id == uuid }) {
                ContactDetailView(vm: vm, contactId: uuid)
            } else {
                Text("contacts.not_found")
            }
        default:
            Text("route.unknown")
        }
    }

    // MARK: - Extracted sheets
    @ViewBuilder
    private func editSheetContent() -> some View {
        if let editingContact = vm.editingContact {
            EditContactView(vm: vm, contact: editingContact)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func congratsSheet(for contact: Contact) -> some View {
        CongratulationActionSheet(
            onGenerateText: {
                contactForCongrats = nil
                path.append("congrats_\(contact.id.uuidString)_text")
            },
            onGenerateCard: {
                contactForCongrats = nil
                path.append("congrats_\(contact.id.uuidString)_card")
            }
        )
    }

    // MARK: - Extracted main content to help the compiler
    @ViewBuilder
    private func mainContent() -> some View {
        ContactsMainContent(
            vm: vm,
            chipFilter: chipFilter,
            contactToDelete: $contactToDelete,
            showDeleteAlert: $showDeleteAlert,
            highlightedContactID: $highlightedContactID,
            isContactPickerPresented: $isContactPickerPresented,
            path: $path,
            filteredContacts: filteredContacts,
            sectionedContacts: sectionedContacts,
            handleImportedContact: handleImportedContact,
            contactForCongrats: $contactForCongrats,
            searchText: $searchText,
            isSelectionMode: $isSelectionMode,
            selectedContacts: $selectedContacts
        )
    }

    // MARK: - Extracted toolbar to help the compiler
    @ToolbarContentBuilder
    private func contactsToolbar() -> some ToolbarContent {
        // Leading: Edit menu / Done
        ToolbarItem(placement: .topBarLeading) {
            if isSelectionMode {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isSelectionMode = false
                        selectedContacts.removeAll()
                    }
                } label: {
                    Text("common.done")
                }
                .accessibilityLabel(Text("common.done"))
            } else {
                Menu {
                    Button("contacts.toolbar.select") {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            isSelectionMode = true
                            selectedContacts.removeAll()
                        }
                    }
                    Button("contacts.toolbar.select.all") {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            isSelectionMode = true
                            selectedContacts = Set(filteredContacts.map { $0.id })
                        }
                    }
                } label: {
                    Text("contacts.toolbar.edit")
                }
                .accessibilityLabel(Text("contacts.toolbar.edit"))
            }
        }

        // Trailing: Add or Delete
        ToolbarItem(placement: .topBarTrailing) {
            if isSelectionMode {
                Button {
                    pendingDeleteIDs = selectedContacts
                    showBulkDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
                .tint(.red)
                .disabled(selectedContacts.isEmpty)
                .accessibilityLabel(Text("contacts.toolbar.delete.selected"))
            } else {
                Menu {
                    importOptionsDialogButtons()
                } label: {
                    Image(systemName: "plus")
                }
                .tint(.blue)
                .accessibilityLabel(Text("contacts.add"))
            }
        }
    }

    // MARK: - Extracted builders to reduce body complexity

    @ViewBuilder
    private func importOptionsDialogButtons() -> some View {
        Button {
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            let rootVC = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            guard let presenter = rootVC else { return }
            ContactImportService.shared.presentContactPicker(from: presenter) { imported in
                // User cancelled the picker — nothing to import
                guard !imported.isEmpty else { return }
                DispatchQueue.main.async {
                    let (toAdd, dups) = ContactImportService.splitDuplicates(existing: vm.contacts, candidates: imported)
                    toAdd.forEach { vm.addContact($0) }

                    // Сообщения пользователю (локализация по выбранному языку приложения)
                    let b = appBundle()
                    let l = appLocale()
                    let message: String
                    if imported.count == 1 && toAdd.isEmpty {
                        message = String(localized: "import.result.single.already", bundle: b, locale: l)
                    } else if toAdd.isEmpty {
                        message = String(localized: "import.result.none.already", bundle: b, locale: l)
                    } else if !dups.isEmpty {
                        message = String.localizedStringWithFormat(
                            String(localized: "import.result.mixed", bundle: b, locale: l),
                            toAdd.count, dups.count
                        )
                    } else {
                        message = String.localizedStringWithFormat(
                            String(localized: "import.result.count", bundle: b, locale: l),
                            toAdd.count
                        )
                    }
                    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: String(localized: "common.ok", bundle: b, locale: l), style: .default))
                    presenter.present(alert, animated: true)
                    UserDefaults.standard.set(true, forKey: "hasShownImportOptions")
                }
            }
        } label: {
            HStack {
                Text("import.contacts.pick.from_list")
                Spacer()
                Image(systemName: "person.crop.circle.badge.plus")
            }
        }
        Button {
            guard
                let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let presenter = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
            else { return }

            let store = CNContactStore()
            store.requestAccess(for: .contacts) { granted, _ in
                guard granted else { return }
                ContactImportService.importAllContacts { imported in
                    DispatchQueue.main.async {
                        let (toAdd, dups) = ContactImportService.splitDuplicates(existing: vm.contacts, candidates: imported)
                        toAdd.forEach { vm.addContact($0) }

                        // Сообщения пользователю (локализация по выбранному языку приложения)
                        let b = appBundle()
                        let l = appLocale()
                        let message: String
                        if imported.count == 1 && toAdd.isEmpty {
                            message = String(localized: "import.result.single.already", bundle: b, locale: l)
                        } else if toAdd.isEmpty {
                            message = String(localized: "import.result.none.already", bundle: b, locale: l)
                        } else if !dups.isEmpty {
                            message = String.localizedStringWithFormat(
                                String(localized: "import.result.mixed", bundle: b, locale: l),
                                toAdd.count, dups.count
                            )
                        } else {
                            message = String.localizedStringWithFormat(
                                String(localized: "import.result.count", bundle: b, locale: l),
                                toAdd.count
                            )
                        }
                        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: String(localized: "common.ok", bundle: b, locale: l), style: .default))
                        presenter.present(alert, animated: true)
                        UserDefaults.standard.set(true, forKey: "hasShownImportOptions")
                    }
                }
            }
        } label: {
            HStack {
                Text("import.contacts.import.all")
                Spacer()
                Image(systemName: "tray.and.arrow.down")
            }
        }
        Button {
            path.append("add")
            UserDefaults.standard.set(true, forKey: "hasShownImportOptions")
        } label: {
            HStack {
                Text("contacts.add.manually")
                Spacer()
                Image(systemName: "pencil")
            }
        }
        // Cancel button removed as per instructions
    }

    private func bulkDeleteAlert() -> Alert {
        let selected = vm.contacts.filter { pendingDeleteIDs.contains($0.id) }
        let titleText: Text = {
            let key = selected.count == 1 ? "contact.delete.title" : "contacts.delete.title"
            return Text(String(localized: .init(key), bundle: appBundle(), locale: appLocale()))
        }()

        let messageText: Text = {
            if selected.count == 1 {
                let name = selected.first?.name ?? ""
                return Text(
                    String.localizedStringWithFormat(
                        String(localized: "contact.delete.confirm.one", bundle: appBundle(), locale: appLocale()),
                        name
                    )
                )
            } else {
                return Text(
                    String.localizedStringWithFormat(
                        String(localized: "contacts.delete.confirm.many", bundle: appBundle(), locale: appLocale()),
                        selected.count
                    )
                )
            }
        }()

        return Alert(
            title: titleText,
            message: messageText,
            primaryButton: .destructive(
                Text(String(localized: "common.delete", bundle: appBundle(), locale: appLocale()))
            ) {
                vm.deleteContacts(with: pendingDeleteIDs)
                selectedContacts.removeAll()
                pendingDeleteIDs.removeAll()
                withAnimation(.easeInOut(duration: 0.16)) { isSelectionMode = false }
            },
            secondaryButton: .cancel(
                Text(String(localized: "common.cancel", bundle: appBundle(), locale: appLocale()))
            ) {
                pendingDeleteIDs.removeAll()
            }
        )
    }

    func handleImportedContact(_ importedCNContact: CNContact) {
        let importedContact = convertCNContactToContact(importedCNContact)
        vm.addContact(importedContact)
        isContactPickerPresented = false
    }

    // (importAllSystemContacts removed)
}

extension UIImage {
    func resizedForCropper(maxSide: CGFloat = 1200) -> UIImage {
        let maxDimension = max(size.width, size.height)
        guard maxDimension > maxSide else { return self }
        let scale = maxSide / maxDimension
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
}

func convertCNContactToContact(_ cnContact: CNContact) -> Contact {
    var birthdayValue: Birthday? = nil
    if let bday = cnContact.birthday {
        if (bday.day ?? 0) > 0 && (bday.month ?? 0) > 0 {
            birthdayValue = Birthday(
                day: bday.day ?? 0,
                month: bday.month ?? 0,
                year: bday.year
            )
        } else {
            birthdayValue = nil
        }
    } else {
        birthdayValue = nil
    }

    return Contact(
        id: UUID(),
        name: cnContact.givenName,
        surname: cnContact.familyName,
        nickname: cnContact.nickname.isEmpty ? nil : cnContact.nickname,
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

// MARK: - ContactsMainContent
private struct ContactsMainContent: View {
    @ObservedObject var vm: ContactsViewModel
    @ObservedObject var chipFilter: ChipRelationFilter
    @Binding var contactToDelete: Contact?
    @Binding var showDeleteAlert: Bool
    @Binding var highlightedContactID: UUID?
    @Binding var isContactPickerPresented: Bool
    @Binding var path: NavigationPath
    let filteredContacts: [Contact]
    let sectionedContacts: [SectionedContacts]
    let handleImportedContact: (CNContact) -> Void
    @Binding var contactForCongrats: Contact?
    @Binding var searchText: String
    @Binding var isSelectionMode: Bool
    @Binding var selectedContacts: Set<UUID>

    // MARK: - Chip localization helpers (display-only)
    private func localizedRelationTitle(_ value: String) -> String {
        let b = appBundle()
        switch value {
        case Contact.unspecified:
            return b.localizedString(forKey: "common.unspecified", value: value, table: "Localizable")
        case "Брат":          return b.localizedString(forKey: "relation.brother", value: value, table: "Localizable")
        case "Сестра":        return b.localizedString(forKey: "relation.sister", value: value, table: "Localizable")
        case "Отец":          return b.localizedString(forKey: "relation.father", value: value, table: "Localizable")
        case "Мать":          return b.localizedString(forKey: "relation.mother", value: value, table: "Localizable")
        case "Бабушка":       return b.localizedString(forKey: "relation.grandmother", value: value, table: "Localizable")
        case "Дедушка":       return b.localizedString(forKey: "relation.grandfather", value: value, table: "Localizable")
        case "Сын":           return b.localizedString(forKey: "relation.son", value: value, table: "Localizable")
        case "Дочь":          return b.localizedString(forKey: "relation.daughter", value: value, table: "Localizable")
        case "Коллега":       return b.localizedString(forKey: "relation.colleague", value: value, table: "Localizable")
        case "Руководитель":  return b.localizedString(forKey: "relation.manager", value: value, table: "Localizable")
        case "Начальник":     return b.localizedString(forKey: "relation.boss", value: value, table: "Localizable")
        case "Товарищ":       return b.localizedString(forKey: "relation.companion", value: value, table: "Localizable")
        case "Друг":          return b.localizedString(forKey: "relation.friend", value: value, table: "Localizable")
        case "Лучший друг":   return b.localizedString(forKey: "relation.best_friend", value: value, table: "Localizable")
        case "Супруг":        return b.localizedString(forKey: "relation.spouse_male", value: value, table: "Localizable")
        case "Супруга":       return b.localizedString(forKey: "relation.spouse_female", value: value, table: "Localizable")
        case "Партнер":       return b.localizedString(forKey: "relation.partner", value: value, table: "Localizable")
        case "Девушка":       return b.localizedString(forKey: "relation.girlfriend", value: value, table: "Localizable")
        case "Парень":        return b.localizedString(forKey: "relation.boyfriend", value: value, table: "Localizable")
        case "Клиент":        return b.localizedString(forKey: "relation.client", value: value, table: "Localizable")
        default:               return value
        }
    }

    private func localizedChipTitle(_ text: String) -> String {
        // Localize custom Russian chip labels for "all contacts" and "no birthday"
        if text == "Все контакты" { return String(localized: "contacts.filter.all", bundle: appBundle(), locale: appLocale()) }
        if text == "Без даты рождения" { return String(localized: "contacts.filter.no_birthday", bundle: appBundle(), locale: appLocale()) }
        // Otherwise, try to localize a relation value
        return localizedRelationTitle(text)
    }

    // MARK: - Section header localization
    private func localizedSectionHeader(from baseName: String) -> String {
        switch baseName {
        case "Без даты рождения":
            return String(localized: "contacts.section.no_birthday", bundle: appBundle(), locale: appLocale())
        case "Сегодня":
            return String(localized: "date.today", bundle: appBundle(), locale: appLocale())
        case "Завтра":
            return String(localized: "date.tomorrow", bundle: appBundle(), locale: appLocale())
        default:
            // Try to parse Russian month name with optional year, then format with selected locale
            let ruMonths = ["январь","февраль","март","апрель","май","июнь","июль","август","сентябрь","октябрь","ноябрь","декабрь"]
            let parts = baseName.split(separator: " ")
            guard let first = parts.first else { return baseName }
            let monthLower = first.lowercased()
            if let idx = ruMonths.firstIndex(of: monthLower) {
                var comps = DateComponents()
                comps.day = 1
                comps.month = idx + 1
                let df = DateFormatter()
                df.locale = appLocale()
                if parts.count >= 2, let year = Int(parts[1]) {
                    comps.year = year
                    df.setLocalizedDateFormatFromTemplate("LLLL y")
                } else {
                    comps.year = 2020 // leap-safe year for month-only formatting
                    df.setLocalizedDateFormatFromTemplate("LLLL")
                }
                if let date = Calendar.current.date(from: comps) {
                    return df.string(from: date).capitalized(with: appLocale())
                }
            }
            return baseName
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    filterChips
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }
                .listRowBackground(Color.clear)
                ForEach(sectionedContacts, id: \.section) { section in
                    Section {
                        ForEach(section.contacts) { contact in
                            if let index = vm.contacts.firstIndex(where: { $0.id == contact.id }) {
                                HStack(spacing: 0) {
                                    if isSelectionMode {
                                        Button(action: {
                                            if selectedContacts.contains(contact.id) {
                                                selectedContacts.remove(contact.id)
                                            } else {
                                                selectedContacts.insert(contact.id)
                                            }
                                        }) {
                                            Image(systemName: selectedContacts.contains(contact.id) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedContacts.contains(contact.id) ? .accentColor : .secondary)
                                                .font(.system(size: 28))
                                                .padding(.trailing, 8)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    // Keep NavigationLink for details to preserve deep-linking
                                    ContactCardView(
                                        contact: $vm.contacts[index],
                                        path: $path,
                                        contactForCongrats: $contactForCongrats
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        path.append("contact_\(contact.id.uuidString)")
                                    }
                                    .onLongPressGesture(minimumDuration: 0.38) {
                                        handleLongPress(on: contact)
                                    }
                                    .scaleEffect(isSelectionMode && selectedContacts.contains(contact.id) ? 0.97 : 1.0)
                                    .animation(.easeInOut(duration: 0.17), value: isSelectionMode)
                                }
                                .padding(.horizontal, CardStyle.listHorizontalPadding)
                                .padding(.bottom, CardStyle.cardSpacing)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                    } header: {
                        let baseName = BirthdaySectionsViewModel(contacts: []).sectionTitle(section.section)
                        Text(localizedSectionHeader(from: baseName))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, CardStyle.listHorizontalPadding)
                            .padding(.top, 8)
                            .padding(.bottom, 6)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .appSearchable(text: $searchText)
            .environment(\.defaultMinListHeaderHeight, 0)
            .animation(.easeInOut(duration: 0.25), value: isSelectionMode)
            .overlay {
                if sectionedContacts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .foregroundColor(.secondary)
                        Text("contacts.empty")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
    
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppButtonStyle.FilterChip.spacing) {
                ForEach(chipFilter.allRelations, id: \.self) { relation in
                    Button(action: {
                        let gen = UIImpactFeedbackGenerator(style: .soft)
                        gen.impactOccurred()
                        chipFilter.toggle(relation)
                    }) {
                        Text(localizedChipTitle(relation).capitalizedFirstLetter())
                            .font(AppButtonStyle.FilterChip.font)
                            .foregroundColor(
                                chipFilter.isSelected(relation)
                                ? AppButtonStyle.FilterChip.selectedText
                                : AppButtonStyle.FilterChip.unselectedText
                            )
                            .padding(.horizontal, AppButtonStyle.FilterChip.horizontalPadding)
                            .padding(.vertical, AppButtonStyle.FilterChip.verticalPadding)
                            .background {
                                if chipFilter.isSelected(relation) {
                                    Capsule().fill(AppButtonStyle.primaryFill())
                                        .overlay(
                                            Capsule().fill(AppButtonStyle.primaryGloss())
                                        )
                                } else {
                                    Capsule().fill(AppButtonStyle.FilterChip.unselectedMaterial)
                                }
                            }
                            .overlay(
                                Capsule()
                                    .stroke(AppButtonStyle.primaryStroke(), lineWidth: 0.8)
                                    .opacity(chipFilter.isSelected(relation) ? 1 : 0)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                    .opacity(chipFilter.isSelected(relation) ? 0 : 1)
                            )
                            .shadow(
                                color: chipFilter.isSelected(relation)
                                ? AppButtonStyle.FilterChip.selectedShadow
                                : AppButtonStyle.FilterChip.unselectedShadow,
                                radius: AppButtonStyle.FilterChip.shadowRadius,
                                y: AppButtonStyle.FilterChip.shadowYOffset
                            )
                    }
                    .buttonStyle(FilterChipButtonStyle.Press())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, AppHeaderStyle.filterChipsBottomPadding)
            .padding(.top, 4)
        }
    }

    private func handleLongPress(on contact: Contact) {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
        if !isSelectionMode {
            isSelectionMode = true
        }
        selectedContacts.insert(contact.id)
    }
    
}
    extension ContactsViewModel {
        func deleteContacts(with ids: Set<UUID>) {
            let toDelete = contacts.filter { ids.contains($0.id) }
            for contact in toDelete {
                removeContact(contact)
            }
        }
    }



