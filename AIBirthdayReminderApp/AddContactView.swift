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

    private let relations = ["Брат", "Сестра", "Отец", "Мать", "Бабушка", "Дедушка", "Сын", "Дочь", "Коллега", "Руководитель", "Начальник", "Товарищ", "Друг", "Лучший друг", "Супруг", "Супруга", "Партнер", "Девушка", "Парень", "Клиент"]
    private let genders = ["Мужской", "Женский"]

    private var isSaveEnabled: Bool {
        !name.isEmpty
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
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.18), Color.purple.opacity(0.16), Color.teal.opacity(0.14)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            Form {
                Section {
                    VStack(spacing: 6) {
                        ContactAvatarHeaderView(
                            contact: Contact(id: UUID(), name: name.isEmpty ? "A" : name, surname: nil, nickname: nil, relationType: nil, gender: nil, birthday: nil, imageData: pickedImage?.jpegData(compressionQuality: 0.8), emoji: pickedEmoji),
                            pickedImage: pickedImage,
                            pickedEmoji: pickedEmoji,
                            headerHeight: 140
                        ) {
                            showAvatarSheet = true
                        }

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)){
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
                    .padding(.top, -25)
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
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Добавить контакт")
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        saveContact()
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
            SystemContactPickerView { cnContact in
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
                    importAlertMessage = "Контакт уже существует."
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
                    importAlertMessage = "Контакт успешно импортирован."
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
        if isDuplicateContact(name: name, surname: surname, birthday: birthday, phone: phoneNumber) {
            importAlertMessage = "Контакт уже существует."
            showImportAlert = true
            return
        }
        let contact = Contact(
            id: UUID(),
            name: name,
            surname: surname.isEmpty ? nil : surname,
            nickname: nickname.isEmpty ? nil : nickname,
            relationType: relation.isEmpty ? nil : relation,
            gender: gender.isEmpty ? nil : gender,
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
