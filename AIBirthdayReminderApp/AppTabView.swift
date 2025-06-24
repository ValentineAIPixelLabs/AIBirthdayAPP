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

            // Вкладка "Праздники" (заглушка)
            NavigationStack {
                VStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 48))
                        .padding(.bottom, 16)
                    Text("Праздники скоро появятся")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
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
        .background(.ultraThinMaterial) // Liquid Glass style!
        .preferredColorScheme(
            vm.colorScheme == .system ? nil :
            (vm.colorScheme == .light ? .light : .dark)
        )
    }
}
