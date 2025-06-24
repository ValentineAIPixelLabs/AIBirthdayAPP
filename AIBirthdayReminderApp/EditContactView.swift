import SwiftUI

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
    // Если используешь imageData — добавь:
    @State private var imageData: Data?

    @State private var occupation: String
    @State private var hobbies: String
    @State private var leisure: String
    @State private var additionalInfo: String

    @State private var showSaveHint = false

    private let relations = ["Брат", "Сестра", "Отец", "Мать", "Бабушка", "Дедушка", "Сын", "Дочь", "Коллега", "Руководитель", "Начальник", "Товарищ", "Друг", "Лучший друг", "Супруг", "Супруга", "Партнер", "Девушка", "Парень", "Клиент"]
    private let genders = ["Мужской", "Женский"]

    private var isSaveEnabled: Bool {
        !name.isEmpty
        // && birthday != nil // Дата рождения теперь необязательна
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
        // если нужно фото:
        _imageData = State(initialValue: contact.imageData)
        _occupation = State(initialValue: contact.occupation ?? "")
        _hobbies = State(initialValue: contact.hobbies ?? "")
        _leisure = State(initialValue: contact.leisure ?? "")
        _additionalInfo = State(initialValue: contact.additionalInfo ?? "")
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
                        DatePicker(
                            "Дата рождения",
                            selection: Binding(
                                get: {
                                    if let birthday = birthday {
                                        // Преобразуем Birthday в Date (пример для года, месяца и дня, игнорируя время)
                                        var comps = DateComponents()
                                        comps.year = birthday.year
                                        comps.month = birthday.month
                                        comps.day = birthday.day
                                        return Calendar.current.date(from: comps) ?? Date()
                                    } else {
                                        // Дата по умолчанию (например, сегодня) - не важна, пользователь может очистить
                                        return Date()
                                    }
                                },
                                set: { newDate in
                                    let comps = Calendar.current.dateComponents([.year, .month, .day], from: newDate)
                                    birthday = Birthday(day: comps.day ?? 1, month: comps.month ?? 1, year: comps.year ?? 2000)
                                }
                            ),
                            displayedComponents: [.date]
                        )
                        // Кнопка для очистки даты рождения
                        Button("Очистить дату рождения") {
                            birthday = nil
                        }
                        .foregroundColor(.red)
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
                                    .foregroundColor(.gray.opacity(0.7))
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
                                    .foregroundColor(.gray.opacity(0.7))
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
                                    .foregroundColor(.gray.opacity(0.7))
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
                                    .foregroundColor(.gray.opacity(0.7))
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
                    // Если реализуешь выбор фото — вставь сюда PhotoPicker!
                    if showSaveHint {
                        Section {
                            Text("Заполните обязательные поля: имя и дату рождения")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .shadow(color: Color.black.opacity(0.07), radius: 8, y: 2)
                        )
                    }
                }
                .scrollDismissesKeyboard(.immediately)
                .navigationTitle("Редактировать")
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
    }

    private func saveContact() {
        // guard let b = birthday else { return } // Дата рождения теперь необязательна
        var updated = contact
        updated.name = name
        updated.surname = surname.isEmpty ? nil : surname
        updated.nickname = nickname.isEmpty ? nil : nickname
        updated.relationType = relation.isEmpty ? nil : relation
        updated.gender = gender.isEmpty ? nil : gender
        updated.birthday = birthday
        // если используешь фото:
        updated.imageData = imageData
        updated.occupation = occupation.isEmpty ? nil : occupation
        updated.hobbies = hobbies.isEmpty ? nil : hobbies
        updated.leisure = leisure.isEmpty ? nil : leisure
        updated.additionalInfo = additionalInfo.isEmpty ? nil : additionalInfo
        vm.updateContact(updated)
        NotificationManager.shared.scheduleBirthdayNotifications(for: updated, settings: vm.globalNotificationSettings)
        dismiss()
    }
}
