import SwiftUI

struct BirthdayField: View {
    @Binding var birthday: Birthday?

    @State private var isExpanded = false
    @State private var tempDay: Int = Calendar.current.component(.day, from: Date())
    @State private var tempMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var tempYear: Int? = Calendar.current.component(.year, from: Date())

    let currentYear = Calendar.current.component(.year, from: Date())
    let minYear = 1900

    private var years: [Int?] {
        [nil] + (stride(from: currentYear, through: minYear, by: -1).map { Optional($0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Дата рождения")
                Spacer()
                Button(action: {
                    prepareTempValues()
                    isExpanded.toggle()
                }) {
                    Text(displayedDate())
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                prepareTempValues()
                isExpanded.toggle()
            }

            if isExpanded {
                HStack(spacing: 0) {
                    Picker("", selection: $tempDay) {
                        ForEach(1...daysIn(month: tempMonth, year: tempYear), id: \.self) {
                            Text("\($0)").tag($0)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 70)
                    .clipped()

                    Picker("", selection: $tempMonth) {
                        ForEach(1...12, id: \.self) {
                            Text(Self.russianMonthName($0)).tag($0)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Picker("", selection: Binding(
                        get: { tempYear ?? -1 },
                        set: { tempYear = $0 == -1 ? nil : $0 }
                    )) {
                        ForEach(years, id: \.self) { year in
                            if let year {
                                Text("\(year)").tag(year)
                            } else {
                                Text("—").tag(-1)
                            }
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 90)
                    .clipped()
                }
                .frame(height: 216)
                .onChange(of: tempMonth) {
                    adjustDay()
                    save()
                }
                .onChange(of: tempYear) {
                    adjustDay()
                    save()
                }
                .onChange(of: tempDay) {
                    save()
                }
            }
        }
        .padding(.vertical, 8)
        .animation(nil, value: isExpanded)
    }

    private func prepareTempValues() {
        if let b = birthday {
            if let day = b.day {
                tempDay = day
            }
            if let month = b.month {
                tempMonth = month
            }
            tempYear = b.year
        } else {
            let now = Date()
            let cal = Calendar.current
            tempDay = cal.component(.day, from: now)
            tempMonth = cal.component(.month, from: now)
            tempYear = cal.component(.year, from: now)
        }
    }

    private func save() {
        birthday = Birthday(day: tempDay, month: tempMonth, year: tempYear)
    }

    private func displayedDate() -> String {
        guard let b = birthday else { return "Указать" }
        guard let day = b.day, let month = b.month else { return "Указать" }
        let monthName = Self.russianMonthName(month)
        if let year = b.year {
            return String(format: "%02d %@ %d", day, monthName, year)
        } else {
            return String(format: "%02d %@", day, monthName)
        }
    }

    private func adjustDay() {
        let maxDay = daysIn(month: tempMonth, year: tempYear)
        if tempDay > maxDay {
            tempDay = maxDay
        }
    }

    private func daysIn(month: Int, year: Int?) -> Int {
        var comps = DateComponents()
        comps.month = month
        comps.year = year ?? 2020
        let calendar = Calendar.current
        return calendar.range(of: .day, in: .month, for: calendar.date(from: comps)!)?.count ?? 31
    }

    static func russianMonthName(_ month: Int) -> String {
        let months = [
            "января", "февраля", "марта", "апреля", "мая", "июня",
            "июля", "августа", "сентября", "октября", "ноября", "декабря"
        ]
        return (1...12).contains(month) ? months[month - 1] : ""
    }
    
    
}
