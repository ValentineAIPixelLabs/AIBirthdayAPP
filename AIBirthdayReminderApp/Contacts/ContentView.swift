import Contacts
import SwiftUI
import Foundation
import UIKit

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
                    ContactAvatarView(contact: contact, size: 64)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(CardStyle.Title.font)
                            .foregroundColor(CardStyle.Title.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.88)
                        if let birthday = contact.birthday, isValidBirthday(birthday) {
                            Text(birthdayDateDetails(for: birthday))
                                .font(CardStyle.Subtitle.font)
                                .foregroundColor(CardStyle.Subtitle.color)
                                .multilineTextAlignment(.leading)
                        } else {
                            Text("Дата рождения не указана")
                                .font(CardStyle.Subtitle.font)
                                .foregroundColor(CardStyle.Subtitle.color)
                        }
                    }
                    Spacer()
                }
                .padding(.bottom, 5)

                Spacer(minLength: 7)

                Button(action: {
                    contactForCongrats = contact
                }) {
                    Label("Поздравить", systemImage: "sparkles")
                        .font(AppButtonStyle.Congratulate.font)
                        .foregroundColor(AppButtonStyle.Congratulate.textColor)
                        .padding(.horizontal, AppButtonStyle.Congratulate.horizontalPadding)
                        .padding(.vertical, AppButtonStyle.Congratulate.verticalPadding)
                        .background(
                            RoundedRectangle(cornerRadius: AppButtonStyle.Congratulate.cornerRadius, style: .continuous)
                                .fill(AppButtonStyle.Congratulate.backgroundColor)
                                .shadow(color: AppButtonStyle.Congratulate.shadow, radius: AppButtonStyle.Congratulate.shadowRadius, y: 2)
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .padding(.bottom, 4)
            }
            .padding(.horizontal, CardStyle.horizontalPadding)
            .padding(.vertical, CardStyle.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                    .fill(CardStyle.backgroundColor)
                    .shadow(color: CardStyle.shadowColor, radius: CardStyle.shadowRadius, y: CardStyle.shadowYOffset)
                    .overlay(
                        RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                            .stroke(CardStyle.borderColor, lineWidth: 0.7)
                    )
            )
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
    @State private var showAPIKeySheet = false
    @State private var contactToDelete: Contact?
    @State private var showDeleteAlert = false
    @State private var highlightedContactID: UUID?
    @State private var isContactPickerPresented = false
    @State private var showImportOptions: Bool = {
        let hasShown = UserDefaults.standard.bool(forKey: "hasShownImportOptions")
        return !hasShown
    }()
    @State private var path = NavigationPath()
    @State private var showSearchContacts: Bool = false
    @State private var searchText: String = ""
    @State private var contactForCongrats: Contact?

    private var filteredContacts: [Contact] {
        chipFilter.filter(contacts: vm.sortedContacts)
    }

    private var sectionedContacts: [SectionedContacts] {
        BirthdaySectionsViewModel(contacts: filteredContacts).sectionedContacts()
    }

    var body: some View {
        Group {
            let contactsList: [Contact] = chipFilter.filter(contacts: vm.sortedContacts)
            let contactsSections: [SectionedContacts] = BirthdaySectionsViewModel(contacts: contactsList).sectionedContacts()
            NavigationStack(path: $path) {
                ZStack {
                    AppBackground()
                    ContactsMainContent(
                        vm: vm,
                        chipFilter: chipFilter,
                        showAPIKeySheet: $showAPIKeySheet,
                        contactToDelete: $contactToDelete,
                        showDeleteAlert: $showDeleteAlert,
                        highlightedContactID: $highlightedContactID,
                        isContactPickerPresented: $isContactPickerPresented,
                        showImportOptions: $showImportOptions,
                        path: $path,
                        filteredContacts: contactsList,
                        sectionedContacts: contactsSections,
                        handleImportedContact: handleImportedContact,
                        contactForCongrats: $contactForCongrats
                    )
                }
                .navigationBarHidden(true)
                .navigationDestination(for: String.self) { destination in
                    switch destination {
                    case "add":
                        AddContactView(vm: vm)
                    case _ where destination.hasPrefix("congrats_"):
                        if let (uuid, type) = parseCongratsDestination(destination),
                           let idx = vm.contacts.firstIndex(where: { $0.id == uuid }) {
                            ContactCongratsView(
                                contact: $vm.contacts[idx],
                                cardStore: CardHistoryStore(contactId: uuid),
                                congratsHistoryStore: CongratsHistoryStore(contactId: uuid),
                                selectedMode: type
                            )
                        } else {
                            Text("Контакт не найден")
                        }
                    default:
                        Text("Неизвестный маршрут")
                    }
                }
                .sheet(isPresented: $showAPIKeySheet) {
                    APIKeyView()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .alert("Удалить контакт?", isPresented: $showDeleteAlert, presenting: contactToDelete) { contact in
                    Button("Удалить", role: .destructive) {
                        vm.removeContact(contact)
                    }
                    Button("Отмена", role: .cancel) { }
                } message: { contact in
                    Text("Контакт \(contact.name) будет удалён безвозвратно.")
                }
                .confirmationDialog("Импортировать контакты?", isPresented: $showImportOptions, titleVisibility: .visible) {
                    Button("Импортировать все контакты") {
                        vm.importAllContacts()
                        showImportOptions = false
                        UserDefaults.standard.set(true, forKey: "hasShownImportOptions")
                    }
                    Button("Выбрать контакты") {
                        isContactPickerPresented = true
                    }
                    Button("Отмена", role: .cancel) {
                        showImportOptions = false
                        UserDefaults.standard.set(true, forKey: "hasShownImportOptions")
                    }
                }
                .sheet(isPresented: $isContactPickerPresented) {
                    SystemContactPickerView { importedCNContact in
                        handleImportedContact(importedCNContact)
                    }
                }
                .sheet(isPresented: $showSearchContacts) {
                    SearchContactsView(
                        vm: vm,
                        chipFilter: chipFilter,
                        onDismiss: { showSearchContacts = false }
                    )
                }
                .sheet(isPresented: $vm.isEditingContactPresented, onDismiss: {
                    vm.editingContact = nil
                }) {
                    if let editingContact = vm.editingContact {
                        EditContactView(vm: vm, contact: editingContact)
                    }
                }
                .sheet(item: $contactForCongrats) { contact in
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

                var chipList = ["все контакты"]
                chipList.append(contentsOf: allRelations.sorted())

                if hasNoBirthday {
                    chipList.append("без даты рождения")
                }

                chipFilter.allRelations = chipList
            }
        }
        .environmentObject(HolidaysViewModel())
    }

    func handleImportedContact(_ importedCNContact: CNContact) {
        let importedContact = convertCNContactToContact(importedCNContact)
        vm.addContact(importedContact)
        isContactPickerPresented = false
    }
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

// MARK: - ContactsMainContent
private struct ContactsMainContent: View {
    @ObservedObject var vm: ContactsViewModel
    @ObservedObject var chipFilter: ChipRelationFilter
    @Binding var showAPIKeySheet: Bool
    @Binding var contactToDelete: Contact?
    @Binding var showDeleteAlert: Bool
    @Binding var highlightedContactID: UUID?
    @Binding var isContactPickerPresented: Bool
    @Binding var showImportOptions: Bool
    @Binding var path: NavigationPath
    let filteredContacts: [Contact]
    let sectionedContacts: [SectionedContacts]
    let handleImportedContact: (CNContact) -> Void
    @Binding var contactForCongrats: Contact?

    @State private var isSearchActive: Bool = false
    @State private var searchText: String = ""

    private var filteredContactsWithSearch: [Contact] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = vm.sortedContacts.filter {
            query.isEmpty ? true :
                $0.name.lowercased().contains(query) ||
                ($0.surname?.lowercased().contains(query) ?? false) ||
                ($0.nickname?.lowercased().contains(query) ?? false)
        }
        return chipFilter.filter(contacts: base)
    }
    private var sectionedContactsWithSearch: [SectionedContacts] {
        BirthdaySectionsViewModel(contacts: filteredContactsWithSearch).sectionedContacts()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("Контакты")
                    .font(.title2).bold()
                    .foregroundColor(.primary)
                Spacer()
                HStack(spacing: AppHeaderStyle.buttonSpacing) {
                    Button(action: { showAPIKeySheet = true }) {
                        Image(systemName: "key")
                            .frame(width: AppButtonStyle.Circular.diameter, height: AppButtonStyle.Circular.diameter)
                            .background(Circle().fill(AppButtonStyle.Circular.backgroundColor))
                            .shadow(color: AppButtonStyle.Circular.shadow, radius: AppButtonStyle.Circular.shadowRadius)
                            .foregroundColor(AppButtonStyle.Circular.iconColor)
                            .font(.system(size: AppButtonStyle.Circular.iconSize, weight: .semibold))
                    }
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isSearchActive.toggle()
                        }
                    }) {
                        Image(systemName: "magnifyingglass")
                            .frame(width: AppButtonStyle.Circular.diameter, height: AppButtonStyle.Circular.diameter)
                            .background(
                                Circle().fill(isSearchActive ? AppButtonStyle.Circular.backgroundColor : AppButtonStyle.Circular.backgroundColor)
                            )
                            .shadow(color: isSearchActive ? AppButtonStyle.Circular.shadow : AppButtonStyle.Circular.shadow, radius: AppButtonStyle.Circular.shadowRadius)
                            .foregroundColor(isSearchActive ? AppButtonStyle.Circular.iconColor : AppButtonStyle.Circular.iconColor)
                            .font(.system(size: AppButtonStyle.Circular.iconSize, weight: .semibold))
                    }
                    Button(action: { path.append("add") }) {
                        Image(systemName: "plus")
                            .frame(width: AppButtonStyle.Circular.diameter, height: AppButtonStyle.Circular.diameter)
                            .background(Circle().fill(AppButtonStyle.Circular.backgroundColor))
                            .shadow(color: AppButtonStyle.Circular.shadow, radius: AppButtonStyle.Circular.shadowRadius)
                            .foregroundColor(AppButtonStyle.Circular.iconColor)
                            .font(.system(size: AppButtonStyle.Circular.iconSize, weight: .semibold))
                    }
                }
            }
            .frame(height: AppHeaderStyle.minHeight)
            .padding(.top, AppHeaderStyle.topPadding)
            .padding(.horizontal, 20)

            if isSearchActive {
                HStack(spacing: 8) {
                    AppSearchBar(text: $searchText)
                    Button("Отмена") {
                        withAnimation(AppButtonStyle.SearchBar.animation) {
                            isSearchActive = false
                        }
                        searchText = ""
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .foregroundColor(.accentColor)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .animation(AppButtonStyle.SearchBar.animation, value: isSearchActive)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 0)
                .frame(height: 44)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chipFilter.allRelations, id: \.self) { relation in
                        Button(action: { chipFilter.toggle(relation) }) {
                            Text(relation.capitalizedFirstLetter())
                                .font(AppButtonStyle.FilterChip.font)
                                .foregroundColor(
                                    chipFilter.isSelected(relation)
                                    ? AppButtonStyle.FilterChip.selectedText
                                    : AppButtonStyle.FilterChip.unselectedText
                                )
                                .padding(.horizontal, AppButtonStyle.FilterChip.horizontalPadding)
                                .padding(.vertical, AppButtonStyle.FilterChip.verticalPadding)
                                .background(
                                    chipFilter.isSelected(relation)
                                    ? AppButtonStyle.FilterChip.selectedBackground
                                    : AppButtonStyle.FilterChip.unselectedBackground
                                )
                                .clipShape(Capsule())
                                .shadow(
                                    color: chipFilter.isSelected(relation)
                                        ? AppButtonStyle.FilterChip.selectedShadow
                                        : AppButtonStyle.FilterChip.unselectedShadow,
                                    radius: AppButtonStyle.FilterChip.shadowRadius,
                                    y: AppButtonStyle.FilterChip.shadowYOffset
                                )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 3)
                .padding(.top, 0)
            }
            .padding(.top, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(
                        isSearchActive ? sectionedContactsWithSearch : sectionedContacts,
                        id: \.section
                    ) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(BirthdaySectionsViewModel(contacts: []).sectionTitle(section.section))
                                .font(.callout).bold()
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.top, 10)
                            ForEach(section.contacts) { contact in
                                if let index = vm.contacts.firstIndex(where: { $0.id == contact.id }) {
                                    NavigationLink(destination: ContactDetailView(vm: vm, contactId: contact.id)) {
                                        HStack {
                                            ContactCardView(
                                                contact: $vm.contacts[index],
                                                path: $path,
                                                contactForCongrats: $contactForCongrats
                                            )
                                        }
                                        .padding(.horizontal, 20)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .scaleEffect(highlightedContactID == contact.id ? 0.95 : 1.0)
                                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: highlightedContactID)
                                        .contextMenu {
                                            Button("Редактировать") {
                                                if vm.contacts.contains(where: { $0.id == contact.id }) {
                                                    DispatchQueue.main.async {
                                                        vm.editingContact = contact
                                                        vm.isEditingContactPresented = true
                                                    }
                                                }
                                            }
                                            Button(role: .destructive) {
                                                vm.removeContact(contact)
                                            } label: {
                                                Text("Удалить")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isSearchActive)
    }
}

private struct SearchContactsView: View {
    @ObservedObject var vm: ContactsViewModel
    @ObservedObject var chipFilter: ChipRelationFilter
    var onDismiss: () -> Void
    @State private var searchText: String = ""

    private var filteredContacts: [Contact] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = vm.sortedContacts.filter {
            query.isEmpty ? true :
                $0.name.lowercased().contains(query) ||
                ($0.surname?.lowercased().contains(query) ?? false) ||
                ($0.nickname?.lowercased().contains(query) ?? false)
        }
        return chipFilter.filter(contacts: base)
    }

    private var sectionedContacts: [SectionedContacts] {
        BirthdaySectionsViewModel(contacts: filteredContacts).sectionedContacts()
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    AppSearchBar(text: $searchText)
                    Button("Отмена") {
                        onDismiss()
                        searchText = ""
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .foregroundColor(.accentColor)
                }
                .padding(10)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(AppButtonStyle.SearchBar.animation, value: searchText)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(sectionedContacts, id: \.section) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(BirthdaySectionsViewModel(contacts: []).sectionTitle(section.section))
                                    .font(.callout).bold()
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 10)
                                ForEach(section.contacts) { contact in
                                    if let index = vm.contacts.firstIndex(where: { $0.id == contact.id }) {
                                        NavigationLink(destination: ContactDetailView(vm: vm, contactId: contact.id)) {
                                            ContactCardView(
                                                contact: $vm.contacts[index],
                                                path: .constant(NavigationPath()),
                                                contactForCongrats: .constant(nil)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .background(
                AppBackground()
            )
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.33), value: searchText)
    }
}
