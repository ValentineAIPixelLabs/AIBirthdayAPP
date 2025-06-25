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

    @State private var pickedImage: UIImage?
    @State private var pickedEmoji: String?
    @State private var pickedMonogram: String? = "A"
    @State private var showAvatarSheet = false
    @State private var showImagePicker = false
    @State private var showCameraPicker = false
    @State private var showEmojiPicker = false

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
            ContactPickerView { cnContact in
                let imported = convertCNContactToContact(cnContact)
                if !vm.contacts.contains(where: { $0.name == imported.name && $0.surname == imported.surname && $0.birthday == imported.birthday }) {
                    vm.addContact(imported)
                    importAlertMessage = "Контакт \"\(imported.name)\" успешно добавлен."
                } else {
                    importAlertMessage = "Контакт \"\(imported.name)\" уже существует."
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
            notificationSettings: .default,
            imageData: pickedImage?.jpegData(compressionQuality: 0.8),
            emoji: pickedEmoji,
            occupation: occupation.isEmpty ? nil : occupation,
            hobbies: hobbies.isEmpty ? nil : hobbies,
            leisure: leisure.isEmpty ? nil : leisure,
            additionalInfo: additionalInfo.isEmpty ? nil : additionalInfo
        )
        vm.addContact(contact)
        dismiss()
    }

    private func convertCNContactToContact(_ cn: CNContact) -> Contact {
        var bday: Birthday? = nil
        if let d = cn.birthday {
            bday = Birthday(day: d.day ?? 0, month: d.month ?? 0, year: d.year)
        }
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
            additionalInfo: nil
        )
    }
}
