import SwiftUI
//import AppHeaderStyle
//import AppSearchBar
//import ButtonStyle

enum HolidaySortMode: String, CaseIterable, Identifiable {
    case date = "По дате"
    case type = "По типу"
    var id: String { self.rawValue }
}

struct HolidaysView: View {
    @StateObject private var viewModel = HolidaysViewModel()
    
    @State private var showAddHoliday = false
    @State private var showCalendarImport = false
    private let calendarImporter = HolidayCalendarImporter()
    @State private var isImporting = false
    @State private var calendarImportError: String? = nil
    @State private var sortMode: HolidaySortMode = .date
    @State private var selectedHoliday: Holiday? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                HolidayContent(
                    viewModel: viewModel,
                    sortMode: $sortMode,
                    selectedHoliday: $selectedHoliday,
                    showAddHoliday: $showAddHoliday,
                    isImporting: $isImporting,
                    calendarImportError: $calendarImportError,
                    calendarImporter: calendarImporter
                )
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct HolidayContent: View {
        @EnvironmentObject var contactsVM: ContactsViewModel
        @ObservedObject var viewModel: HolidaysViewModel
        @Binding var sortMode: HolidaySortMode
        @Binding var selectedHoliday: Holiday?
        @Binding var showAddHoliday: Bool
        @Binding var isImporting: Bool
        @Binding var calendarImportError: String?
        let calendarImporter: HolidayCalendarImporter
        
        @State private var searchText: String = ""
        @State private var isSearchActive: Bool = false
        @State private var selectedFilter: String = "Все праздники"
        @State private var holidayToEdit: Holiday? = nil
        @State private var selectedHolidayForCongrats: Holiday? = nil
        @State private var showCongratsSheet: Bool = false
        @State private var holidayForCongratsSheet: Holiday? = nil
        @State private var selectedMode: String? = nil // "text" или "card"
        @State private var showAddMenu = false
        
        var holidayTypes: [String] {
            let types = Set(viewModel.holidays.map { $0.type.title })
            var allTypes = Array(types).sorted()
            allTypes.insert("Все праздники", at: 0)
            return allTypes
        }

        var filteredVisibleHolidays: [Holiday] {
            let baseFiltered = searchText.isEmpty
                ? viewModel.holidays.filter { !viewModel.isHolidayHidden($0) }
                : viewModel.holidays.filter { !$0.title.isEmpty && $0.title.localizedCaseInsensitiveContains(searchText) && !viewModel.isHolidayHidden($0) }
            if selectedFilter == "Все праздники" {
                return baseFiltered
            } else {
                return baseFiltered.filter { $0.type.title == selectedFilter }
            }
        }

        var filteredHiddenHolidays: [Holiday] {
            let baseFiltered = viewModel.holidays.filter { viewModel.isHolidayHidden($0) }
            if selectedFilter == "Все праздники" {
                return baseFiltered
            } else {
                return baseFiltered.filter { $0.type.title == selectedFilter }
            }
        }

        var groupedHolidays: [String: [Holiday]] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            switch sortMode {
            case .date:
                formatter.dateFormat = "LLLL"
                return Dictionary(grouping: filteredVisibleHolidays) { holiday in
                    formatter.string(from: holiday.date).capitalized
                }
            case .type:
                return Dictionary(grouping: filteredVisibleHolidays) { holiday in
                    holiday.type.title
                }
            }
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
        
        @State private var showHiddenSection = false
        @State private var isSelectionMode: Bool = false
        @State private var selectedHolidays: Set<UUID> = []
        @State private var isRestoreMode: Bool = false
        @State private var selectedHiddenHolidays: Set<UUID> = []

        var body: some View {
            VStack(spacing: 0) {
                topBar
                searchBar
                filterChips
                holidaysLists
            }
            .frame(maxWidth: .infinity)
            .alert("Ошибка", isPresented: Binding(
                get: { calendarImportError != nil },
                set: { _ in calendarImportError = nil }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(calendarImportError ?? "")
            }
            .sheet(item: $holidayForCongratsSheet) { holiday in
                CongratulationActionSheet(
                    onGenerateText: {
                        selectedHolidayForCongrats = holiday
                        selectedMode = "text"
                        holidayForCongratsSheet = nil
                    },
                    onGenerateCard: {
                        selectedHolidayForCongrats = holiday
                        selectedMode = "card"
                        holidayForCongratsSheet = nil
                    }
                )
            }
            .sheet(isPresented: $showAddHoliday) {
                AddHolidaysView(isPresented: $showAddHoliday) { holiday in
                    viewModel.addHoliday(holiday)
                }
            }
            .confirmationDialog("Добавить праздник", isPresented: $showAddMenu, titleVisibility: .visible) {
                Button("Ввести праздник вручную", systemImage: "pencil") {
                    showAddHoliday = true
                }
                Button("Импортировать из календаря", systemImage: "calendar.badge.plus") {
                    isImporting = true
                    calendarImporter.requestAccess { granted in
                        if granted {
                            calendarImporter.fetchHolidayEvents { importedHolidays in
                                let newHolidays = importedHolidays.filter { imp in
                                    !viewModel.holidays.contains(where: { $0.title == imp.title && Calendar.current.isDate($0.date, inSameDayAs: imp.date) })
                                }
                                for holiday in newHolidays {
                                    viewModel.addHoliday(holiday)
                                }
                                isImporting = false
                            }
                        } else {
                            calendarImportError = "Нет доступа к календарю. Включите доступ в настройках."
                            isImporting = false
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedHoliday) { holiday in
                HolidayDetailView(holiday: holiday, vm: viewModel)
            }
            .navigationDestination(item: $holidayToEdit) { holiday in
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
            .navigationDestination(isPresented: Binding(
                get: { selectedHolidayForCongrats != nil && selectedMode != nil },
                set: { newValue in
                    if !newValue {
                        selectedHolidayForCongrats = nil
                        selectedMode = nil
                    }
                }
            )) {
                if let holiday = selectedHolidayForCongrats, let mode = selectedMode {
                    if mode == "text" {
                        HolidayCongratsTextView(holiday: holiday, vm: contactsVM)
                    } else {
                        HolidayCongratsCardView(holiday: holiday, vm: contactsVM)
                    }
                }
            }
        }

        private var topBar: some View {
            AppTopBar(
                title: "",
                leftButtons: [],
                rightButtons: [
                    AnyView(
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                // Закрываем секцию скрытых праздников и restore-режим при активации массового выбора
                                if showHiddenSection {
                                    showHiddenSection = false
                                    isRestoreMode = false
                                    selectedHiddenHolidays.removeAll()
                                }
                                isSelectionMode.toggle()
                                if !isSelectionMode {
                                    selectedHolidays.removeAll()
                                }
                            }
                        }) {
                            Image(systemName: isSelectionMode ? "xmark" : "eye.slash")
                        }
                        .frame(width: AppButtonStyle.Circular.diameter, height: AppButtonStyle.Circular.diameter)
                        .background(Circle().fill(AppButtonStyle.Circular.backgroundColor))
                        .shadow(color: AppButtonStyle.Circular.shadow, radius: AppButtonStyle.Circular.shadowRadius)
                        .foregroundColor(AppButtonStyle.Circular.iconColor)
                        .font(.system(size: AppButtonStyle.Circular.iconSize, weight: .semibold))
                        .accessibilityLabel(isSelectionMode ? "Выйти из режима выбора" : "Выбрать праздники")
                    ),
                    AnyView(
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSearchActive.toggle()
                                if !isSearchActive {
                                    searchText = ""
                                }
                            }
                        }) {
                            Image(systemName: "magnifyingglass")
                        }
                        .frame(width: AppButtonStyle.Circular.diameter, height: AppButtonStyle.Circular.diameter)
                        .background(Circle().fill(AppButtonStyle.Circular.backgroundColor))
                        .shadow(color: AppButtonStyle.Circular.shadow, radius: AppButtonStyle.Circular.shadowRadius)
                        .foregroundColor(AppButtonStyle.Circular.iconColor)
                        .font(.system(size: AppButtonStyle.Circular.iconSize, weight: .semibold))
                        .accessibilityLabel("Поиск")
                    ),
                    AnyView(
                        Button(action: {
                            showAddMenu = true
                        }) {
                            Image(systemName: "plus")
                        }
                        .frame(width: AppButtonStyle.Circular.diameter, height: AppButtonStyle.Circular.diameter)
                        .background(Circle().fill(AppButtonStyle.Circular.backgroundColor))
                        .shadow(color: AppButtonStyle.Circular.shadow, radius: AppButtonStyle.Circular.shadowRadius)
                        .foregroundColor(AppButtonStyle.Circular.iconColor)
                        .font(.system(size: AppButtonStyle.Circular.iconSize, weight: .semibold))
                        .accessibilityLabel("Добавить праздник")
                    )
                ]
            )
        }

        private var searchBar: some View {
            Group {
                if isSearchActive {
                    HStack {
                        AppSearchBar(text: $searchText)
                        Button(action: {
                            withAnimation(AppButtonStyle.SearchBar.animation) {
                                isSearchActive = false
                                searchText = ""
                            }
                        }) {
                            Text("Отмена")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }

        private var filterChips: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppButtonStyle.FilterChip.spacing) {
                    ForEach(holidayTypes, id: \.self) { type in
                        Button(action: {
                            selectedFilter = type
                        }) {
                            Text(type)
                                .font(AppButtonStyle.FilterChip.font)
                                .foregroundColor(selectedFilter == type ? AppButtonStyle.FilterChip.selectedText : AppButtonStyle.FilterChip.unselectedText)
                                .padding(.horizontal, AppButtonStyle.FilterChip.horizontalPadding)
                                .padding(.vertical, AppButtonStyle.FilterChip.verticalPadding)
                                .background(selectedFilter == type ? AppButtonStyle.FilterChip.selectedBackground : AppButtonStyle.FilterChip.unselectedBackground)
                                .clipShape(Capsule())
                                .shadow(
                                    color: selectedFilter == type ? AppButtonStyle.FilterChip.selectedShadow : AppButtonStyle.FilterChip.unselectedShadow,
                                    radius: AppButtonStyle.FilterChip.shadowRadius,
                                    y: AppButtonStyle.FilterChip.shadowYOffset
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, AppHeaderStyle.filterChipsBottomPadding)
                .padding(.top, AppHeaderStyle.filterChipsTopPadding)
            }
        }

        private var holidaysLists: some View {
            // Новый способ группировки и сортировки месяцев (по текущему, следующему и далее)
            let now = Date()
            let calendar = Calendar.current
            let currentMonth = calendar.component(.month, from: now)
            let monthsWithHolidays = Set(filteredVisibleHolidays.map { calendar.component(.month, from: $0.date) }).sorted()

            var sortedMonths: [Int] = []
            if let startMonth = monthsWithHolidays.first(where: { $0 >= currentMonth }) ?? monthsWithHolidays.first {
                sortedMonths.append(contentsOf: monthsWithHolidays.filter { $0 >= startMonth })
                sortedMonths.append(contentsOf: monthsWithHolidays.filter { $0 < startMonth })
            }

            let monthsDict = Dictionary(grouping: filteredVisibleHolidays) { calendar.component(.month, from: $0.date) }
            let monthSymbols = DateFormatter().standaloneMonthSymbols ?? []

            return Group {
                ZStack(alignment: .bottom) {
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 18) {
                                // Список видимых праздников, если есть
                                if !filteredVisibleHolidays.isEmpty {
                                    ForEach(sortedMonths, id: \.self) { month in
                                        if let holidays = monthsDict[month], !holidays.isEmpty {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text(monthSymbols.indices.contains(month-1) ? monthSymbols[month-1].capitalized : "Месяц")
                                                    .font(.callout).bold()
                                                    .foregroundColor(.secondary)
                                                    .padding(.top, AppHeaderStyle.monthLabelTopPadding)
                                                    .padding(.leading, 20)
                                                ForEach(holidays.sorted(by: { $0.date < $1.date }), id: \.id) { holiday in
                                                    holidayRow(holiday: holiday)
                                                }
                                            }
                                        }
                                    }
                                }
                                // Кнопка показа скрытых праздников: показывать всегда, если есть скрытые праздники
                                if !filteredHiddenHolidays.isEmpty {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.22)) {
                                            showHiddenSection.toggle()
                                            if showHiddenSection {
                                                isRestoreMode = true
                                                selectedHiddenHolidays.removeAll()
                                            } else {
                                                isRestoreMode = false
                                                selectedHiddenHolidays.removeAll()
                                            }
                                        }
                                        if showHiddenSection {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                                withAnimation {
                                                    scrollProxy.scrollTo("hiddenHolidaysSection", anchor: .top)
                                                }
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: showHiddenSection ? "eye.slash" : "eye")
                                                .font(.system(size: 19, weight: .semibold))
                                            Text(showHiddenSection ? "Скрыть" : "Отобразить скрытые праздники")
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .clipShape(Capsule())
                                        .shadow(color: Color.black.opacity(0.06), radius: 2, y: 1)
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.vertical, 10)
                                }
                                // Скрытые праздники
                                if showHiddenSection {
                                    Group {
                                        EmptyView()
                                    }
                                    .id("hiddenHolidaysSection")
                                    // Кнопка "Вернуть праздники" удалена, restore-режим теперь только через основную кнопку
                                    if filteredHiddenHolidays.isEmpty {
                                        Text("Нет скрытых праздников")
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                            .padding(.top, 8)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                    } else {
                                        ForEach(filteredHiddenHolidays, id: \.id) { holiday in
                                            HStack(alignment: .center, spacing: 0) {
                                                if isRestoreMode {
                                                    Button(action: {
                                                        if selectedHiddenHolidays.contains(holiday.id) {
                                                            selectedHiddenHolidays.remove(holiday.id)
                                                        } else {
                                                            selectedHiddenHolidays.insert(holiday.id)
                                                        }
                                                    }) {
                                                        Image(systemName: selectedHiddenHolidays.contains(holiday.id) ? "eye.circle.fill" : "eye.circle")
                                                            .foregroundColor(selectedHiddenHolidays.contains(holiday.id) ? .accentColor : .secondary)
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
                                                    isHidden: true,
                                                    onEdit: { holiday in
                                                        holidayToEdit = holiday
                                                    }
                                                )
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .padding(.horizontal, 20)
                                        }
                                    }
                                }
                                // Сообщение, если нет ни видимых, ни скрытых праздников
                                if filteredVisibleHolidays.isEmpty && filteredHiddenHolidays.isEmpty {
                                    VStack {
                                        Spacer()
                                        Image(systemName: "calendar.badge.clock")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 64, height: 64)
                                            .foregroundColor(.secondary)
                                            .padding(.bottom, 12)
                                        Text("Праздники скоро появятся")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                }
                            }
                            .padding(.top, AppHeaderStyle.listTopPaddingAfterChips)
                            .padding(.bottom, 110)
                        }
                        .id(viewModel.holidays.count)
                    }
                    if isSelectionMode {
                        selectionBottomBar
                    }
                    // Показывать restoreBottomBar только если открыта секция скрытых и активен режим восстановления
                    if showHiddenSection && isRestoreMode {
                        restoreBottomBar
                    }
                }
            }
        }

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
                    onEdit: { holiday in
                        holidayToEdit = holiday
                    }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture {
                    if isSelectionMode {
                        if selectedHolidays.contains(holiday.id) {
                            selectedHolidays.remove(holiday.id)
                        } else {
                            selectedHolidays.insert(holiday.id)
                        }
                    } else {
                        selectedHoliday = holiday
                    }
                }
            }
            .padding(.horizontal, 20)
        }

        private var selectionBottomBar: some View {
            VStack(spacing: 10) {
                Divider()
                HStack(spacing: 16) {
                    Button(action: {
                        // Скрыть выбранные
                        for id in selectedHolidays {
                            if let holiday = viewModel.holidays.first(where: { $0.id == id }) {
                                viewModel.hideHoliday(holiday)
                            }
                        }
                        selectedHolidays.removeAll()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSelectionMode = false
                        }
                    }) {
                        Text("Скрыть выбранные")
                            .font(.system(size: 17, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.88)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(selectedHolidays.isEmpty ? .gray : .white)
                            .background(
                                Capsule().fill(selectedHolidays.isEmpty ? Color.gray.opacity(0.13) : Color.accentColor)
                            )
                    }
                    .disabled(selectedHolidays.isEmpty)

                    Button(action: {
                        let visibleIds = Set(filteredVisibleHolidays.map { $0.id })
                        if selectedHolidays.intersection(visibleIds).count == visibleIds.count && !visibleIds.isEmpty {
                            // Снять все
                            selectedHolidays.subtract(visibleIds)
                        } else {
                            // Выделить все
                            selectedHolidays.formUnion(visibleIds)
                        }
                    }) {
                        let visibleIds = Set(filteredVisibleHolidays.map { $0.id })
                        let isAllSelected = selectedHolidays.intersection(visibleIds).count == visibleIds.count && !visibleIds.isEmpty
                        Text(isAllSelected ? "Снять все" : "Выделить все")
                            .font(.system(size: 17, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.88)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(.accentColor)
                            .background(
                                Capsule().fill(Color.accentColor.opacity(0.13))
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }

    private var restoreBottomBar: some View {
        VStack(spacing: 10) {
            Divider()
            HStack(spacing: 16) {
                Button(action: {
                    // Вернуть выбранные
                    for id in selectedHiddenHolidays {
                        if let holiday = viewModel.holidays.first(where: { $0.id == id }) {
                            viewModel.unhideHoliday(holiday)
                        }
                    }
                    selectedHiddenHolidays.removeAll()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isRestoreMode = false
                    }
                }) {
                    Text("Вернуть выбранные")
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(selectedHiddenHolidays.isEmpty ? .gray : .white)
                        .background(
                            Capsule().fill(selectedHiddenHolidays.isEmpty ? Color.gray.opacity(0.13) : Color.accentColor)
                        )
                }
                .disabled(selectedHiddenHolidays.isEmpty)

                Button(action: {
                    let hiddenIds = Set(filteredHiddenHolidays.map { $0.id })
                    if selectedHiddenHolidays.intersection(hiddenIds).count == hiddenIds.count && !hiddenIds.isEmpty {
                        // Снять все
                        selectedHiddenHolidays.subtract(hiddenIds)
                    } else {
                        // Выделить все
                        selectedHiddenHolidays.formUnion(hiddenIds)
                    }
                }) {
                    let hiddenIds = Set(filteredHiddenHolidays.map { $0.id })
                    let isAllSelected = selectedHiddenHolidays.intersection(hiddenIds).count == hiddenIds.count && !hiddenIds.isEmpty
                    Text(isAllSelected ? "Снять все" : "Выделить все")
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(.accentColor)
                        .background(
                            Capsule().fill(Color.accentColor.opacity(0.13))
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
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
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 64, height: 64)
                        .shadow(color: CardStyle.shadowColor, radius: 6, x: 0, y: 2)
                    Text((holiday.icon?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? holiday.icon!.trimmingCharacters(in: .whitespacesAndNewlines) : "🎉"))
                        .font(CardStyle.Title.font)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(holiday.title)
                        .font(CardStyle.Title.font)
                        .foregroundColor(CardStyle.Title.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
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
            .padding(.vertical, CardStyle.verticalPadding)
            .padding(.horizontal, CardStyle.horizontalPadding)

            Spacer(minLength: 20)
            if !isHidden {
                Button(action: {
                    holidayForCongratsSheet = holiday
                }) {
                    Label("Поздравить", systemImage: "sparkles")
                        .font(AppButtonStyle.Congratulate.font)
                        .foregroundColor(AppButtonStyle.Congratulate.textColor)
                        .padding(.horizontal, AppButtonStyle.Congratulate.horizontalPadding)
                        .padding(.vertical, AppButtonStyle.Congratulate.verticalPadding)
                        .background(
                            RoundedRectangle(cornerRadius: AppButtonStyle.Congratulate.cornerRadius, style: .continuous)
                                .fill(AppButtonStyle.Congratulate.backgroundColor)
                                .shadow(color: AppButtonStyle.Congratulate.shadow, radius: AppButtonStyle.Congratulate.shadowRadius, y: 2)
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, CardStyle.horizontalPadding)
                .padding(.bottom, 14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                .fill(CardStyle.backgroundColor)
                .shadow(color: CardStyle.shadowColor, radius: CardStyle.shadowRadius, y: CardStyle.shadowYOffset)
                .overlay(
                    RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                        .stroke(CardStyle.borderColor, lineWidth: 0.7)
                )
        )
    }

    private func dateFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.setLocalizedDateFormatFromTemplate("d MMMM")
        return formatter.string(from: date)
    }
    // colorForType и isSingleEmoji больше не используются
    
    #Preview {
        HolidaysView()
    }
    
}
