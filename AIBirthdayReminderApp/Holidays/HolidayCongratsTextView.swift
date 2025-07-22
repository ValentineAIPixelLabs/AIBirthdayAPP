//
//  HolidayCongratsTextView.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 19.07.2025.
//

import SwiftUI

struct HolidayCongratsTextView: View {
    let holiday: Holiday
    @ObservedObject var vm: ContactsViewModel

    // История поздравлений по празднику (можно использовать UserDefaults или CoreData, как в ContactCongratsView)
    @State private var history: [String] = [] // замените тип, если у вас другая модель поздравления
    @State private var showCongratsActionSheet = false
    @State private var showContactPicker = false
    @State private var showShareSheet = false
    @State private var selectedCongrats: String?
    @State private var isGenerating = false
    @State private var showCongratsPopup = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView {
                    VStack(spacing: 20) {
                        holidayCard

                        generateButton

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Поздравления")
                                .font(.headline)
                                .bold()
                                .padding(.top, 16)

                            if history.isEmpty {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.3))
                                    .frame(minHeight: 46)
                                    .overlay(
                                        Text("Нет поздравлений")
                                            .foregroundColor(Color.gray)
                                            .font(.subheadline)
                                    )
                                    .padding(.bottom, 16)
                            } else {
                                ForEach(history, id: \.self) { congrats in
                                    Button(action: {
                                        selectedCongrats = congrats
                                        showCongratsPopup = true
                                    }) {
                                        Text(congrats)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                            .padding()
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(Color.white.opacity(0.3))
                                            )
                                    }
                                    .contextMenu {
                                        Button {
                                            UIPasteboard.general.string = congrats
                                        } label: {
                                            Label("Копировать", systemImage: "doc.on.doc")
                                        }
                                        Button {
                                            selectedCongrats = congrats
                                            showShareSheet = true
                                        } label: {
                                            Label("Поделиться", systemImage: "square.and.arrow.up")
                                        }
                                        Button(role: .destructive) {
                                            history.removeAll { $0 == congrats }
                                        } label: {
                                            Label("Удалить", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            congratsPopup
        }
        .navigationBarHidden(true)
        .confirmationDialog(
            "Выберите тип поздравления",
            isPresented: $showCongratsActionSheet,
            titleVisibility: .visible
        ) {
            Button("Общее поздравление") {
                generateCongrats(for: nil)
            }
            Button("Поздравить конкретного человека…") {
                showContactPicker = true
            }
            Button("Отмена", role: .cancel) {}
        }
        .sheet(isPresented: $showContactPicker) {
            ContactSelectSheetView(vm: vm) { contact in
                generateCongrats(for: contact)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let selectedCongrats = selectedCongrats {
                ActivityViewController(activityItems: [selectedCongrats])
            }
        }
    }

    // Popup поздравления (аналогично ContactCongratsView)
    @ViewBuilder
    private var congratsPopup: some View {
        if showCongratsPopup, let selectedCongrats = selectedCongrats {
            CongratsResultPopup(
                message: selectedCongrats,
                onCopy: {
                    UIPasteboard.general.string = selectedCongrats
                },
                onShare: {
                    showCongratsPopup = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showShareSheet = true
                    }
                },
                onClose: {
                    showCongratsPopup = false
                }
            )
            .transition(.opacity)
            .zIndex(100)
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack(spacing: 16) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: AppButtonStyle.Circular.iconSize, height: AppButtonStyle.Circular.iconSize)
                    .foregroundColor(AppButtonStyle.Circular.iconColor)
                    .frame(width: AppButtonStyle.Circular.diameter, height: AppButtonStyle.Circular.diameter)
                    .background(AppButtonStyle.Circular.backgroundColor)
                    .clipShape(Circle())
                    .shadow(color: AppButtonStyle.Circular.shadow, radius: AppButtonStyle.Circular.shadowRadius)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Holiday Card
    private var holidayCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Праздник: \(holiday.title)")
                .font(.headline)
                .bold()
                .foregroundColor(.primary)

            Text(holiday.date.formatted(date: .long, time: .omitted))
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.3))
        )
    }

    // MARK: - Generate Button
    private var generateButton: some View {
        Button(action: { showCongratsActionSheet = true }) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3)
                Text("Сгенерировать поздравление")
                    .font(.headline.bold())
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(isGenerating ? Color.gray : Color.blue)
            .cornerRadius(14)
        }
        .disabled(isGenerating)
    }

    // MARK: - Генерация поздравления
    private func generateCongrats(for contact: Contact?) {
        isGenerating = true
        // Здесь должен быть вызов AI-генерации поздравления (или своя логика)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
            let base = "Сгенерированное поздравление с праздником \(holiday.title)" + (contact != nil ? " для \(contact!.name)" : "")
            history.insert(base, at: 0)
            isGenerating = false
        })
    }
}
