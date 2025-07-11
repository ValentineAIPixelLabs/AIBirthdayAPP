import SwiftUI
//import CardStyle
import UIKit
//import ButtonStyle


struct ContactDetailView: View {
    let isTestMode = false
    @ObservedObject var vm: ContactsViewModel
    let contactId: UUID

    
    @State private var pickedImage: UIImage?
    @State private var showAvatarSheet = false
    @State private var showImagePicker = false
    @State private var showCameraPicker = false
    @State private var showEmojiPicker = false
    @State private var showMonogramPicker = false
    @State private var pickedEmoji: String?
    @State private var pickedMonogram: String?
    @State private var monogramColor: Color = .blue

    // Удалены состояния, связанные с генерацией поздравлений и открыток

    @AppStorage("openai_api_key") private var apiKey: String = ""

    @Environment(\.dismiss) var dismiss
    @State private var selectedContactForEdit: Contact? = nil

    var contact: Contact? {
        vm.contacts.first(where: { $0.id == contactId })
    }

    init(vm: ContactsViewModel, contactId: UUID) {
        self.vm = vm
        self.contactId = contactId
    }

    let headerHeight: CGFloat = 360

    var body: some View {
        GeometryReader { geo in
            if let contact = contact {
                ZStack {
                    AppBackground()
                    ZStack(alignment: .top) {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 20) {
                                headerBlock(contact: contact)
                                birthdayBlock(contact: contact)
                                occupationBlock(contact: contact)
                                hobbiesBlock(contact: contact)
                                leisureBlock(contact: contact)
                                additionalInfoBlock(contact: contact)
                                actionsPanel(contact: contact)
                                    .padding(.bottom, 40)
                            }
                            .frame(maxWidth: 500)
                            .padding(.horizontal, 16)
                            .padding(.top, 80)
                        }
                        topButtons(geo: geo)
                    }
                    .edgesIgnoringSafeArea(.top)
                }
            }
        }
        // onAppear без вызова handleOnAppear
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        
        .navigationDestination(item: $selectedContactForEdit) { contact in
                    EditContactView(vm: vm, contact: contact)
                }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        
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
                        if var contact = contact {
                            contact.imageData = nil
                            contact.emoji = nil
                            vm.updateContact(contact)
                        }
                        pickedImage = nil
                        pickedEmoji = nil
                        pickedMonogram = ""
                    }
                }
            )
            .presentationDetents([.height(225)])
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .sheet(isPresented: $showImagePicker) {
            PhotoPickerWithCrop { image in
                if let image = image, var contact = contact {
                    contact.imageData = image.jpegData(compressionQuality: 0.9)
                    contact.emoji = nil
                    vm.updateContact(contact)
                }
                pickedImage = nil
                pickedEmoji = nil
                pickedMonogram = ""
                showImagePicker = false
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .fullScreenCover(isPresented: $showCameraPicker) {
            CameraPicker(image: $pickedImage)
                .ignoresSafeArea()
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onChange(of: pickedMonogram) { newMonogram, _ in
            // Если выбрали монограмму, сбрасываем изображение и эмодзи и обновляем контакт
            if let newMonogram = newMonogram, !newMonogram.isEmpty {
                pickedImage = nil
                pickedEmoji = nil
                if var contact = contact {
                    contact.imageData = nil
                    contact.emoji = nil
                    vm.updateContact(contact)
                }
            }
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView { emoji in
                if let emoji = emoji, var contact = contact {
                    contact.emoji = emoji
                    contact.imageData = nil
                    vm.updateContact(contact)
                }
                pickedImage = nil
                pickedEmoji = nil
                pickedMonogram = ""
                showEmojiPicker = false
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .sheet(isPresented: $showMonogramPicker) {
            MonogramPickerView(selectedMonogram: $pickedMonogram, color: $monogramColor)
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
                .background(
                    RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                        .fill(CardStyle.backgroundColor)
                        .shadow(color: CardStyle.shadowColor, radius: CardStyle.shadowRadius, y: CardStyle.shadowYOffset)
                        .overlay(
                            RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                                .stroke(CardStyle.borderColor, lineWidth: 0.7)
                        )
                )
                .padding(.top, CardStyle.verticalPadding)
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
                .background(
                    RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                        .fill(CardStyle.backgroundColor)
                        .shadow(color: CardStyle.shadowColor, radius: CardStyle.shadowRadius, y: CardStyle.shadowYOffset)
                        .overlay(
                            RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                                .stroke(CardStyle.borderColor, lineWidth: 0.7)
                        )
                )
                .padding(.top, CardStyle.verticalPadding)
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
                .background(
                    RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                        .fill(CardStyle.backgroundColor)
                        .shadow(color: CardStyle.shadowColor, radius: CardStyle.shadowRadius, y: CardStyle.shadowYOffset)
                        .overlay(
                            RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                                .stroke(CardStyle.borderColor, lineWidth: 0.7)
                        )
                )
                .padding(.top, CardStyle.verticalPadding)
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
                .background(
                    RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                        .fill(CardStyle.backgroundColor)
                        .shadow(color: CardStyle.shadowColor, radius: CardStyle.shadowRadius, y: CardStyle.shadowYOffset)
                        .overlay(
                            RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                                .stroke(CardStyle.borderColor, lineWidth: 0.7)
                        )
                )
                .padding(.top, CardStyle.verticalPadding)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Header
    private func headerBlock(contact: Contact) -> some View {
        VStack(spacing: 10) {
            ContactAvatarHeaderView(
                contact: contact,
                pickedImage: pickedImage,
                pickedEmoji: pickedEmoji,
                headerHeight: 140,
                onTap: { showAvatarSheet = true }
            )
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
            // Тип отношений — бейдж под именем/фамилией, если есть
            if let relation = contact.relationType, !relation.isEmpty {
                Text(relation)
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
        .padding(.top, 20)
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
        .background(
            RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                .fill(CardStyle.backgroundColor)
                .shadow(color: CardStyle.shadowColor, radius: CardStyle.shadowRadius, y: CardStyle.shadowYOffset)
                .overlay(
                    RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                        .stroke(CardStyle.borderColor, lineWidth: 0.7)
                )
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - DescriptionBlock (удалён)

    // MARK: - ActionsPanel (кнопки генерации удалены)
    private func actionsPanel(contact: Contact) -> some View {
        EmptyView()
    }

    // MARK: - Birthday Date Formatter

    // MARK: - Top Buttons ("Назад", "Править")
    private func topButtons(geo: GeometryProxy) -> some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.backward")
                    .frame(width: AppButtonStyle.Circular.diameter, height: AppButtonStyle.Circular.diameter)
                    .background(Circle().fill(AppButtonStyle.Circular.backgroundColor))
                    .shadow(color: AppButtonStyle.Circular.shadow, radius: AppButtonStyle.Circular.shadowRadius)
                    .foregroundColor(AppButtonStyle.Circular.iconColor)
                    .font(.system(size: AppButtonStyle.Circular.iconSize, weight: .semibold))
            }
            Spacer()
            Button(action: {
                if let contact = contact {
                    selectedContactForEdit = contact
                }
            }) {
                Image(systemName: "pencil")
                    .frame(width: AppButtonStyle.Circular.diameter, height: AppButtonStyle.Circular.diameter)
                    .background(Circle().fill(AppButtonStyle.Circular.backgroundColor))
                    .shadow(color: AppButtonStyle.Circular.shadow, radius: AppButtonStyle.Circular.shadowRadius)
                    .foregroundColor(AppButtonStyle.Circular.iconColor)
                    .font(.system(size: AppButtonStyle.Circular.iconSize, weight: .semibold))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, geo.safeAreaInsets.top + 8)
    }

    // Удалены handleOnAppear, handleGreetingDelete, handleCardDelete

}
