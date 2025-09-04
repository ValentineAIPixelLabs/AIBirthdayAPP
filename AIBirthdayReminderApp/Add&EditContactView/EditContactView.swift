import SwiftUI
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

struct EditContactView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var vm: ContactsViewModel
    @State private var contact: Contact

    @State private var name: String
    @State private var surname: String
    @State private var nickname: String
    @State private var relation: String = Contact.unspecified
    @State private var gender: String = Contact.unspecified
    @State private var birthday: Birthday?

    @State private var occupation: String
    @State private var hobbies: String
    @State private var leisure: String
    @State private var additionalInfo: String
    @State private var phoneNumber: String

    @State private var pickedImage: UIImage?
    @State private var pickedEmoji: String?
    @State private var showAvatarSheet = false
    @State private var showImagePicker = false
    @State private var showEmojiPicker = false
    @State private var showCameraPicker = false

    @State private var showSaveHint = false

    @State private var isContactPickerPresented = false
    @State private var showImportAlert = false
    @State private var importAlertMessage = ""
    @State private var showPhonePickerAlert = false
    @State private var phoneNumbersFromContact: [String] = []
    @State private var tempImportedContact: Contact?

    private let relations = [Contact.unspecified, "Брат", "Сестра", "Отец", "Мать", "Бабушка", "Дедушка", "Сын", "Дочь", "Коллега", "Руководитель", "Начальник", "Товарищ", "Друг", "Лучший друг", "Супруг", "Супруга", "Партнер", "Девушка", "Парень", "Клиент"]
    private let genders = [Contact.unspecified, "Мужской", "Женский"]

    private var isSaveEnabled: Bool {
        !name.isEmpty
    }

    private func isDuplicateContact(name: String, surname: String, birthday: Birthday?, phone: String) -> Bool {
        vm.contacts.contains(where: { c in
            c.id != contact.id &&
            c.name == name &&
            (c.surname ?? "") == (surname) &&
            c.birthday == birthday &&
            (c.phoneNumber ?? "") == (phone)
        })
    }

    init(vm: ContactsViewModel, contact: Contact) {
        self.vm = vm
        _contact = State(initialValue: contact)
        _name = State(initialValue: contact.name)
        _surname = State(initialValue: contact.surname ?? "")
        _nickname = State(initialValue: contact.nickname ?? "")
        _relation = State(initialValue: contact.relationType ?? Contact.unspecified)
        _gender = State(initialValue: contact.gender ?? Contact.unspecified)
        _birthday = State(initialValue: contact.birthday)
        _occupation = State(initialValue: contact.occupation ?? "")
        _hobbies = State(initialValue: contact.hobbies ?? "")
        _leisure = State(initialValue: contact.leisure ?? "")
        _additionalInfo = State(initialValue: contact.additionalInfo ?? "")
        _phoneNumber = State(initialValue: contact.phoneNumber ?? "")

        _pickedImage = State(initialValue: {
            if let data = contact.imageData, let uiImage = UIImage(data: data) {
                return uiImage
            }
            return nil
        }())
        _pickedEmoji = State(initialValue: contact.emoji)
    }

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.18), Color.purple.opacity(0.16), Color.teal.opacity(0.14)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            Form {
                AvatarHeaderSection(
                    source: {
                        if let image = pickedImage {
                            return .image(image)
                        } else if let emoji = pickedEmoji {
                            return .emoji(emoji)
                        } else {
                            let initial = name.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0) } ?? "?"
                            return .monogram(initial.uppercased())
                        }
                    }(),
                    shape: .circle,
                    size: .headerXL,
                    buttonTitle: String(localized: "avatar.select", defaultValue: "Выбрать аватар", bundle: appBundle(), locale: appLocale()),
                    onTap: { showAvatarSheet = true }
                )

                Section(header: Text(String(localized: "add.section.main_info", defaultValue: "Основная информация", bundle: appBundle(), locale: appLocale()))) {
                    TextField(String(localized: "add.name", defaultValue: "Имя", bundle: appBundle(), locale: appLocale()), text: $name)
                    TextField(String(localized: "add.surname.optional", defaultValue: "Фамилия (необязательно)", bundle: appBundle(), locale: appLocale()), text: $surname)
                    TextField(String(localized: "add.nickname.optional", defaultValue: "Прозвище (необязательно)", bundle: appBundle(), locale: appLocale()), text: $nickname)
                    Picker(String(localized: "add.relation", defaultValue: "Отношения", bundle: appBundle(), locale: appLocale()), selection: $relation) {
                        ForEach(relations, id: \.self) { Text(localizedRelationTitle($0)) }
                    }
                    Picker(String(localized: "add.gender", defaultValue: "Пол", bundle: appBundle(), locale: appLocale()), selection: $gender) {
                        ForEach(genders, id: \.self) { Text(localizedGenderTitle($0)) }
                    }
                    TextField(String(localized: "add.phone", defaultValue: "Телефон", bundle: appBundle(), locale: appLocale()), text: $phoneNumber)
                        .keyboardType(.phonePad)
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
                    }
                }

                if showSaveHint {
                    Section {
                        Text(String(localized: "form.required.hint", defaultValue: "Заполните обязательные поля", bundle: appBundle(), locale: appLocale()))
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarBackButtonHidden(true)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(String(localized: "common.save", defaultValue: "Сохранить", bundle: appBundle(), locale: appLocale())) {
                    saveContact()
                }
                .disabled(!isSaveEnabled)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "common.cancel", defaultValue: "Отмена", bundle: appBundle(), locale: appLocale())) { dismiss() }
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
                    }
                }
            )
            .presentationDetents([.height(225)])
        }
        .sheet(isPresented: $showImagePicker) {
            PhotoPickerWithCrop { image in
                DispatchQueue.main.async {
                    if let image = image {
                        pickedImage = image
                        pickedEmoji = nil
                    }
                    showImagePicker = false
                }
            }
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView { emoji in
                DispatchQueue.main.async {
                    if let emoji = emoji {
                        pickedEmoji = emoji
                        pickedImage = nil
                    }
                    showEmojiPicker = false
                }
            }
        }
        .fullScreenCover(isPresented: $showCameraPicker) {
            CameraPicker(image: $pickedImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $isContactPickerPresented) {
            SystemContactsPickerViewMultiple { selected in
                DispatchQueue.main.async {
                    guard let cnContact = selected.first else {
                        isContactPickerPresented = false
                        return
                    }
                    let imported = convertCNContactToContact(cnContact)
                    let numbers = cnContact.phoneNumbers.map { $0.value.stringValue }
                    if !numbers.isEmpty {
                        if numbers.count == 1 {
                            let importedPhone = numbers[0]
                            let phoneWasChanged = phoneNumber != importedPhone
                            phoneNumber = importedPhone
                            importAndShowAlert(from: imported, phoneWasChanged: phoneWasChanged)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isContactPickerPresented = false
                            }
                        } else {
                            phoneNumbersFromContact = numbers
                            tempImportedContact = imported
                            showPhonePickerAlert = true
                            // не закрываем sheet, ждём выбора
                        }
                    } else {
                        importAndShowAlert(from: imported, phoneWasChanged: false)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isContactPickerPresented = false
                        }
                    }
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
        .actionSheet(isPresented: $showPhonePickerAlert) {
            ActionSheet(
                title: Text(String(localized: "contact.phone.select", defaultValue: "Выберите номер", bundle: appBundle(), locale: appLocale())),
                message: nil,
                buttons: phoneNumbersFromContact.map { number in
                    .default(Text(number)) {
                        let phoneWasChanged = phoneNumber != number
                        phoneNumber = number
                        // Используем временный контакт (tempImportedContact)
                        importAndShowAlert(from: tempImportedContact, phoneWasChanged: phoneWasChanged)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isContactPickerPresented = false
                        }
                        tempImportedContact = nil
                    }
                } + [.cancel({
                    tempImportedContact = nil
                })]
            )
        }
    }

    private func importAndShowAlert(from imported: Contact?, phoneWasChanged: Bool) {
        // Проверка на дубликат
        if let imported = imported,
           isDuplicateContact(name: imported.name, surname: imported.surname ?? "", birthday: imported.birthday, phone: phoneNumber) {
            importAlertMessage = String(localized: "contact.import.exists", defaultValue: "Контакт с такими данными уже существует.", bundle: appBundle(), locale: appLocale())
            showImportAlert = true
            return
        }

        var didUpdate = phoneWasChanged

        if let imported = imported {
            if !imported.name.isEmpty, name != imported.name {
                name = imported.name
                didUpdate = true
            }
            if let importedSurname = imported.surname, !importedSurname.isEmpty, surname != importedSurname {
                surname = importedSurname
                didUpdate = true
            }
            if let importedNickname = imported.nickname, !importedNickname.isEmpty, nickname != importedNickname {
                nickname = importedNickname
                didUpdate = true
            }
            if let importedBirthday = imported.birthday, birthday != importedBirthday {
                birthday = importedBirthday
                didUpdate = true
            }
            if let importedOccupation = imported.occupation, !importedOccupation.isEmpty, occupation != importedOccupation {
                occupation = importedOccupation
                didUpdate = true
            }
            if let imageData = imported.imageData, !imageData.isEmpty, pickedImage?.jpegData(compressionQuality: 0.8) != imageData {
                pickedImage = UIImage(data: imageData)
                pickedEmoji = nil
                didUpdate = true
            }
        }
        importAlertMessage = didUpdate ? String(localized: "contact.import.updated", defaultValue: "Данные обновлены из Контактов.", bundle: appBundle(), locale: appLocale()) : String(localized: "contact.import.nochange", defaultValue: "Контакт не изменился.", bundle: appBundle(), locale: appLocale())
        showImportAlert = true
    }

    private func saveContact() {
        if isDuplicateContact(name: name, surname: surname, birthday: birthday, phone: phoneNumber) {
            importAlertMessage = String(localized: "contact.import.exists", defaultValue: "Контакт с такими данными уже существует.", bundle: appBundle(), locale: appLocale())
            showImportAlert = true
            return
        }
        var updated = contact
        updated.name = name
        updated.surname = surname.isEmpty ? nil : surname
        updated.nickname = nickname.isEmpty ? nil : nickname
        updated.relationType = relation.isEmpty ? nil : relation
        updated.gender = gender.isEmpty ? nil : gender
        updated.birthday = birthday
        updated.imageData = pickedImage?.jpegData(compressionQuality: 0.8)
        updated.emoji = pickedEmoji
        updated.occupation = occupation.isEmpty ? nil : occupation
        updated.hobbies = hobbies.isEmpty ? nil : hobbies
        updated.leisure = leisure.isEmpty ? nil : leisure
        updated.additionalInfo = additionalInfo.isEmpty ? nil : additionalInfo
        updated.phoneNumber = phoneNumber.isEmpty ? nil : phoneNumber
        vm.updateContact(updated)
        NotificationManager.shared.scheduleBirthdayNotifications(for: updated, settings: vm.globalNotificationSettings)
        dismiss()
    }

    private func convertCNContactToContact(_ cn: CNContact) -> Contact {
        var bday: Birthday? = nil
        if let d = cn.birthday {
            bday = Birthday(day: d.day ?? 0, month: d.month ?? 0, year: d.year)
        }
        let phone = cn.phoneNumbers.first?.value.stringValue
        return Contact(
            id: UUID(),
            name: cn.givenName,
            surname: cn.familyName.isEmpty ? nil : cn.familyName,
            nickname: cn.nickname.isEmpty ? nil : cn.nickname,
            relationType: Contact.unspecified,
            gender: Contact.unspecified,
            birthday: bday,
            notificationSettings: .default,
            imageData: cn.imageData,
            emoji: nil,
            occupation: cn.jobTitle.isEmpty ? nil : cn.jobTitle,
            hobbies: nil,
            leisure: nil,
            additionalInfo: nil,
            phoneNumber: phone
        )
    }
}
