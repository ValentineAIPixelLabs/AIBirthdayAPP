import Contacts
import SwiftUI
import Foundation
import UIKit
//import AppHeaderStyle
//import AppSearchBar

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
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Через \(daysUntilNextBirthday(from: birthday)) \(daysSuffix(for: daysUntilNextBirthday(from: birthday))) · \(dateStringRu(nextBirthdayDate(from: birthday)))")
                                    .font(CardStyle.Subtitle.font)
                                    .foregroundColor(CardStyle.Subtitle.color)
                                let weekday = {
                                    let formatter = DateFormatter()
                                    formatter.locale = Locale(identifier: "ru_RU")
                                    formatter.dateFormat = "EEEE"
                                    let raw = formatter.string(from: nextBirthdayDate(from: birthday))
                                    return raw.prefix(1).uppercased() + raw.dropFirst()
                                }()
                                Text(weekday)
                                    .font(CardStyle.Subtitle.font)
                                    .foregroundColor(CardStyle.Subtitle.color)
                            }
                        } else {
                            Text("Дата рождения не указана")
                                .font(CardStyle.Subtitle.font)
                                .foregroundColor(CardStyle.Subtitle.color)
                        }
                    }
                    Spacer()
                }
                .padding(.bottom, 12)

                Spacer(minLength: 8)

                Button(action: {
                    path.append("congrats_\(contact.id.uuidString)")
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




// --- Основной ContentView ---
struct ContentView: View {

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
    // Удаляем старое состояние поиска
    @State private var showSearchContacts: Bool = false
    @State private var searchText: String = ""


    private var filteredContacts: [Contact] {
        // Фильтрация только по chipFilter, поиск теперь в отдельном SearchContactsView
        return chipFilter.filter(contacts: vm.sortedContacts)
    }

    private var sectionedContacts: [SectionedContacts] {
        BirthdaySectionsViewModel(contacts: filteredContacts).sectionedContacts()
    }

var body: some View {
    Group {
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
                    filteredContacts: filteredContacts,
                    sectionedContacts: sectionedContacts,
                    handleImportedContact: handleImportedContact
                )
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { destination in
                if destination == "add" {
                    AddContactView(vm: vm)
                } else if destination.hasPrefix("congrats_") {
                    // Извлекаем контакт по id из строки
                    let idString = String(destination.dropFirst("congrats_".count))
                    if let uuid = UUID(uuidString: idString),
                       let idx = vm.contacts.firstIndex(where: { $0.id == uuid }) {
                        ContactCongratsView(
                            contact: $vm.contacts[idx],
                            cardStore: CardHistoryStore(contactId: uuid),
                            congratsHistoryStore: CongratsHistoryStore(contactId: uuid)
                        )
                    } else {
                        Text("Контакт не найден")
                    }
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
            // Новый .sheet для поиска
            .sheet(isPresented: $showSearchContacts) {
                SearchContactsView(
                    vm: vm,
                    chipFilter: chipFilter,
                    onDismiss: { showSearchContacts = false }
                )
            }
            // Новый .sheet для редактирования контакта
            .sheet(isPresented: $vm.isEditingContactPresented, onDismiss: {
                vm.editingContact = nil
            }) {
                if let editingContact = vm.editingContact {
                    EditContactView(vm: vm, contact: editingContact)
                }
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

    // Новый стиль поиска, как в HolidayDetailView
    @State private var isSearchActive: Bool = false
    @State private var searchText: String = ""

    // Фильтрация контактов по поиску и чипам
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
            // Верхняя панель с кнопками
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
                    // Кнопка поиска (лупа) с новым стилем
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

            // Строка поиска с плавной анимацией, как в HolidayDetailView
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

            // Чипы фильтра под строкой поиска, с паддингом .horizontal 16, сверху около 12
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

            // Список контактов под фильтрами
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
                                            ContactCardView(contact: $vm.contacts[index], path: $path)
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

// MARK: - SearchContactsView
private struct SearchContactsView: View {
    @ObservedObject var vm: ContactsViewModel
    @ObservedObject var chipFilter: ChipRelationFilter
    var onDismiss: () -> Void
    @State private var searchText: String = ""

    // Фильтрация по тексту и чипам
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
                                            ContactCardView(contact: $vm.contacts[index], path: .constant(NavigationPath()))
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
