import SwiftUI
import UIKit
import Contacts

// MARK: - Localization helpers (file-local)
private func appLocale() -> Locale {
    if let code = UserDefaults.standard.string(forKey: "app.language.code") {
        return Locale(identifier: code)
    }
    if let code = Bundle.main.preferredLocalizations.first {
        return Locale(identifier: code)
    }
    return .current
}
private func appBundle() -> Bundle {
    if let code = UserDefaults.standard.string(forKey: "app.language.code"),
       let path = Bundle.main.path(forResource: code, ofType: "lproj"),
       let bundle = Bundle(path: path) {
        return bundle
    }
    return .main
}

// MARK: - Display mappers (keep model values as-is)
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

private func localizedGenderTitle(_ value: String) -> String {
    let b = appBundle()
    switch value {
    case Contact.unspecified:
        return b.localizedString(forKey: "common.unspecified", value: value, table: "Localizable")
    case "Мужской": return b.localizedString(forKey: "gender.male", value: value, table: "Localizable")
    case "Женский": return b.localizedString(forKey: "gender.female", value: value, table: "Localizable")
    default:         return value
    }
}
//import ButtonStyle

struct AddContactView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var vm: ContactsViewModel

    @State private var name: String = ""
    @State private var surname: String = ""
    @State private var nickname: String = ""
    @State private var relation: String = Contact.unspecified
    @State private var gender: String = Contact.unspecified
    @State private var birthday: Birthday? = nil

    @State private var occupation: String = ""
    @State private var hobbies: String = ""
    @State private var leisure: String = ""
    @State private var additionalInfo: String = ""
    @State private var phoneNumber: String = ""

    @State private var pickedImage: UIImage?
    @State private var pickedEmoji: String?
    @State private var pickedMonogram: String? = "A"
    @State private var showAvatarSheet = false
    @State private var showImagePicker = false
    @State private var showCameraPicker = false
    @State private var showEmojiPicker = false

    @State private var showSaveHint = false
    @State private var isContactPickerPresented = false
    @State private var showImportAlert = false
    @State private var importAlertMessage = ""
    @State private var showPhonePickerAlert = false
    @State private var phoneNumbersFromContact: [String] = []

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, surname, nickname, phone, occupation, hobbies, leisure, additional
    }

    private let relations = [Contact.unspecified, "Брат", "Сестра", "Отец", "Мать", "Бабушка", "Дедушка", "Сын", "Дочь", "Коллега", "Руководитель", "Начальник", "Товарищ", "Друг", "Лучший друг", "Супруг", "Супруга", "Партнер", "Девушка", "Парень", "Клиент"]
    private let genders = [Contact.unspecified, "Мужской", "Женский"]

    private var isSaveEnabled: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }


    // === Функция проверки на дубликат ===
    private func isDuplicateContact(name: String, surname: String, birthday: Birthday?, phone: String) -> Bool {
        vm.contacts.contains(where: { contact in
            contact.name == name &&
            (contact.surname ?? "") == (surname) &&
            contact.birthday == birthday &&
            (contact.phoneNumber ?? "") == (phone)
        })
    }

    var body: some View {
        ZStack {
            AppBackground()
            
            Form {
                AvatarHeaderSection(
                    source: {
                        if let image = pickedImage {
                            return .image(image)
                        } else if let emoji = pickedEmoji {
                            return .emoji(emoji)
                        } else {
                            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            let initial = trimmed.isEmpty ? (pickedMonogram ?? "A") : String(trimmed.first!).uppercased()
                            return .monogram(initial)
                        }
                    }(),
                    shape: .circle,
                    size: .headerXL,
                    buttonTitle: String(localized: "avatar.select", defaultValue: "Выбрать аватар", bundle: appBundle(), locale: appLocale()),
                    onTap: { showAvatarSheet = true }
                )

                Section(header: Text(String(localized: "add.section.main_info", defaultValue: "Основная информация", bundle: appBundle(), locale: appLocale()))) {
                    TextField(String(localized: "add.name", defaultValue: "Имя", bundle: appBundle(), locale: appLocale()), text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)
                        .textContentType(.givenName)
                        .font(.body)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .surname }
                    TextField(String(localized: "add.surname.optional", defaultValue: "Фамилия (необязательно)", bundle: appBundle(), locale: appLocale()), text: $surname)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)
                        .textContentType(.familyName)
                        .font(.body)
                        .focused($focusedField, equals: .surname)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .nickname }
                    TextField(String(localized: "add.nickname.optional", defaultValue: "Прозвище (необязательно)", bundle: appBundle(), locale: appLocale()), text: $nickname)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textContentType(.nickname)
                        .font(.body)
                        .focused($focusedField, equals: .nickname)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .phone }
                    Picker(String(localized: "add.relation", defaultValue: "Отношения", bundle: appBundle(), locale: appLocale()), selection: $relation) {
                        ForEach(relations, id: \.self) { Text(localizedRelationTitle($0)) }
                    }
                    Picker(String(localized: "add.gender", defaultValue: "Пол", bundle: appBundle(), locale: appLocale()), selection: $gender) {
                        ForEach(genders, id: \.self) { Text(localizedGenderTitle($0)) }
                    }
                    TextField(String(localized: "add.phone", defaultValue: "Телефон", bundle: appBundle(), locale: appLocale()), text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textContentType(.telephoneNumber)
                        .font(.body)
                        .focused($focusedField, equals: .phone)
                        .submitLabel(.done)
                }
                
                Section(header: Text(String(localized: "add.section.birthday", defaultValue: "Дата рождения", bundle: appBundle(), locale: appLocale()))) {
                    BirthdayField(birthday: $birthday)
                }
                
                Section(header: Text(String(localized: "add.section.occupation", defaultValue: "Род деятельности / Профессия", bundle: appBundle(), locale: appLocale()))) {
                    ZStack(alignment: .topLeading) {
                        if occupation.isEmpty {
                            Text(String(localized: "add.occupation.placeholder", defaultValue: "Кем работает / На кого учится…", bundle: appBundle(), locale: appLocale()))
                                .foregroundColor(Color(UIColor.placeholderText))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $occupation)
                            .frame(minHeight: 64)
                            .font(.body)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.sentences)
                            .focused($focusedField, equals: .occupation)
                    }
                }

                Section(header: Text(String(localized: "add.section.hobbies", defaultValue: "Увлечения / Хобби", bundle: appBundle(), locale: appLocale()))) {
                    ZStack(alignment: .topLeading) {
                        if hobbies.isEmpty {
                            Text(String(localized: "add.hobbies.placeholder", defaultValue: "Например, спорт, рыбалка, путешествия…", bundle: appBundle(), locale: appLocale()))
                                .foregroundColor(Color(UIColor.placeholderText))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $hobbies)
                            .frame(minHeight: 64)
                            .font(.body)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.sentences)
                            .focused($focusedField, equals: .hobbies)
                    }
                }

                Section(header: Text(String(localized: "add.section.leisure", defaultValue: "Как любит проводить свободное время", bundle: appBundle(), locale: appLocale()))) {
                    ZStack(alignment: .topLeading) {
                        if leisure.isEmpty {
                            Text(String(localized: "add.leisure.placeholder", defaultValue: "Прогулки, чтение, игры, волонтёрство…", bundle: appBundle(), locale: appLocale()))
                                .foregroundColor(Color(UIColor.placeholderText))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $leisure)
                            .frame(minHeight: 64)
                            .font(.body)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.sentences)
                            .focused($focusedField, equals: .leisure)
                    }
                }

                Section(header: Text(String(localized: "add.section.additional", defaultValue: "Дополнительная информация", bundle: appBundle(), locale: appLocale()))) {
                    ZStack(alignment: .topLeading) {
                        if additionalInfo.isEmpty {
                            Text(String(localized: "add.additional.placeholder", defaultValue: "Что-то ещё важное…", bundle: appBundle(), locale: appLocale()))
                                .foregroundColor(Color(UIColor.placeholderText))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $additionalInfo)
                            .frame(minHeight: 64)
                            .font(.body)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.sentences)
                            .focused($focusedField, equals: .additional)
                    }
                }

            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(String(localized: "common.add", defaultValue: "Добавить", bundle: appBundle(), locale: appBundle().preferredLocalizations.first.map { Locale(identifier: $0) } ?? appLocale())) {
                        saveContact()
                    }
                    .disabled(!isSaveEnabled)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "keyboard.done", defaultValue: "Готово", bundle: appBundle(), locale: appLocale())) {
                        focusedField = nil
                    }
                }
            }
        }
        .sheet(isPresented: $showAvatarSheet) {
            AvatarPickerSheet(
                onCamera: {
                    showAvatarSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showCameraPicker = true }
                },
                onPhoto: {
                    showAvatarSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showImagePicker = true }
                },
                onEmoji: {
                    showAvatarSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showEmojiPicker = true }
                },
                onMonogram: {
                    showAvatarSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        pickedImage = nil
                        pickedEmoji = nil
                        pickedMonogram = "A"
                    }
                }
            )
            .presentationDetents([.height(225)])
        }
        .sheet(isPresented: $showImagePicker) {
            PhotoPickerWithCrop { image in
                if let image = image {
                    pickedImage = image
                    pickedEmoji = nil
                    pickedMonogram = ""
                }
                showImagePicker = false
            }
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView { emoji in
                if let emoji = emoji {
                    pickedEmoji = emoji
                    pickedImage = nil
                    pickedMonogram = ""
                }
                showEmojiPicker = false
            }
        }
        .fullScreenCover(isPresented: $showCameraPicker) {
            CameraPicker(image: $pickedImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $isContactPickerPresented) {
            SystemContactsPickerViewMultiple { selected in
                guard let cnContact = selected.first else { return }
                let imported = convertCNContactToContact(cnContact)
                let numbers = cnContact.phoneNumbers.map { $0.value.stringValue }
                if !numbers.isEmpty {
                    if numbers.count == 1 {
                        phoneNumber = numbers[0]
                    } else {
                        phoneNumbersFromContact = numbers
                        showPhonePickerAlert = true
                    }
                }
                // Проверка на дубликат
                if isDuplicateContact(name: imported.name, surname: imported.surname ?? "", birthday: imported.birthday, phone: imported.phoneNumber ?? "") {
                    importAlertMessage = String(localized: "contact.import.exists", defaultValue: "Контакт уже существует.", bundle: appBundle(), locale: appLocale())
                } else {
                    name = imported.name
                    surname = imported.surname ?? ""
                    nickname = imported.nickname ?? ""
                    birthday = imported.birthday
                    occupation = imported.occupation ?? ""
                    if let imageData = imported.imageData, !imageData.isEmpty {
                        pickedImage = UIImage(data: imageData)
                        pickedEmoji = nil
                        pickedMonogram = ""
                    }
                    importAlertMessage = String(localized: "contact.import.success", defaultValue: "Контакт успешно импортирован.", bundle: appBundle(), locale: appLocale())
                }
                showImportAlert = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isContactPickerPresented = false
                }
            }
        }
        .alert(isPresented: $showImportAlert) {
            Alert(
                title: Text(String(localized: "contact.import.title", defaultValue: "Импорт контакта", bundle: appBundle(), locale: appLocale())),
                message: Text(importAlertMessage),
                dismissButton: .default(Text(String(localized: "common.ok", defaultValue: "Ок", bundle: appBundle(), locale: appLocale())))
            )
        }
        .confirmationDialog(
            Text(String(localized: "contact.phone.select", defaultValue: "Выберите номер", bundle: appBundle(), locale: appLocale())),
            isPresented: $showPhonePickerAlert,
            titleVisibility: .visible
        ) {
            ForEach(phoneNumbersFromContact, id: \.self) { number in
                Button(number) { phoneNumber = number }
            }
            Button(String(localized: "common.cancel", defaultValue: "Отмена", bundle: appBundle(), locale: appLocale()), role: .cancel) {}
        }
    }

    private func saveContact() {
        if isDuplicateContact(name: name, surname: surname, birthday: birthday, phone: phoneNumber) {
            importAlertMessage = String(localized: "contact.import.exists", defaultValue: "Контакт уже существует.", bundle: appBundle(), locale: appLocale())
            showImportAlert = true
            return
        }
        let contact = Contact(
            id: UUID(),
            name: name,
            surname: surname.isEmpty ? nil : surname,
            nickname: nickname.isEmpty ? nil : nickname,
            relationType: relation.isEmpty ? Contact.unspecified : relation,
            gender: gender.isEmpty ? Contact.unspecified : gender,
            birthday: birthday,
            notificationSettings: .default,
            imageData: pickedImage?.jpegData(compressionQuality: 0.8),
            emoji: pickedEmoji,
            occupation: occupation.isEmpty ? nil : occupation,
            hobbies: hobbies.isEmpty ? nil : hobbies,
            leisure: leisure.isEmpty ? nil : leisure,
            additionalInfo: additionalInfo.isEmpty ? nil : additionalInfo,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber
        )
        vm.addContact(contact)
        dismiss()
    }

    private func convertCNContactToContact(_ cn: CNContact) -> Contact {
        var bday: Birthday? = nil
        if let d = cn.birthday {
            bday = Birthday(day: d.day ?? 0, month: d.month ?? 0, year: d.year)
        }
        let phone = cn.phoneNumbers.first?.value.stringValue
        let first = cn.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last  = cn.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nick  = cn.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeFirst = first.isEmpty ? (nick.isEmpty ? String(localized: "contact.no_name", defaultValue: "Без имени", bundle: appBundle(), locale: appLocale()) : nick) : first

        return Contact(
            id: UUID(),
            name: safeFirst,
            surname: last.isEmpty ? nil : last,
            nickname: nick.isEmpty ? nil : nick,
            relationType: Contact.unspecified,
            gender: Contact.unspecified,
            birthday: bday,
            notificationSettings: .default,
            imageData: cn.imageData,
            emoji: nil,
            occupation: cn.jobTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : cn.jobTitle,
            hobbies: nil,
            leisure: nil,
            additionalInfo: nil,
            phoneNumber: phone
        )
    }
}
