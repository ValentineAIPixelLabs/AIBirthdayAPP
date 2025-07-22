import SwiftUI

struct AppTabView: View {
    @StateObject var vm = ContactsViewModel()
    
    var body: some View {
        TabView {
            // Вкладка "Подарок" — твой основной функционал
            NavigationStack {
                ContentView(vm: vm)
            }
            .tabItem {
                Image(systemName: "gift.fill")
                Text("Контакты")
            }

            // Вкладка "Праздники"
            NavigationStack {
                HolidaysView()
            }
            .tabItem {
                Image(systemName: "calendar.badge.clock")
                Text("Праздники")
            }

            // Вкладка "Настройки"
            NavigationStack {
                SettingsTabView(vm: vm)
            }
            .tabItem {
                Image(systemName: "gearshape")
                Text("Настройки")
            }
        }
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .preferredColorScheme(
            vm.colorScheme == .system ? nil :
            (vm.colorScheme == .light ? .light : .dark)
        )
        .environmentObject(vm)
    }
}
