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

        var body: some View {
            VStack(spacing: 0) {
                // ... (верхняя панель и фильтры без изменений)
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
                    // ... (чипы-фильтры и поисковая строка без изменений)
                    // ...
                    // Поисковая строка и фильтры остаются такими же, как у тебя
                    // ...
                }

                if !filteredVisibleHolidays.isEmpty {
                    ScrollViewReader { scrollProxy in
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
                                            .padding(.leading, 20)
                                        ForEach(groupedHolidays[sectionKey] ?? [], id: \.id) { holiday in
                                            HolidayCardView(holiday: holiday, viewModel: viewModel, selectedHoliday: $selectedHoliday)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 20)
                                                .onTapGesture {
                                                    selectedHoliday = holiday
                                                }
                                        }
                                    }
                                }
                                // Divider() // Удаляем Divider перед кнопкой
                                // Кнопка показа скрытых праздников (новый стиль)
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        showHiddenSection.toggle()
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
                                    .background(Color(.systemGray6))
                                    .clipShape(Capsule())
                                    .shadow(color: Color.black.opacity(0.06), radius: 2, y: 1)
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 10)
                                // Скрытые праздники
                                if showHiddenSection {
                                    Group {
                                        // Добавляем идентификатор секции скрытых праздников
                                        EmptyView()
                                    }
                                    .id("hiddenHolidaysSection")
                                    if filteredHiddenHolidays.isEmpty {
                                        Text("Нет скрытых праздников")
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                            .padding(.top, 8)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                    } else {
                                        ForEach(filteredHiddenHolidays, id: \.id) { holiday in
                                            HolidayCardView(holiday: holiday, viewModel: viewModel, selectedHoliday: $selectedHoliday, isHidden: true)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 20)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 10)
                            .padding(.bottom, 60)
                        }
                        .id(viewModel.holidays.count)
                    }
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
    private struct HolidayCardView: View {
        let holiday: Holiday
        @ObservedObject var viewModel: HolidaysViewModel
        @Binding var selectedHoliday: Holiday?
        var isHidden: Bool = false
        @State private var isPressed = false

        var body: some View {
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
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.13), radius: 10, x: 0, y: 4)
            // .padding(.vertical, 4)
            .contextMenu {
                if isHidden {
                    Button {
                        viewModel.unhideHoliday(holiday)
                    } label: {
                        Label("Показать", systemImage: "eye")
                    }
                } else {
                    Button {
                        viewModel.hideHoliday(holiday)
                    } label: {
                        Label("Скрыть", systemImage: "eye")
                    }
                    Button {
                        selectedHoliday = holiday
                    } label: {
                        Label("Редактировать", systemImage: "pencil")
                    }
                }
            }
        }

        private func dateFormatted(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.setLocalizedDateFormatFromTemplate("d MMMM")
            return formatter.string(from: date)
        }
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
