import SwiftUI


// Теперь компонент используется как ContactSelectSheetView(vm: ..., onContactSelected: ...)
@MainActor
struct ContactSelectSheetView: View {
    @Environment(\.dismiss) var dismiss

    // Список всех контактов приложения
    @State private var searchText = ""
    @ObservedObject var vm: ContactsViewModel

    var onContactSelected: (Contact) -> Void

    var filteredContacts: [Contact] {
        if searchText.isEmpty {
            return vm.contacts
        } else {
            return vm.contacts.filter {
                $0.fullName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredContacts) { contact in
                Button {
                    DispatchQueue.main.async {
                        onContactSelected(contact)
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(contact: contact, size: 40)
                        Text(contact.fullName)
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .navigationTitle("Выберите контакт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Используй свой AvatarView для отображения аватара контакта.
// Если в проекте нет AvatarView, замени на простую инициал буквы:
@MainActor
struct AvatarView: View {
    let contact: Contact
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size/4)
                .fill(Color.gray.opacity(0.15))
            Text(String(contact.fullName.prefix(1)).uppercased())
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundColor(.secondary)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size/4))
    }
}
