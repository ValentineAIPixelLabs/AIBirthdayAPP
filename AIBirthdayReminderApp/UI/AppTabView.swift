import SwiftUI
import UIKit

private enum Tab: Hashable { case contacts, holidays, settings }

struct AppTabView: View {
    @StateObject var vm = ContactsViewModel()
    @State private var selection: Tab = .contacts
    
    var body: some View {
        TabView(selection: $selection) {
            // Вкладка "Подарок" — твой основной функционал
            NavigationStack {
                ContentView(vm: vm)
            }
            .tabItem {
                Label {
                    Text("tabs.contacts")
                } icon: {
                    Image(systemName: "gift.fill")
                        .symbolRenderingMode(.monochrome)
                        .imageScale(.medium)
                }
            }
            .tag(Tab.contacts)

            // Вкладка "Праздники"
            NavigationStack {
                HolidaysView()
            }
            .tabItem {
                Label {
                    Text("tabs.holidays")
                } icon: {
                    Image(systemName: "calendar.badge.clock")
                        .symbolRenderingMode(.monochrome)
                        .imageScale(.medium)
                }
            }
            .tag(Tab.holidays)

            // Вкладка "Настройки"
            NavigationStack {
                SettingsTabView(vm: vm)
            }
            .tabItem {
                Label {
                    Text("tabs.settings")
                } icon: {
                    Image(systemName: "gearshape")
                        .symbolRenderingMode(.monochrome)
                        .imageScale(.medium)
                }
            }
            .tag(Tab.settings)
        }
        .onChange(of: selection) { _ in
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
        }
        // После успешного входа с Apple переключаемся на вкладку с контактами
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignIn).receive(on: DispatchQueue.main)) { _ in
            selection = .contacts
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
