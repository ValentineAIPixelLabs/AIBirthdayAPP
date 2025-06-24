import SwiftUI
import Contacts

struct AddContactView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var vm: ContactsViewModel

    @State private var name: String = ""
    @State private var surname: String = ""
    @State private var nickname: String = ""
    @State private var relation: String = "Друг"
    @State private var gender: String = "Мужской"
    @State private var birthday: Birthday? = nil

    @State private var occupation: String = ""
    @State private var hobbies: String = ""
    @State private var leisure: String = ""
    @State private var additionalInfo: String = ""

    @State private var showSaveHint = false
    @State private var isImporting = false
    @State private var isContactPickerPresented = false
    @State private var showImportAlert = false
    @State private var importAlertMessage = ""

    private let relations = ["Брат", "Сестра", "Отец", "Мать", "Бабушка", "Дедушка", "Сын", "Дочь", "Коллега", "Руководитель", "Начальник", "Товарищ", "Друг", "Лучший друг", "Супруг", "Супруга", "Партнер", "Девушка", "Парень", "Клиент"]
    private let genders = ["Мужской", "Женский"]

    private var isSaveEnabled: Bool {
        !name.isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.18), Color.purple.opacity(0.16), Color.teal.opacity(0.14)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            NavigationView {
                Form {
                    Section(header: Text("Основная информация")) {
                        TextField("Имя", text: $name)
                        TextField("Фамилия (необязательно)", text: $surname)
                        TextField("Прозвище (необязательно)", text: $nickname)
                        Picker("Отношения", selection: $relation) {
                            ForEach(relations, id: \.self) { rel in
                                Text(rel)
                            }
                        }
                        Picker("Пол", selection: $gender) {
                            ForEach(genders, id: \.self) { g in
                                Text(g)
                            }
                        }
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.07), radius: 8, y: 2)
                    )
                    Section(header: Text("Дата рождения")) {
                        BirthdayField(birthday: $birthday)
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.07), radius: 8, y: 2)
                    )
                    Section(header: Text("Род деятельности / Профессия")) {
                        ZStack(alignment: .topLeading) {
                            if occupation.isEmpty {
                                Text("Кем работает / На кого учится, например, инженер, студент, преподаватель, дизайнер…")
                                    .foregroundColor(Color(UIColor.placeholderText))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 8)
                            }
                            TextEditor(text: $occupation)
                                .frame(minHeight: 64)
                                .font(.body)
                                .padding(4)
                        }
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.07), radius: 8, y: 2)
                    )
                    Section(header: Text("Увлечения / Хобби")) {
                        ZStack(alignment: .topLeading) {
                            if hobbies.isEmpty {
                                Text("Например, спорт (футбол, плавание), рыбалка, вязание, фотография, путешествия, коллекционирование…")
                                    .foregroundColor(Color(UIColor.placeholderText))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 8)
                            }
                            TextEditor(text: $hobbies)
                                .frame(minHeight: 64)
                                .font(.body)
                                .padding(4)
                        }
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.07), radius: 8, y: 2)
                    )
                    Section(header: Text("Как любит проводить свободное время")) {
                        ZStack(alignment: .topLeading) {
                            if leisure.isEmpty {
                                Text("Общаться с друзьями, вечеринки, прогулки на свежем воздухе, чтение, гейминг, настольные игры, волонтёрство…")
                                    .foregroundColor(Color(UIColor.placeholderText))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 8)
                            }
                            TextEditor(text: $leisure)
                                .frame(minHeight: 64)
                                .font(.body)
                                .padding(4)
                        }
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.07), radius: 8, y: 2)
                    )
                    Section(header: Text("Дополнительная информация")) {
                        ZStack(alignment: .topLeading) {
                            if additionalInfo.isEmpty {
                                Text("Что-то ещё важное, индивидуальное или необычное…")
                                    .foregroundColor(Color(UIColor.placeholderText))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 8)
                            }
                            TextEditor(text: $additionalInfo)
                                .frame(minHeight: 64)
                                .font(.body)
                                .padding(4)
                        }
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.07), radius: 8, y: 2)
                    )
                    
                    Section {
                        Button(action: {
                            isContactPickerPresented = true
                        }) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                Text("Импортировать из Контактов")
                            }
                        }
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.07), radius: 8, y: 2)
                    )
                    
                }
                .scrollDismissesKeyboard(.immediately)
                .navigationTitle("Добавить контакт")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Сохранить") {
                            if isSaveEnabled {
                                saveContact()
                            } else {
                                withAnimation { showSaveHint = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { showSaveHint = false }
                                }
                            }
                        }
                        .disabled(!isSaveEnabled)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { dismiss() }
                    }
                }
            }
        }
        .sheet(isPresented: $isContactPickerPresented) {
            ContactPickerView { importedCNContact in
                let importedContact = convertCNContactToContact(importedCNContact)
                if !vm.contacts.contains(where: { 
                    $0.name == importedContact.name && 
                    $0.surname == importedContact.surname && 
                    $0.birthday == importedContact.birthday 
                }) {
                    vm.addContact(importedContact)
                    importAlertMessage = "Контакт \"\(importedContact.name)\" успешно добавлен."
                } else {
                    importAlertMessage = "Контакт \"\(importedContact.name)\" уже существует."
                }
                showImportAlert = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                    isContactPickerPresented = false
                }
            }
        }
        .alert(isPresented: $showImportAlert) {
            Alert(title: Text("Импорт контакта"), message: Text(importAlertMessage), dismissButton: .default(Text("Ок")))
        }
    }

    private func saveContact() {
        let contact = Contact(
            id: UUID(),
            name: name,
            surname: surname.isEmpty ? nil : surname,
            nickname: nickname.isEmpty ? nil : nickname,
            relationType: relation.isEmpty ? nil : relation,
            gender: gender.isEmpty ? nil : gender,
            birthday: birthday,
            occupation: occupation.isEmpty ? nil : occupation,
            hobbies: hobbies.isEmpty ? nil : hobbies,
            leisure: leisure.isEmpty ? nil : leisure,
            additionalInfo: additionalInfo.isEmpty ? nil : additionalInfo
        )
        vm.addContact(contact)
        dismiss()
    }

    func convertCNContactToContact(_ cnContact: CNContact) -> Contact {
        var birthdayValue: Birthday? = nil
        if let bday = cnContact.birthday {
            birthdayValue = Birthday(
                day: bday.day ?? 0,
                month: bday.month ?? 0,
                year: bday.year
            )
        }

        return Contact(
            id: UUID(),
            name: cnContact.givenName,
            surname: cnContact.familyName.isEmpty ? nil : cnContact.familyName,
            nickname: cnContact.nickname.isEmpty ? nil : cnContact.nickname,
            relationType: nil,
            gender: nil,
            birthday: (birthdayValue?.day == 0 && birthdayValue?.month == 0 && birthdayValue?.year == nil) ? nil : birthdayValue,
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

extension View {
    func getRootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return nil }
        return root
    }
}
