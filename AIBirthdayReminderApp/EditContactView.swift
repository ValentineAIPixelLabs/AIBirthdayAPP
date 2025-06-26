import SwiftUI
import Contacts

struct EditContactView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var vm: ContactsViewModel
    @State private var contact: Contact

    @State private var name: String
    @State private var surname: String
    @State private var nickname: String
    @State private var relation: String
    @State private var gender: String
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

    private let relations = ["Брат", "Сестра", "Отец", "Мать", "Бабушка", "Дедушка", "Сын", "Дочь", "Коллега", "Руководитель", "Начальник", "Товарищ", "Друг", "Лучший друг", "Супруг", "Супруга", "Партнер", "Девушка", "Парень", "Клиент"]
    private let genders = ["Мужской", "Женский"]

    private var isSaveEnabled: Bool {
        !name.isEmpty
    }

    init(vm: ContactsViewModel, contact: Contact) {
        self.vm = vm
        _contact = State(initialValue: contact)
        _name = State(initialValue: contact.name)
        _surname = State(initialValue: contact.surname ?? "")
        _nickname = State(initialValue: contact.nickname ?? "")
        _relation = State(initialValue: contact.relationType ?? "")
        _gender = State(initialValue: contact.gender ?? "")
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
                Section {
                    VStack(spacing: 6) {
                        ContactAvatarHeaderView(
                            contact: Contact(id: contact.id, name: name.isEmpty ? "A" : name, surname: nil, nickname: nil, relationType: nil, gender: nil, birthday: nil, imageData: pickedImage?.jpegData(compressionQuality: 0.8), emoji: pickedEmoji),
                            pickedImage: pickedImage,
                            pickedEmoji: pickedEmoji,
                            headerHeight: 140
                        ) {
                            showAvatarSheet = true
                        }

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showAvatarSheet = true
                            }
                        }) {
                            Text("Выбрать аватар")
                                .font(.callout)
                                .foregroundStyle(.tint)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, -12)
                    .padding(.bottom, 4)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                Section(header: Text("Основная информация")) {
                    TextField("Имя", text: $name)
                    TextField("Фамилия (необязательно)", text: $surname)
                    TextField("Прозвище (необязательно)", text: $nickname)
                    Picker("Отношения", selection: $relation) {
                        ForEach(relations, id: \.self) { Text($0) }
                    }
                    Picker("Пол", selection: $gender) {
                        ForEach(genders, id: \.self) { Text($0) }
                    }
                    TextField("Телефон", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }

                Section(header: Text("Дата рождения")) {
                    BirthdayField(birthday: $birthday)
                }

                Section(header: Text("Род деятельности / Профессия")) {
                    ZStack(alignment: .topLeading) {
                        if occupation.isEmpty {
                            Text("Кем работает / На кого учится…")
                                .foregroundColor(Color(UIColor.placeholderText))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $occupation)
                            .frame(minHeight: 64)
                            .font(.body)
                    }
                }

                Section(header: Text("Увлечения / Хобби")) {
                    ZStack(alignment: .topLeading) {
                        if hobbies.isEmpty {
                            Text("Например, спорт, рыбалка, путешествия…")
                                .foregroundColor(Color(UIColor.placeholderText))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $hobbies)
                            .frame(minHeight: 64)
                            .font(.body)
                    }
                }

                Section(header: Text("Как любит проводить свободное время")) {
                    ZStack(alignment: .topLeading) {
                        if leisure.isEmpty {
                            Text("Прогулки, чтение, игры, волонтёрство…")
                                .foregroundColor(Color(UIColor.placeholderText))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $leisure)
                            .frame(minHeight: 64)
                            .font(.body)
                    }
                }

                Section(header: Text("Дополнительная информация")) {
                    ZStack(alignment: .topLeading) {
                        if additionalInfo.isEmpty {
                            Text("Что-то ещё важное…")
                                .foregroundColor(Color(UIColor.placeholderText))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $additionalInfo)
                            .frame(minHeight: 64)
                            .font(.body)
                    }
                }

                Section {
                    Button {
                        isContactPickerPresented = true
                    } label: {
                        Label("Импортировать из Контактов", systemImage: "person.crop.circle.badge.plus")
                    }
                }

                if showSaveHint {
                    Section {
                        Text("Заполните обязательные поля")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Редактировать")
            .navigationBarBackButtonHidden(true)
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
                if let image = image {
                    pickedImage = image
                    pickedEmoji = nil
                }
                showImagePicker = false
            }
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView { emoji in
                if let emoji = emoji {
                    pickedEmoji = emoji
                    pickedImage = nil
                }
                showEmojiPicker = false
            }
        }
        .fullScreenCover(isPresented: $showCameraPicker) {
            CameraPicker(image: $pickedImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $isContactPickerPresented) {
            ContactPickerView { cnContact in
                let imported = convertCNContactToContact(cnContact)
                // Сбор всех телефонов для выбора
                let numbers = cnContact.phoneNumbers.map { $0.value.stringValue }
                if !numbers.isEmpty {
                    if numbers.count == 1 {
                        phoneNumber = numbers[0]
                    } else {
                        phoneNumbersFromContact = numbers
                        showPhonePickerAlert = true
                    }
                }
                // Остальные поля по приоритету:
                var didUpdate = false
                if !imported.name.isEmpty {
                    if name != imported.name {
                        name = imported.name
                        didUpdate = true
                    }
                }
                if let importedSurname = imported.surname, !importedSurname.isEmpty {
                    if surname != importedSurname {
                        surname = importedSurname
                        didUpdate = true
                    }
                }
                if let importedNickname = imported.nickname, !importedNickname.isEmpty {
                    if nickname != importedNickname {
                        nickname = importedNickname
                        didUpdate = true
                    }
                }
                if let importedBirthday = imported.birthday {
                    if birthday != importedBirthday {
                        birthday = importedBirthday
                        didUpdate = true
                    }
                }
                if let importedOccupation = imported.occupation, !importedOccupation.isEmpty {
                    if occupation != importedOccupation {
                        occupation = importedOccupation
                        didUpdate = true
                    }
                }
                if let imageData = imported.imageData, !imageData.isEmpty {
                    if pickedImage?.jpegData(compressionQuality: 0.8) != imageData {
                        pickedImage = UIImage(data: imageData)
                        pickedEmoji = nil
                        didUpdate = true
                    }
                }
                if let importedPhone = imported.phoneNumber, !importedPhone.isEmpty {
                    if phoneNumber != importedPhone {
                        phoneNumber = importedPhone
                        didUpdate = true
                    }
                }
                if didUpdate {
                    importAlertMessage = "Данные обновлены из Контактов."
                } else {
                    importAlertMessage = "Контакт не изменился."
                }
                showImportAlert = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isContactPickerPresented = false
                }
            }
        }
        .alert(isPresented: $showImportAlert) {
            Alert(title: Text("Импорт контакта"), message: Text(importAlertMessage), dismissButton: .default(Text("Ок")))
        }
        .actionSheet(isPresented: $showPhonePickerAlert) {
            ActionSheet(
                title: Text("Выберите номер"),
                message: nil,
                buttons: phoneNumbersFromContact.map { number in
                    .default(Text(number)) {
                        phoneNumber = number
                    }
                } + [.cancel()]
            )
        }
    }

    private func saveContact() {
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
            relationType: nil,
            gender: nil,
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
