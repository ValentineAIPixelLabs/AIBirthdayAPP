import SwiftUI

struct DeletedHolidaysView: View {
    @ObservedObject var vm: HolidaysViewModel
    @Environment(\.dismiss) var dismiss
    
    
    var body: some View {
        List {
            if vm.deletedHolidays.isEmpty {
                Text("Удалённых праздников нет")
                    .foregroundColor(.secondary)
            } else {
                ForEach(vm.deletedHolidays, id: \.id) { holiday in
                    HStack {
                        Text(holiday.title)
                        Spacer()
                        Button(action: {
                            vm.restoreHoliday(holiday)
                        }) {
                            Image(systemName: "arrow.uturn.backward.circle")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        let holiday = vm.deletedHolidays[index]
                        vm.removeDeletedHoliday(holiday)
                    }
                }
            }
        }
        .id(vm.deletedHolidays.count)
        .navigationTitle("Удалённые праздники")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Закрыть") {
                    dismiss()
                }
            }
        }
    }
}
