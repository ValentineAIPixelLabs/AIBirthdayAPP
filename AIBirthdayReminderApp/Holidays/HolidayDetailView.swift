import SwiftUI

// MARK: - Localization helpers (file-local)
private func appLocale() -> Locale {
    if let code = UserDefaults.standard.string(forKey: "app.language.code") { return Locale(identifier: code) }
    if let code = Bundle.main.preferredLocalizations.first { return Locale(identifier: code) }
    return .current
}
private func appBundle() -> Bundle {
    if let code = UserDefaults.standard.string(forKey: "app.language.code"),
       let path = Bundle.main.path(forResource: code, ofType: "lproj"),
       let bundle = Bundle(path: path) { return bundle }
    return .main
}
private func localizedDate(_ date: Date) -> String {
    let df = DateFormatter()
    df.locale = appLocale()
    df.setLocalizedDateFormatFromTemplate("d MMMM y")
    return df.string(from: date)
}

private func formattedHolidayDate(_ holiday: Holiday) -> String {
    let calendar = Calendar.current
    var comps = calendar.dateComponents([.day, .month], from: holiday.date)
    let df = DateFormatter()
    df.locale = appLocale()
    if let y = holiday.year {
        comps.year = y
        let date = calendar.date(from: comps) ?? holiday.date
        df.setLocalizedDateFormatFromTemplate("d MMMM y")
        return df.string(from: date)
    } else {
        // Показать только день и месяц, без года
        df.setLocalizedDateFormatFromTemplate("d MMMM")
        return df.string(from: holiday.date)
    }
}

@MainActor struct HolidayDetailView: View {
    let holiday: Holiday
    @ObservedObject var vm: HolidaysViewModel
    @EnvironmentObject var contactsVM: ContactsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showEditHolidayView = false
    @State private var navigateToEdit = false
    @State private var showCongratsSheet = false
    @State private var isCongratsActive = false
    @State private var selectedCongratsMode: String? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AppBackground()
                
                ScrollView {
                    VStack(spacing: EditorTheme.detailHeaderSpacing) {
                        // Аватар (централизованный AvatarKit) — дефолт как в контактах: монограмма по первой букве
                        let trimmedTitle = holiday.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let avatarSource: AvatarSource = {
                            if let e = holiday.icon?.trimmingCharacters(in: .whitespacesAndNewlines), !e.isEmpty {
                                return .emoji(e)
                            } else {
                                let initial = trimmedTitle.first.map { String($0).uppercased() } ?? "?"
                                return .monogram(initial)
                            }
                        }()
                        AppAvatarView(
                            source: avatarSource,
                            shape: .circle,
                            size: .headerXL
                        )
                        
                        // Название праздника — как имя в ContactDetailView (без второй строки)
                        Text(holiday.title)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        // Карточки даты и типа
                        VStack(spacing: 12) {
                            // Карточка даты
                            HStack(alignment: .top, spacing: CardStyle.Detail.spacing) {
                                Image(systemName: "gift.fill")
                                    .foregroundColor(.pink)
                                    .font(.system(size: CardStyle.Detail.iconSize))

                                let prefix = String(localized: "holiday.date.prefix", defaultValue: "Дата праздника", bundle: appBundle(), locale: appLocale())
                                let dateText = formattedHolidayDate(holiday)
                                Text("\(prefix): \(dateText)")
                                    .font(CardStyle.Detail.font)
                                    .foregroundColor(.primary)

                                Spacer()
                            }
                            .padding(.horizontal, CardStyle.Detail.innerHorizontalPadding)
                            .padding(.vertical, CardStyle.Detail.verticalPadding)
                            .cardBackground()

                            // Карточка типа
                            HStack(alignment: .top, spacing: CardStyle.Detail.spacing) {
                                Image(systemName: "tag.fill")
                                    .foregroundColor(.indigo)
                                    .font(.system(size: CardStyle.Detail.iconSize))

                                Text(holiday.type.title)
                                    .font(CardStyle.Detail.font)
                                    .foregroundColor(.primary)

                                Spacer()
                            }
                            .padding(.horizontal, CardStyle.Detail.innerHorizontalPadding)
                            .padding(.vertical, CardStyle.Detail.verticalPadding)
                            .cardBackground()
                        }
                        
                        CongratulateButton {
                            showCongratsSheet = true
                        }
                        .padding(.top, 6)
                    }
                    .frame(maxWidth: EditorTheme.detailMaxWidth)
                    .padding(.horizontal, EditorTheme.detailHorizontalPadding)
                    .padding(.top, EditorTheme.detailHeaderTop)
                }
            }
        }
        .navigationDestination(isPresented: $navigateToEdit) {
            EditHolidayView(
                holiday: holiday,
                onSave: { updatedHoliday in
                    vm.updateHoliday(updatedHoliday)
                    navigateToEdit = false
                },
                onCancel: {
                    navigateToEdit = false
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    navigateToEdit = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .navigationDestination(isPresented: $isCongratsActive) {
            if let mode = selectedCongratsMode {
                if mode == "text" {
                    HolidayCongratsTextView(holiday: holiday, vm: contactsVM)
                } else {
                    HolidayCongratsCardView(holiday: holiday, vm: contactsVM)
                }
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $showCongratsSheet) {
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
}
