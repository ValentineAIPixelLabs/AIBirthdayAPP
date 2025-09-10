import SwiftUI
import UIKit

struct ContactDetailView: View {
    let isTestMode = false
    @ObservedObject var vm: ContactsViewModel
    let contactId: UUID
    

    @Environment(\.dismiss) var dismiss
    @State private var isEditActive = false
    @State private var showCongratsSheet = false
    @State private var isCongratsActive = false
    @State private var selectedCongratsMode: String? = nil

    var contact: Contact? {
        vm.contacts.first(where: { $0.id == contactId })
    }

    init(vm: ContactsViewModel, contactId: UUID) {
        self.vm = vm
        self.contactId = contactId
    }

    let headerHeight: CGFloat = 360

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

    // Display mapper: keeps stored value intact, shows localized title
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

    var body: some View {
        GeometryReader { geo in
            if let contact = contact {
                ZStack {
                    AppBackground()
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 12) {
                            headerBlock(contact: contact)
                            birthdayBlock(contact: contact)
                            phoneBlock(contact: contact)
                            occupationBlock(contact: contact)
                            hobbiesBlock(contact: contact)
                            leisureBlock(contact: contact)
                            additionalInfoBlock(contact: contact)
                            actionsPanel(contact: contact)
                                .padding(.bottom, 40)
                        }
                        .frame(maxWidth: EditorTheme.detailMaxWidth)
                        .padding(.horizontal, EditorTheme.detailHorizontalPadding)
                        .padding(.top, EditorTheme.detailHeaderTop)
                    }
                }
            }
        }
        .toolbar {
            // Trailing: edit (pencil)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if contact != nil {
                        isEditActive = true
                    }
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .navigationDestination(isPresented: $isEditActive) {
            if let contact = contact {
                EditContactView(vm: vm, contact: contact)
            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: $isCongratsActive) {
            if let c = contact,
               let idx = vm.contacts.firstIndex(where: { $0.id == c.id }),
               let mode = selectedCongratsMode {
                ContactCongratsView(contact: $vm.contacts[idx], selectedMode: mode)
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $showCongratsSheet) {
            if contact != nil {
                CongratulationActionSheet(
                    onGenerateText: {
                        selectedCongratsMode = "text"
                        showCongratsSheet = false
                        isCongratsActive = true
                    },
                    onGenerateCard: {
                        selectedCongratsMode = "card"
                        showCongratsSheet = false
                        isCongratsActive = true
                    }
                )
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
        }
    }


    // MARK: - Occupation Block
    private func occupationBlock(contact: Contact) -> some View {
        Group {
            if let occupation = contact.occupation, !occupation.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "briefcase")
                        .foregroundColor(.indigo)
                        .font(.title3)
                        .padding(.top, 2)
                    Text(occupation)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.vertical, CardStyle.Detail.verticalPadding)
                .padding(.horizontal, CardStyle.Detail.innerHorizontalPadding)
                .cardBackground()
                .padding(.top, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Hobbies Block
    private func hobbiesBlock(contact: Contact) -> some View {
        Group {
            if let hobbies = contact.hobbies, !hobbies.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "soccerball")
                        .foregroundColor(.green)
                        .font(.title3)
                        .padding(.top, 2)
                    Text(hobbies)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.vertical, CardStyle.Detail.verticalPadding)
                .padding(.horizontal, CardStyle.Detail.innerHorizontalPadding)
                .cardBackground()
                .padding(.top, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Leisure Block
    private func leisureBlock(contact: Contact) -> some View {
        Group {
            if let leisure = contact.leisure, !leisure.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "person.3.sequence")
                        .foregroundColor(.orange)
                        .font(.title3)
                        .padding(.top, 2)
                    Text(leisure)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.vertical, CardStyle.Detail.verticalPadding)
                .padding(.horizontal, CardStyle.Detail.innerHorizontalPadding)
                .cardBackground()
                .padding(.top, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Additional Info Block
    private func additionalInfoBlock(contact: Contact) -> some View {
        Group {
            if let info = contact.additionalInfo, !info.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.yellow)
                        .font(.title3)
                        .padding(.top, 2)
                    Text(info)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.vertical, CardStyle.Detail.verticalPadding)
                .padding(.horizontal, CardStyle.Detail.innerHorizontalPadding)
                .cardBackground()
                .padding(.top, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Header
    private func headerBlock(contact: Contact) -> some View {
        VStack(spacing: EditorTheme.detailHeaderSpacing) {
            // Централизованный аватар из AvatarKit
            let avatarSource: AvatarSource = {
                if let data = contact.imageData, let img = UIImage(data: data) {
                    return .image(img)
                } else if let e = contact.emoji, !e.isEmpty {
                    return .emoji(e)
                } else {
                    let initial = contact.name.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "?"
                    return .monogram(initial)
                }
            }()
            AppAvatarView(source: avatarSource, shape: .circle, size: .headerXL, showsEditBadge: false)
            // Имя и фамилия (крупно, по центру)
            if let surname = contact.surname, !surname.isEmpty {
                VStack(spacing: 0) {
                    Text(contact.name)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    Text(surname)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            } else {
                Text(contact.name)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            // Тип отношений — бейдж под именем/фамилией, если явно указан (не пусто и не "Не указано")
            if let rawRelation = contact.relationType?.trimmingCharacters(in: .whitespacesAndNewlines),
               !rawRelation.isEmpty,
               rawRelation.caseInsensitiveCompare(Contact.unspecified) != .orderedSame {
                let relationTitle = localizedRelationTitle(rawRelation)
                Text(relationTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.7))
                    )
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - BirthdayBlock
    private func birthdayBlock(contact: Contact) -> some View {
        HStack(spacing: CardStyle.Detail.spacing) {
            Image(systemName: "gift.fill")
                .foregroundColor(.pink)
                .font(.system(size: CardStyle.Detail.iconSize))
            Text(formattedBirthdayDetails(for: contact.birthday))
                .font(CardStyle.Detail.font)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.vertical, CardStyle.Detail.verticalPadding)
        .padding(.horizontal, CardStyle.Detail.innerHorizontalPadding)
        .cardBackground()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - PhoneBlock
    private func phoneBlock(contact: Contact) -> some View {
        Group {
            if let phone = contact.phoneNumber, !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: CardStyle.Detail.spacing) {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.green)
                        .font(.system(size: CardStyle.Detail.iconSize))
                    Text(phone)
                        .font(CardStyle.Detail.font)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                }
                .padding(.vertical, CardStyle.Detail.verticalPadding)
                .padding(.horizontal, CardStyle.Detail.innerHorizontalPadding)
                .cardBackground()
                .padding(.top, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - DescriptionBlock (удалён)

    // MARK: - ActionsPanel
    private func actionsPanel(contact: Contact) -> some View {
        VStack(spacing: 10) {
            CongratulateButton {
                showCongratsSheet = true
            }
        }
    }

    // MARK: - Birthday Date Formatter

    
}
