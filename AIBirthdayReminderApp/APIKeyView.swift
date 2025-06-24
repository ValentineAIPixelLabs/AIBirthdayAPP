//
//  APIKeyView.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 19.06.2025.
//


import SwiftUI

struct APIKeyView: View {
    @AppStorage("openai_api_key") private var apiKey: String = ""
    @State private var tempKey: String = ""
    @State private var showSaved: Bool = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("OpenAI API ключ")) {
                    SecureField("Введите API ключ...", text: $tempKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                if showSaved {
                    Text("Ключ сохранён!").foregroundColor(.green)
                }
                Button("Сохранить") {
                    apiKey = tempKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    showSaved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showSaved = false
                        dismiss()
                    }
                }
                .disabled(tempKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationTitle("API ключ OpenAI")
            .onAppear {
                tempKey = apiKey
            }
        }
    }
}
