import SwiftUI

struct NotificationSettingsView: View {
    @Binding var settings: NotificationSettings
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            Toggle("Включить напоминания", isOn: $settings.enabled)
            Section(header: Text("За сколько дней напоминать")) {
                ForEach([7, 1, 0], id: \.self) { days in
                    Toggle(daysLabel(days), isOn: Binding(
                        get: { settings.daysBefore.contains(days) },
                        set: { value in
                            if value {
                                settings.daysBefore.append(days)
                            } else {
                                settings.daysBefore.removeAll { $0 == days }
                            }
                        }
                    ))
                }
            }
            Section(header: Text("Время напоминания")) {
                DatePicker(
                    "Время",
                    selection: Binding(
                        get: { timeToDate(settings.hour, settings.minute) },
                        set: { newValue in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            settings.hour = comps.hour ?? 9
                            settings.minute = comps.minute ?? 0
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Сохранить") {
                    dismiss()
                }
            }
        }
        .navigationTitle("Напоминания")
    }

    private func daysLabel(_ days: Int) -> String {
        switch days {
        case 0: return "В сам день"
        case 1: return "За день"
        case 7: return "За неделю"
        default: return "За \(days) дней"
        }
    }

    private func timeToDate(_ hour: Int, _ minute: Int) -> Date {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? Date()
    }
}
