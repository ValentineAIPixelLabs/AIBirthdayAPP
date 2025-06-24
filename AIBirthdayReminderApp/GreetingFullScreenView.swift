//
//  GreetingFullScreenView.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 19.06.2025.
//

import SwiftUI

struct GreetingFullScreenView: View {
    @Binding var isPresented: Bool
    let greeting: String
    let greetings: [String]
    let onDelete: (Int) -> Void
    let onGenerate: () -> Void
    
    @State private var showHistorySheet = false
    @State private var isCopyAlertPresented = false

    var body: some View {
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

            VStack(alignment: .leading, spacing: 0) {
                // TopBar
                HStack {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        if !greeting.isEmpty {
                            Text(greeting)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: Color.black.opacity(0.07), radius: 6, y: 2)
                                )
                                .padding(.horizontal, 16)
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .contextMenu {
                                    Button("Скопировать") {
                                        UIPasteboard.general.string = greeting
                                        isCopyAlertPresented = true
                                    }
                                    Button(role: .destructive) {
                                        onDelete(0)
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 16)
                    .animation(.easeInOut, value: greeting)
                }
                .padding(.bottom, 0)

                HStack(spacing: 16) {
                    Button(action: onGenerate) {
                        Label("Сгенерировать", systemImage: "sparkles")
                            .font(.system(size: 17, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    Button(action: { showHistorySheet = true }) {
                        Label("История", systemImage: "list.bullet.rectangle")
                            .font(.system(size: 17, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .padding(.top, 0)
        }
        .sheet(isPresented: $showHistorySheet) {
            GreetingsHistoryFullScreenView(isPresented: $showHistorySheet, greetings: greetings, onDelete: onDelete)
        }
        .alert("Текст поздравления скопирован", isPresented: $isCopyAlertPresented) {
            Button("OK", role: .cancel) { }
        }
    }
}

// MARK: - Previews
struct GreetingFullScreenView_Previews: PreviewProvider {
    static var previews: some View {
        GreetingFullScreenView(
            isPresented: .constant(true),
            greeting: "Тестовое поздравление",
            greetings: [],
            onDelete: { _ in },
            onGenerate: {}
        )
    }
}
