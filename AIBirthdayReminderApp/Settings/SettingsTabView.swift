import SwiftUI
@preconcurrency import Contacts
import ContactsUI

@MainActor struct SettingsTabView: View {
    @ObservedObject var vm: ContactsViewModel
    @EnvironmentObject var holidaysVM: HolidaysViewModel
    @EnvironmentObject var lang: LanguageManager
    @State private var showNotificationSettings = false
    @State private var showSubscription = false
    @State private var showSupport = false

    var body: some View {
        NavigationStack {
            List {

                Section(header: Text("settings.purchases.header")) {
                    Button {
                        showSubscription = true
                    } label: {
                        Label(LocalizedStringKey("settings.subscription"), systemImage: "star.circle")
                            .font(.headline)
                            .padding(.vertical, 8)
                    }
                    .foregroundColor(.primary)

                    Button {
                        showSupport = true
                    } label: {
                        Label(LocalizedStringKey("settings.support"), systemImage: "questionmark.circle")
                            .font(.headline)
                            .padding(.vertical, 8)
                    }
                    .foregroundColor(.primary)
                }

                Section {
                    Button {
                        showNotificationSettings = true
                    } label: {
                        Label("notifications.configure", systemImage: "bell.badge")
                            .font(.headline)
                            .padding(.vertical, 8)
                    }
                    .foregroundColor(.primary)
                } header: {
                    Text("notifications.title")
                }

                Section(header: Text("settings.language")) {
                    Picker("settings.language", selection: $lang.current) {
                        ForEach(AppLanguage.allCases) { l in
                            Text(l.displayName).tag(l)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("theme.title")) {
                    Picker("theme.picker", selection: $vm.colorScheme) {
                        ForEach(ContactsViewModel.AppColorScheme.allCases) { scheme in
                            Text(scheme.labelKey).tag(scheme)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle(Text("settings.title"))
            .id(lang.current)
            .background(AppBackground().ignoresSafeArea())
            .sheet(isPresented: $showNotificationSettings) {
                NavigationStack {
                    NotificationSettingsView(settings: $vm.globalNotificationSettings)
                }
            }
            .fullScreenCover(isPresented: $showSubscription) {
                PaywallView()
            }
            .sheet(isPresented: $showSupport) {
                SupportView()
            }
        }
    }

}

struct SystemContactsPickerViewMultiple: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    var onSelectContacts: ([CNContact]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {
        // no update needed
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: SystemContactsPickerViewMultiple
        init(_ parent: SystemContactsPickerViewMultiple) { self.parent = parent }

        // iOS supports selecting multiple contacts; this delegate will be called with an array if user selects several
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            DispatchQueue.main.async {
                self.parent.onSelectContacts(contacts)
                self.parent.presentationMode.wrappedValue.dismiss()
            }
        }

        // Fallback: single contact selected
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            DispatchQueue.main.async {
                self.parent.onSelectContacts([contact])
                self.parent.presentationMode.wrappedValue.dismiss()
            }
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            DispatchQueue.main.async {
                self.parent.presentationMode.wrappedValue.dismiss()
            }
        }
    }
}



struct SupportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: StoreKitManager
    @State private var isRequestingRefund = false

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("settings.support")) {
                    Text("support.body")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Section(footer: Text("support.refund.footer")) {
                    Button {
                        Task { await requestRefund() }
                    } label: {
                        HStack {
                            if isRequestingRefund {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            }
                            Text("support.refund.request")
                        }
                    }
                    .disabled(isRequestingRefund)
                }
            }
            .navigationTitle("support.nav.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }

    private func requestRefund() async {
        guard !isRequestingRefund else { return }
        isRequestingRefund = true
        defer { isRequestingRefund = false }
        await store.requestRefund()
    }
}
