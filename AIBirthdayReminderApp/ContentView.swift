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
    let contact: Contact

    var title: String { birthdayTitle(for: contact) }
    var details: String {
        return birthdayDateDetails(for: contact.birthday)
    }
    var subtitleText: String { subtitle(for: contact) }

    var body: some View {
        CardPresetView {
            HStack(alignment: .center, spacing: 16) {
                ContactAvatarView(contact: contact, size: 64)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                    Text(details)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .opacity(0.96)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
            }
        }
    }
}




// --- Основной ContentView ---
struct ContentView: View {

    @StateObject var vm = ContactsViewModel()
    @StateObject var chipFilter = ChipRelationFilter(
        relations: ["Брат", "Сестра", "Отец", "Мать", "Бабушка", "Дедушка", "Сын", "Дочь", "Коллега", "Руководитель", "Начальник", "Товарищ", "Друг", "Лучший друг", "Супруг", "Супруга", "Партнер", "Девушка", "Парень", "Клиент"]
    )
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
    @State private var searchText = ""
    @State private var showSearchBar = false

    private var gradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.blue.opacity(0.18),
                Color.purple.opacity(0.16),
                Color.teal.opacity(0.14)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

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
    Group {
        NavigationStack(path: $path) {
            ZStack {
                gradient.ignoresSafeArea()
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
                    searchText: $searchText,
                    showSearchBar: $showSearchBar,
                    filteredContacts: filteredContacts,
                    sectionedContacts: sectionedContacts,
                    handleImportedContact: handleImportedContact
                )
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { destination in
                if destination == "add" {
                    AddContactView(vm: vm)
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
    @Binding var searchText: String
    @Binding var showSearchBar: Bool
    let filteredContacts: [Contact]
    let sectionedContacts: [SectionedContacts]
    let handleImportedContact: (CNContact) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("Контакты")
                    .font(.title2).bold()
                    .foregroundColor(.primary)
                Spacer()
                Button(action: { showAPIKeySheet = true }) {
                    Image(systemName: "key")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle().fill(Color.white.opacity(0.3))
                                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1)
                        )
                }
                .buttonStyle(ActionButtonStyle())
                Spacer(minLength: 8)
                Button(action: { showSearchBar = true }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle().fill(Color.white.opacity(0.3))
                                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1)
                        )
                }
                .buttonStyle(ActionButtonStyle())
                Spacer(minLength: 8)
                Button(action: { path.append("add") }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle().fill(Color.white.opacity(0.3))
                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1)
                        )
                }
                .buttonStyle(ActionButtonStyle())
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chipFilter.allRelations, id: \.self) { relation in
                        Button(action: { chipFilter.toggle(relation) }) {
                            Text(relation)
                                .font(.system(size: 15, weight: .medium))
                                .textCase(.lowercase)
                                .foregroundColor(
                                    chipFilter.isSelected(relation) ? .white : .accentColor
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    chipFilter.isSelected(relation)
                                    ? Color.accentColor
                                    : Color.white.opacity(0.26)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: .black.opacity(chipFilter.isSelected(relation) ? 0.10 : 0.06), radius: 2, y: 1)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 3)
                .padding(.top, 0)
            }

            if showSearchBar {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Поиск", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    Button("Отмена") {
                        showSearchBar = false
                        searchText = ""
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .foregroundColor(.accentColor)
                }
                .padding(10)
                .background(
                    Color.white.opacity(0.7)
                        .blur(radius: 0.3)
                        .shadow(color: .black.opacity(0.09), radius: 10, y: 2)
                )
                .cornerRadius(12)
                .padding(.horizontal, 18)
                .padding(.top, 2)
                .padding(.bottom, 6)
            }

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
                                NavigationLink(destination: ContactDetailView(vm: vm, contactId: contact.id)) {
                                    ContactCardView(contact: contact)
                                        .scaleEffect(highlightedContactID == contact.id ? 0.95 : 1.0)
                                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: highlightedContactID)
                                }
                                .simultaneousGesture(
                                    LongPressGesture(minimumDuration: 0.55)
                                        .onEnded { _ in
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            highlightedContactID = contact.id
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) {
                                                contactToDelete = contact
                                                showDeleteAlert = true
                                                highlightedContactID = nil
                                            }
                                        }
                                )
                            }
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
        }
    }
}
