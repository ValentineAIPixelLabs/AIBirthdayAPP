import SwiftUI



enum HolidaySortMode: String, CaseIterable, Identifiable {
    case date = "По дате"
    case type = "По типу"
    var id: String { self.rawValue }
}

struct HolidaysView: View {
    @StateObject private var viewModel = HolidaysViewModel()
    
    @State private var showAddHoliday = false
    @State private var newTitle = ""
    @State private var newDate = Date()
    @State private var newType: HolidayType = .personal
    @State private var newIcon = ""
    // @State private var showRegionalPicker = false

    @State private var showCalendarImport = false
    private let calendarImporter = HolidayCalendarImporter()
    @State private var isImporting = false
    @State private var calendarImportError: String? = nil
    
    @State private var sortMode: HolidaySortMode = .date

    @State private var selectedHoliday: Holiday? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.18),
                        Color.purple.opacity(0.16),
                        Color.teal.opacity(0.14)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                HolidayContent(
                    viewModel: viewModel,
                    sortMode: $sortMode,
                    selectedHoliday: $selectedHoliday,
                    showAddHoliday: $showAddHoliday,
                    newTitle: $newTitle,
                    newDate: $newDate,
                    newType: $newType,
                    newIcon: $newIcon,
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

extension HolidaysView {
    private struct HolidayContent: View {
        @ObservedObject var viewModel: HolidaysViewModel
        @Binding var sortMode: HolidaySortMode
        @Binding var selectedHoliday: Holiday?
        // @Binding var showRegionalPicker: Bool
        @Binding var showAddHoliday: Bool
        @Binding var newTitle: String
        @Binding var newDate: Date
        @Binding var newType: HolidayType
        @Binding var newIcon: String
        @Binding var isImporting: Bool
        @Binding var calendarImportError: String?
        let calendarImporter: HolidayCalendarImporter
        
        @State private var searchText: String = ""
        @State private var selectedFilter: String = "Все праздники"
        @State private var isSearchActive: Bool = false
        
        var holidayTypes: [String] {
            let types = Set(viewModel.holidays.map { $0.type.title })
            var allTypes = Array(types).sorted()
            allTypes.insert("Все праздники", at: 0)
            return allTypes
        }
        
        var groupedHolidays: [String: [Holiday]] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            switch sortMode {
            case .date:
                formatter.dateFormat = "LLLL"
                return Dictionary(grouping: filteredHolidays) { holiday in
                    formatter.string(from: holiday.date).capitalized
                }
            case .type:
                return Dictionary(grouping: filteredHolidays) { holiday in
                    holiday.type.title
                }
            }
        }
        
        var filteredHolidays: [Holiday] {
            let baseFiltered = searchText.isEmpty ? viewModel.holidays : viewModel.holidays.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
            if selectedFilter == "Все праздники" {
                return baseFiltered
            } else {
                return baseFiltered.filter { $0.type.title == selectedFilter }
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
        
        var body: some View {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    Text("Праздники")
                        .font(.title2).bold()
                        .foregroundColor(.primary)
                    Spacer()
                    if isImporting {
                        ProgressView()
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1)
                            )
                    } else {
                        Button {
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
                        } label: {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.accentColor)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.3))
                                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1)
                                )
                        }
                    }
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isSearchActive.toggle()
                        }
                        if !isSearchActive {
                            searchText = ""
                        }
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.accentColor)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1)
                            )
                    }
                    .accessibilityLabel("Поиск")
                    Button(action: {
                        showAddHoliday = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.accentColor)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1)
                            )
                    }
                    .accessibilityLabel("Добавить праздник")
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                VStack(spacing: 0) {
                    // Чипы-фильтры
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(holidayTypes, id: \.self) { type in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.16)) {
                                        selectedFilter = type
                                    }
                                }) {
                                    Text(type)
                                        .font(.system(size: 15, weight: .medium))
                                        .textCase(.lowercase)
                                        .foregroundColor(selectedFilter == type ? .white : .accentColor)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(selectedFilter == type ? Color.accentColor : Color.white.opacity(0.26))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(selectedFilter == type ? Color.accentColor : Color.clear, lineWidth: 1.2)
                                        )
                                        .shadow(color: Color.black.opacity(selectedFilter == type ? 0.09 : 0.05), radius: selectedFilter == type ? 4 : 1, y: 1)
                                }
                                .buttonStyle(.plain)
                                .animation(.easeInOut(duration: 0.16), value: selectedFilter)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 3)
                        .padding(.top, 0)
                    }

                    // Поисковая строка
                    ZStack {
                        if isSearchActive {
                            HStack(spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.secondary)
                                    TextField("Поиск праздников", text: $searchText)
                                        .textFieldStyle(.plain)
                                        .disableAutocorrection(true)
                                        .autocapitalization(.none)
                                    if !searchText.isEmpty {
                                        Button(action: {
                                            searchText = ""
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.leading, 14)
                                .padding(.trailing, 10)
                                .background(
                                    Color.white.opacity(0.94)
                                        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 2)
                                )
                                .cornerRadius(16)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                                .animation(.easeInOut(duration: 0.18), value: isSearchActive)
                                Button("Отмена") {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        isSearchActive = false
                                        searchText = ""
                                    }
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }
                                .foregroundColor(.accentColor)
                                .font(.system(size: 17, weight: .regular))
                                .padding(.trailing, 12)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 2)
                        }
                    }
                    .frame(height: isSearchActive ? 44 : 0)
                    .animation(.easeInOut(duration: 0.18), value: isSearchActive)
                }

                if !filteredHolidays.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            ForEach(groupedHolidays.keys.sorted(by: { key1, key2 in
                                if sortMode == .date {
                                    let formatter = DateFormatter()
                                    formatter.locale = Locale(identifier: "ru_RU")
                                    formatter.dateFormat = "LLLL"
                                    guard let date1 = formatter.date(from: key1),
                                          let date2 = formatter.date(from: key2) else { return false }
                                    return date1 < date2
                                } else {
                                    return key1 < key2
                                }
                            }), id: \.self) { sectionKey in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(sectionKey)
                                        .font(.callout).bold()
                                        .foregroundColor(.secondary)
                                        .padding(.top, 10)
                                    ForEach(groupedHolidays[sectionKey] ?? [], id: \.id) { holiday in
                                        Button {
                                            selectedHoliday = holiday
                                        } label: {
                                            HolidayRow(holiday: holiday, viewModel: viewModel)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 14)
                            }
                        }
                        .padding(.top, 10)
                    }
                    .id(viewModel.holidays.count)
                } else {
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
            .padding(.top, 12)
            .frame(maxWidth: .infinity)
            .alert("Ошибка", isPresented: Binding(
                get: { calendarImportError != nil },
                set: { _ in calendarImportError = nil }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(calendarImportError ?? "")
            }
            .sheet(isPresented: $showAddHoliday) {
                NavigationStack {
                    Form {
                        Section(header: Text("Основное")) {
                            TextField("Название праздника", text: $newTitle)
                            DatePicker("Дата", selection: $newDate, displayedComponents: .date)
                            Picker("Тип", selection: $newType) {
                                ForEach(HolidayType.allCases, id: \.self) { type in
                                    Text(type.title).tag(type)
                                }
                            }
                            TextField("Иконка (эмодзи)", text: $newIcon)
                        }
                    }
                    .navigationTitle("Новый праздник")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Отмена") {
                                showAddHoliday = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Добавить") {
                                let holiday = Holiday(
                                    title: newTitle,
                                    date: newDate,
                                    type: newType,
                                    icon: newIcon.isEmpty ? nil : newIcon,
                                    isRegional: false,
                                    isCustom: true,
                                    relatedProfession: nil
                                )
                                viewModel.addHoliday(holiday)
                                // Сброс
                                newTitle = ""
                                newDate = Date()
                                newType = .personal
                                newIcon = ""
                                showAddHoliday = false
                            }.disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedHoliday) { holiday in
                HolidayDetailView(holiday: holiday)
            }
        }
    }
}

extension HolidaysView {
    struct HolidayRow: View {
        let holiday: Holiday
        @ObservedObject var viewModel: HolidaysViewModel
        var body: some View {
            HolidayCardView(holiday: holiday, viewModel: viewModel)
        }
    }
    
    /// Карточка праздника, визуально унифицирована с ContactCardView
    private struct HolidayCardView: View {
        let holiday: Holiday
        @ObservedObject var viewModel: HolidaysViewModel
        @State private var showDeleteConfirmation = false
        @State private var isPressed = false

        var body: some View {
            CardPresetView {
                HStack(alignment: .center, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.thinMaterial)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.18), lineWidth: 1.2)
                            )
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.13), radius: 10, x: 0, y: 4)
                            .frame(width: 64, height: 64)
                        if let icon = holiday.icon, !icon.isEmpty {
                            if isSingleEmoji(icon) {
                                Text(icon)
                                    .font(.system(size: 32))
                            } else {
                                Image(systemName: icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)
                                    .foregroundColor(colorForType(holiday.type))
                            }
                        } else {
                            Image(systemName: "calendar")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.red)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(holiday.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.88)
                        Text(dateFormatted(holiday.date))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .opacity(0.96)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Spacer()
                }
            }
            .scaleEffect(isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.2), value: isPressed)
            .onLongPressGesture(minimumDuration: 0.3, pressing: { pressing in
                if pressing {
                    isPressed = true
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isPressed = false
                    }
                }
            }, perform: {
                showDeleteConfirmation = true
            })
            .alert("Удалить праздник?", isPresented: $showDeleteConfirmation) {
                Button("Удалить", role: .destructive) {
                    viewModel.deleteHoliday(holiday)
                }
                Button("Отмена", role: .cancel) {}
            }
        }

        // Размеры для адаптивности
        private var avatarSize: CGFloat {
            UIDevice.current.userInterfaceIdiom == .pad ? 74 : 64
        }
        private var iconFontSize: CGFloat {
            UIDevice.current.userInterfaceIdiom == .pad ? 38 : 32
        }

        /// Возвращает первую букву первого слова заголовка
        private func initials(from title: String) -> String {
            title
                .components(separatedBy: .whitespacesAndNewlines)
                .first?
                .prefix(1)
                .uppercased() ?? ""
        }

        /// Форматирует дату в стиль "d MMMM" с локализацией
        private func dateFormatted(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.setLocalizedDateFormatFromTemplate("d MMMM")
            return formatter.string(from: date)
        }

        /// Возвращает цвет для типа праздника
        private func colorForType(_ type: HolidayType) -> Color {
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

        /// Проверяет, является ли строка одиночным emoji
        private func isSingleEmoji(_ string: String) -> Bool {
            let scalars = string.unicodeScalars
            return (scalars.count == 1 && scalars.first?.properties.isEmoji == true)
                || (scalars.count == 2 && scalars.allSatisfy { $0.properties.isEmoji })
        }
    }
}


#Preview {
    HolidaysView()
}
