//
//  HolidayCongratsCardView.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 19.07.2025.
//

import SwiftUI
    //import CardHistoryStore

struct HolidayCongratsCardView: View {
    let holiday: Holiday
    @ObservedObject var vm: ContactsViewModel

    @State private var cardHistory: [UIImage] = []
    @State private var congratsHistory: [String] = []
    @State private var showCongratsActionSheet = false
    @State private var showContactPicker = false
    @State private var selectedCard: UIImage?
    @State private var isGenerating = false
    @State private var isShowingCardPopup = false

    var body: some View {
        ZStack {
            AppBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                VStack(spacing: 16) {
                    holidayBlock

                    generateButton

                    if cardHistory.isEmpty {
                        Text("Нет открыток")
                            .font(.body.weight(.medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                            .padding(.vertical, 32)
                            .multilineTextAlignment(.center)
                    } else {
                        cardHistoryScroll
                            .padding(.top, 24)
                    }
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .onAppear {
                cardHistory = CardHistoryStore.loadHistory(for: holiday.id.uuidString)
                congratsHistory = CardHistoryStore.loadCongratsHistory(for: holiday.id.uuidString)
            }
        }
        .confirmationDialog(
            "Выберите тип открытки",
            isPresented: $showCongratsActionSheet,
            titleVisibility: .visible
        ) {
            Button("Общая открытка") {
                generateCard(for: nil)
            }
            Button("Для конкретного человека…") {
                showContactPicker = true
            }
            Button("Отмена", role: .cancel) {}
        }
        .sheet(isPresented: $showContactPicker) {
            ContactSelectSheetView(vm: vm) { contact in
                generateCard(for: contact)
            }
        }
        .sheet(isPresented: $isShowingCardPopup) {
            if let card = selectedCard {
                CardResultPopup(
                    image: card,
                    onCopy: { copyImage(card) },
                    onShare: { shareImage(card) },
                    onSave: { saveImage(card) },
                    onClose: { isShowingCardPopup = false }
                )
                .transition(.opacity)
                .animation(.easeInOut, value: isShowingCardPopup)
            }
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.backward")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(.accentColor)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.14))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.07), radius: 2)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Holiday Info Block
    private var holidayBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Праздник: \(holiday.title)")
                .font(.headline)
                .foregroundColor(.primary)

            Text(holiday.date.formatted(date: .long, time: .omitted))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(.regularMaterial)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.07), radius: 4, x: 0, y: 2)
    }

    // MARK: - Generate Button
    private var generateButton: some View {
        Button {
            showCongratsActionSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                Text("Сгенерировать открытку")
            }
            .font(.body.weight(.semibold))
            .foregroundColor(.white)
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .background(Color.accentColor)
            .cornerRadius(16)
        }
        .disabled(isGenerating)
    }

    // MARK: - Card History Scroll
    private var cardHistoryScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(cardHistory, id: \.self) { card in
                    Button {
                        selectedCard = card
                        isShowingCardPopup = true
                    } label: {
                        Image(uiImage: card)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 110, height: 148)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.09), radius: 5, x: 0, y: 2)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button {
                            copyImage(card)
                        } label: {
                            Label("Копировать", systemImage: "doc.on.doc")
                        }
                        Button {
                            shareImage(card)
                        } label: {
                            Label("Поделиться", systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive) {
                            deleteCard(card)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Генерация открытки
    private func generateCard(for contact: Contact?) {
        isGenerating = true
        // Сохраняем демо-текстовое поздравление
        let demoCongrats = "С праздником! Желаю счастья, здоровья и ярких моментов!"
        CardHistoryStore.addCongrats(demoCongrats, for: holiday.id.uuidString)
        congratsHistory = CardHistoryStore.loadCongratsHistory(for: holiday.id.uuidString)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let demoImage = UIImage(systemName: "gift") {
                cardHistory.insert(demoImage, at: 0)
                CardHistoryStore.saveHistory(cardHistory, for: holiday.id.uuidString)
            }
            isGenerating = false
        }
    }

    // MARK: - Копирование изображения в буфер
    private func copyImage(_ image: UIImage) {
        UIPasteboard.general.image = image
    }

    // MARK: - Поделиться изображением
    private func shareImage(_ image: UIImage) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        rootVC.present(activityVC, animated: true)
    }

    // MARK: - Сохранить изображение в фотоальбом
    private func saveImage(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    // MARK: - Удаление открытки из истории
    private func deleteCard(_ card: UIImage) {
        if let index = cardHistory.firstIndex(of: card) {
            cardHistory.remove(at: index)
            CardHistoryStore.saveHistory(cardHistory, for: holiday.id.uuidString)
            if selectedCard == card {
                selectedCard = nil
                isShowingCardPopup = false
            }
        }
    }

    // MARK: - Навигация назад
    @Environment(\.dismiss) private var dismiss
}
