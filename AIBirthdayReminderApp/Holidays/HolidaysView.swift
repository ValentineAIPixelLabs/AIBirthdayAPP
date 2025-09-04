import SwiftUI
import UIKit

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

enum HolidaySortMode: String, CaseIterable, Identifiable {
    case date = "По дате"
    case type = "По типу"
    var id: String { self.rawValue }
}

struct HolidaysView: View {
    @StateObject private var viewModel = HolidaysViewModel()
    
    @State private var showCalendarImport = false
    private let calendarImporter = HolidayCalendarImporter()
    @State private var isImporting = false
    @State private var calendarImportError: String? = nil
    @State private var sortMode: HolidaySortMode = .date
    @State private var selectedHoliday: Holiday? = nil
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppBackground()
                HolidayContent(
                    viewModel: viewModel,
                    sortMode: $sortMode,
                    selectedHoliday: $selectedHoliday,
                    isImporting: $isImporting,
                    calendarImportError: $calendarImportError,
                    calendarImporter: calendarImporter,
                    path: $path
                )
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct HolidayContent: View {

    // Localized month symbols (moved out of body to avoid type-checker ambiguity)
    private var localizedMonthSymbols: [String] {
        let df = DateFormatter()
        df.locale = appLocale()
        return df.standaloneMonthSymbols ?? []
    }

        // MARK: - Helpers split out of body to speed up type-checking
        // MARK: - YearMonth grouping helpers
        private struct YearMonth: Hashable {
            let year: Int
            let month: Int
        }

        private var next12Months: [YearMonth] {
            let cal = Calendar.current
            let now = Date()
            let startYear = cal.component(.year, from: now)
            let startMonth = cal.component(.month, from: now)
            return (0..<12).map { offset in
                var m = startMonth + offset
                var y = startYear
                while m > 12 {
                    m -= 12
                    y += 1
                }
                return YearMonth(year: y, month: m)
            }
        }

        private var monthsByYearMonth: [YearMonth: [Holiday]] {
            let cal = Calendar.current
            return Dictionary(grouping: filteredVisibleHolidays) { h in
                let next = h.nextOccurrence()
                let y = cal.component(.year, from: next)
                let m = cal.component(.month, from: next)
                return YearMonth(year: y, month: m)
            }
        }

        @ViewBuilder
        private func visibleHolidaysSections(monthSymbols: [String]) -> some View {
            let ymList: [YearMonth] = self.next12Months
            ForEach(ymList, id: \.self) { ym in
                if let holidays = monthsByYearMonth[ym], !holidays.isEmpty {
                    Section {
                        ForEach(holidays.sorted(by: { $0.nextOccurrence() < $1.nextOccurrence() }), id: \.id) { holiday in
                            holidayRow(holiday: holiday)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .padding(.bottom, CardStyle.cardSpacing)
                        }
                    } header: {
                        let idx: Int = ym.month - 1
                        let monthName: String = {
                            if idx >= 0 && idx < monthSymbols.count {
                                return monthSymbols[idx].capitalized(with: appLocale())
                            } else {
                                return String(localized: "month.unknown", bundle: appBundle(), locale: appLocale())
                            }
                        }()
                        let currentYear = Calendar.current.component(.year, from: Date())
                        let headerText: String = (ym.year == currentYear) ? monthName : "\(monthName) \(String(ym.year))"
                        Text(headerText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, CardStyle.listHorizontalPadding)
                            .padding(.top, 8)
                            .padding(.bottom, 6)
                    }
                    .listRowBackground(Color.clear)
                }
            }
        }



        @EnvironmentObject var contactsVM: ContactsViewModel
        @ObservedObject var viewModel: HolidaysViewModel
        @Binding var sortMode: HolidaySortMode
        @Binding var selectedHoliday: Holiday?
        @Binding var isImporting: Bool
        @Binding var calendarImportError: String?
        let calendarImporter: HolidayCalendarImporter
        @Binding var path: NavigationPath
        
        @State private var selectedFilter: String = "Все праздники"
        @State private var holidayToEdit: Holiday? = nil
        @State private var selectedHolidayForCongrats: Holiday? = nil
        @State private var showCongratsSheet: Bool = false
        @State private var holidayForCongratsSheet: Holiday? = nil
        @State private var selectedMode: String? = nil // "text" или "card"
        
        var holidayTypes: [String] {
            let types = Set(viewModel.holidays.map { $0.type.title })
            var allTypes = Array(types).sorted()
            allTypes.insert("Все праздники", at: 0)
            return allTypes
        }

        var filteredVisibleHolidays: [Holiday] {
            let baseFiltered = viewModel.searchText.isEmpty
                ? viewModel.holidays
                : viewModel.holidays.filter { !$0.title.isEmpty && $0.title.localizedCaseInsensitiveContains(viewModel.searchText) }
            if selectedFilter == "Все праздники" {
                return baseFiltered
            } else {
                return baseFiltered.filter { $0.type.title == selectedFilter }
            }
        }


        var groupedHolidays: [String: [Holiday]] {
            let formatter = DateFormatter()
            formatter.locale = appLocale()
            switch sortMode {
            case .date:
                formatter.setLocalizedDateFormatFromTemplate("LLLL")
                return Dictionary(grouping: filteredVisibleHolidays) { holiday in
                    formatter.string(from: holiday.date).capitalized(with: appLocale())
                }
            case .type:
                return Dictionary(grouping: filteredVisibleHolidays) { holiday in
                    holiday.type.title
                }
            }
        }

        // MARK: - Months sorting/grouping helpers
        private var sortedMonths: [Int] {
            let now = Date()
            let calendar = Calendar.current
            let currentMonth = calendar.component(.month, from: now)
            let monthsWithHolidays = Set(filteredVisibleHolidays.map { calendar.component(.month, from: $0.date) }).sorted()
            var result: [Int] = []
            if let startMonth = monthsWithHolidays.first(where: { $0 >= currentMonth }) ?? monthsWithHolidays.first {
                result.append(contentsOf: monthsWithHolidays.filter { $0 >= startMonth })
                result.append(contentsOf: monthsWithHolidays.filter { $0 < startMonth })
            }
            return result
        }

        private var monthsDict: [Int: [Holiday]] {
            let calendar = Calendar.current
            return Dictionary(grouping: filteredVisibleHolidays) { calendar.component(.month, from: $0.date) }
        }
        
        func colorForType(_ type: HolidayType) -> Color {
            switch type {
            case .official:
                return .blue
            case .professional:
                return .green
            case .personal:
                return .purple
            case .religious:
                return .orange
            case .other:
                return .gray
            }
        }
        
        @State private var isSelectionMode: Bool = false
        @State private var selectedHolidays: Set<UUID> = []
        @State private var showDeleteVisibleAlert: Bool = false
        @Environment(\.horizontalSizeClass) private var hSize

        // MARK: - Chip localization helpers (display-only)
        private func slugify(_ raw: String) -> String {
            var s = raw.folding(options: .diacriticInsensitive, locale: appLocale()).lowercased()
            let disallowed = CharacterSet.alphanumerics.inverted
            s = s.unicodeScalars.map { disallowed.contains($0) ? "_" : String($0) }.joined()
            while s.contains("__") { s = s.replacingOccurrences(of: "__", with: "_") }
            return s.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        }

        private func localizedChipTitle(for type: String) -> String {
            if type == "Все праздники" {
                return String(localized: "holidays.filter.all", bundle: appBundle(), locale: appLocale())
            }
            let key = "holidays.type." + slugify(type)
            let bundle = appBundle()
            return bundle.localizedString(forKey: key, value: type, table: "Localizable")
        }

        private func parseCongratsDestination(_ destination: String) -> (UUID, String)? {
            let prefix = "holiday_congrats_"
            guard destination.hasPrefix(prefix) else { return nil }
            let stripped = destination.dropFirst(prefix.count)
            guard let underscore = stripped.firstIndex(of: "_") else { return nil }
            let idString = String(stripped[..<underscore])
            let type = String(stripped[stripped.index(after: underscore)...]) // "text" or "card"
            guard let uuid = UUID(uuidString: idString) else { return nil }
            return (uuid, type)
        }

        private func parseHolidayDetail(_ destination: String) -> UUID? {
            let prefix = "holiday_detail_"
            guard destination.hasPrefix(prefix) else { return nil }
            let idString = String(destination.dropFirst(prefix.count))
            return UUID(uuidString: idString)
        }

        var body: some View {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                List {
                    // Фильтры как первая строка — как в «Контактах»: внутри Section
                    Section {
                        filterChips
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                    }
                    .listRowBackground(Color.clear)

                    // Список видимых праздников по месяцам
                    let monthSymbols: [String] = localizedMonthSymbols
                    if !filteredVisibleHolidays.isEmpty {
                        visibleHolidaysSections(monthSymbols: monthSymbols)
                    }


                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .appSearchable(text: $viewModel.searchText)
                .environment(\.defaultMinListHeaderHeight, 0)
                .overlay {
                    if filteredVisibleHolidays.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                                .foregroundColor(.secondary)
                            .padding(.bottom, CardStyle.cardSpacing)
                            Text("holidays.empty")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                }
            }
            .alert(Text("common.error"), isPresented: Binding(
                get: { calendarImportError != nil },
                set: { _ in calendarImportError = nil }
            )) {
                Button(String(localized: "common.ok", bundle: appBundle(), locale: appLocale()), role: .cancel) { }
            } message: {
                Text(calendarImportError ?? "")
            }
            .alert(Text("holiday.delete.title"), isPresented: $showDeleteVisibleAlert) {
                Button(String(localized: "common.cancel", bundle: appBundle(), locale: appLocale()), role: .cancel) { }
                Button(String(localized: "common.delete", bundle: appBundle(), locale: appLocale()), role: .destructive) {
                    for id in selectedHolidays {
                        if let holiday = viewModel.holidays.first(where: { $0.id == id }) {
                            viewModel.deleteHoliday(holiday)
                        }
                    }
                    selectedHolidays.removeAll()
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isSelectionMode = false
                    }
                }
            } message: {
                Text("holiday.delete.message")
            }
            .sheet(item: $holidayForCongratsSheet) { holiday in
                CongratulationActionSheet(
                    onGenerateText: {
                        holidayForCongratsSheet = nil
                        path.append("holiday_congrats_\(holiday.id.uuidString)_text")
                    },
                    onGenerateCard: {
                        holidayForCongratsSheet = nil
                        path.append("holiday_congrats_\(holiday.id.uuidString)_card")
                    }
                )
            }

            .navigationDestination(for: String.self) { destination in
                if destination == "holiday_add" {
                    AddHolidaysView(
                        isPresented: .init(
                            get: { true },
                            set: { newValue in
                                // Закрытие изнутри AddHolidaysView (isPresented = false) превращаем в pop
                                if newValue == false {
                                    if !path.isEmpty {
                                        path.removeLast()
                                    }
                                }
                            }
                        )
                    ) { holiday in
                        viewModel.addHoliday(holiday)
                        // Поп назад выполняется через isPresented=false внутри AddHolidaysView → биндинг превратит это в безопасный pop
                    }
                } else if let uuid = parseHolidayDetail(destination),
                          let holiday = viewModel.holidays.first(where: { $0.id == uuid }) {
                    HolidayDetailView(holiday: holiday, vm: viewModel)
                } else if let (uuid, type) = parseCongratsDestination(destination),
                          let holiday = viewModel.holidays.first(where: { $0.id == uuid }) {
                    if type == "text" {
                        HolidayCongratsTextView(holiday: holiday, vm: contactsVM)
                    } else {
                        HolidayCongratsCardView(holiday: holiday, vm: contactsVM)
                    }
                } else {
                    Text("route.unknown")
                }
            }
            .sheet(item: $holidayToEdit) { holiday in
                EditHolidayView(
                    holiday: holiday,
                    onSave: { updatedHoliday in
                        viewModel.updateHoliday(updatedHoliday)
                        holidayToEdit = nil
                    },
                    onCancel: {
                        holidayToEdit = nil
                    }
                )
            }
            .toolbar {
                // Leading: Edit menu / Done
                ToolbarItem(placement: .topBarLeading) {
                    if isSelectionMode {
                        Button("common.done") {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                isSelectionMode = false
                                selectedHolidays.removeAll()
                            }
                        }
                    } else {
                        Menu {
                            Button("holidays.toolbar.select") {
                                withAnimation(.easeInOut(duration: 0.16)) {
                                    isSelectionMode = true
                                    selectedHolidays.removeAll()
                                }
                            }
                            Button("holidays.toolbar.select.all") {
                                withAnimation(.easeInOut(duration: 0.16)) {
                                    isSelectionMode = true
                                    let allVisible = Set(filteredVisibleHolidays.map { $0.id })
                                    selectedHolidays = allVisible
                                }
                            }
                        } label: {
                            Text("contacts.toolbar.edit")
                        }
                        .accessibilityLabel(Text("contacts.toolbar.edit"))
                    }
                }

                // Trailing: Add or Hide
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelectionMode {
                        HStack(spacing: 16) {
                            Button(role: .destructive) {
                                showDeleteVisibleAlert = true
                            } label: {
                                Label("common.delete", systemImage: "trash")
                            }
                            .disabled(selectedHolidays.isEmpty)
                            .accessibilityLabel(Text("holidays.toolbar.delete.selected"))
                            .tint(selectedHolidays.isEmpty ? .secondary : .red)
                        }
                    } else {
                        Menu {
                            Button("holidays.add.manual", systemImage: "pencil") {
                                path.append("holiday_add")
                            }
                            Button("holidays.import.calendar", systemImage: "calendar.badge.plus") {
                                isImporting = true
                                calendarImporter.requestAccess { granted in
                                    if granted {
                                        calendarImporter.fetchHolidayEvents { importedHolidays in
                                            let newHolidays = importedHolidays.filter { imp in
                                                !viewModel.holidays.contains(where: { $0.title == imp.title && Calendar.current.isDate($0.date, inSameDayAs: imp.date) })
                                            }
                                            DispatchQueue.main.async {
                                                for holiday in newHolidays {
                                                    viewModel.addHoliday(holiday)
                                                }
                                                isImporting = false
                                            }
                                        }
                                    } else {
                                        DispatchQueue.main.async {
                                            calendarImportError = String(localized: "calendar.access.denied", bundle: appBundle(), locale: appLocale())
                                            isImporting = false
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .tint(.blue)
                        .accessibilityLabel(Text("holidays.add"))
                    }
                }
            }
        }



        private var filterChips: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: (hSize == .compact ? max(8, AppButtonStyle.FilterChip.spacing - 6) : AppButtonStyle.FilterChip.spacing)) {
                    ForEach(holidayTypes, id: \.self) { type in
                        Button(action: {
                            let gen = UIImpactFeedbackGenerator(style: .soft)
                            gen.impactOccurred()
                            selectedFilter = type
                        }) {
                            Text(localizedChipTitle(for: type))
                                .font(AppButtonStyle.FilterChip.font)
                                .lineLimit(1)
                                .minimumScaleFactor(0.88)
                                .foregroundColor(selectedFilter == type ? AppButtonStyle.FilterChip.selectedText : AppButtonStyle.FilterChip.unselectedText)
                                .padding(.horizontal, AppButtonStyle.FilterChip.horizontalPadding)
                                .padding(.vertical, AppButtonStyle.FilterChip.verticalPadding)
                                .background {
                                    if selectedFilter == type {
                                        Capsule().fill(AppButtonStyle.primaryFill())
                                            .overlay(
                                                Capsule().fill(AppButtonStyle.primaryGloss())
                                            )
                                    } else {
                                        Capsule().fill(AppButtonStyle.FilterChip.unselectedMaterial)
                                    }
                                }
                                .overlay(
                                    Capsule()
                                        .stroke(AppButtonStyle.primaryStroke(), lineWidth: 0.8)
                                        .opacity(selectedFilter == type ? 1 : 0)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                        .opacity(selectedFilter == type ? 0 : 1)
                                )
                                .shadow(
                                    color: selectedFilter == type ? AppButtonStyle.FilterChip.selectedShadow : AppButtonStyle.FilterChip.unselectedShadow,
                                    radius: AppButtonStyle.FilterChip.shadowRadius,
                                    y: AppButtonStyle.FilterChip.shadowYOffset
                                )
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(FilterChipButtonStyle.Press())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, AppHeaderStyle.filterChipsBottomPadding)
                .padding(.top, 0)
            }
        }

        // holidaysLists больше не нужен, логика перенесена в body

        // monthSection больше не нужен, секции строятся через groupedHolidays

        @ViewBuilder
        private func holidayRow(holiday: Holiday) -> some View {
            HStack(alignment: .center, spacing: 0) {
                if isSelectionMode {
                    Button(action: {
                        if selectedHolidays.contains(holiday.id) {
                            selectedHolidays.remove(holiday.id)
                        } else {
                            selectedHolidays.insert(holiday.id)
                        }
                    }) {
                        Image(systemName: selectedHolidays.contains(holiday.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedHolidays.contains(holiday.id) ? .accentColor : .secondary)
                            .font(.system(size: 28))
                            .padding(.trailing, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                HolidayCardView(
                    holiday: holiday,
                    viewModel: viewModel,
                    selectedHoliday: $selectedHoliday,
                    selectedHolidayForCongrats: $selectedHolidayForCongrats,
                    showCongratsSheet: $showCongratsSheet,
                    holidayForCongratsSheet: $holidayForCongratsSheet,
                    isHidden: false,
                    onEdit: { holiday in
                        holidayToEdit = holiday
                    },
                    isSelectionMode: isSelectionMode,
                    onSelection: {
                        if isSelectionMode {
                            if selectedHolidays.contains(holiday.id) {
                                selectedHolidays.remove(holiday.id)
                            } else {
                                selectedHolidays.insert(holiday.id)
                            }
                        } else {
                            path.append("holiday_detail_\(holiday.id.uuidString)")
                        }
                    }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scaleEffect(isSelectionMode && selectedHolidays.contains(holiday.id) ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.17), value: isSelectionMode)
            .onLongPressGesture(minimumDuration: 0.38) {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                withAnimation(.easeInOut(duration: 0.16)) {
                    isSelectionMode = true
                    selectedHolidays.insert(holiday.id)
                }
            }
            .padding(.horizontal, CardStyle.listHorizontalPadding)
            .listRowBackground(Color.clear)
        }


}


private struct HolidayCardView: View {
    let holiday: Holiday
    @ObservedObject var viewModel: HolidaysViewModel
    @Binding var selectedHoliday: Holiday?
    @Binding var selectedHolidayForCongrats: Holiday?
    @Binding var showCongratsSheet: Bool
    @Binding var holidayForCongratsSheet: Holiday?
    var isHidden: Bool = false
    var onEdit: ((Holiday) -> Void)? = nil
    // New: support selection mode and tap handler
    var isSelectionMode: Bool = false
    var onSelection: (() -> Void)? = nil
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                // AvatarKit-based avatar with fallback to monogram (first letter of title)
                let trimmedTitle = holiday.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let avatarSource: AvatarSource = {
                    if let e = holiday.icon?.trimmingCharacters(in: .whitespacesAndNewlines), !e.isEmpty {
                        return .emoji(e)
                    } else {
                        let initial = trimmedTitle.first.map { String($0).uppercased() } ?? "?"
                        return .monogram(initial)
                    }
                }()
                AppAvatarView(source: avatarSource, shape: .circle, size: .listLarge)
                VStack(alignment: .leading, spacing: 6) {
                    Text(holiday.title)
                        .font(CardStyle.Title.font)
                        .foregroundColor(CardStyle.Title.color)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(dateFormatted(holiday.date))
                        .font(CardStyle.Subtitle.font)
                        .foregroundColor(CardStyle.Subtitle.color)
                        .opacity(0.96)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
            }
            .padding(.top, CardStyle.verticalPadding)
            .padding(.bottom, isHidden ? CardStyle.verticalPadding : 0)
            .padding(.horizontal, CardStyle.horizontalPadding)

            if !isHidden {
                CongratulateButton {
                    holidayForCongratsSheet = holiday
                }
                .font(CardStyle.ButtonTitle.font)
                .frame(maxWidth: .infinity)
                .padding(.top, CardStyle.CTA.topPadding)
                .padding(.horizontal, CardStyle.horizontalPadding)
                .padding(.bottom, CardStyle.CTA.bottomPadding)
            }
        }
        .contentShape(Rectangle())
        .frame(minHeight: isHidden ? 84 : nil, alignment: .center)
        .cardBackground()
        .overlay(
            Group {
                if isSelectionMode {
                    Color.clear
                        .contentShape(Rectangle())
                }
            }
        )
        .onTapGesture {
            if !isSelectionMode {
                onSelection?()
            }
        }
    }

    private func dateFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = appLocale()
        formatter.setLocalizedDateFormatFromTemplate("d MMMM")
        return formatter.string(from: date)
    }
    
    
    #Preview {
        HolidaysView()
    }
    
}



