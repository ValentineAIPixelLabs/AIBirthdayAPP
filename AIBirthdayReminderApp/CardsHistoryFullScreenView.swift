//
//  CardsHistoryFullScreenView.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 19.06.2025.
//


import UIKit
import SwiftUI

struct CardsHistoryFullScreenView: View {
    @Binding var isPresented: Bool
    let contactId: UUID
    @StateObject private var cardStore: CardHistoryStore

    init(isPresented: Binding<Bool>, contactId: UUID) {
        self._isPresented = isPresented
        self.contactId = contactId
        self._cardStore = StateObject(wrappedValue: CardHistoryStore(contactId: contactId))
    }
    
    @State private var showCopyAnimation: [Bool] = []
    @State private var isCopyAlertPresented: [Bool] = []
    
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

            if cardStore.savedCards.isEmpty {
                Text("Нет сохранённых открыток")
                    .foregroundColor(.secondary)
                    .font(.title2)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(Array(cardStore.savedCards.enumerated()), id: \.offset) { idx, url in
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(maxWidth: .infinity, maxHeight: 240)
                                case .success(let image):
                                    ZStack {
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .frame(maxWidth: min(350, UIScreen.main.bounds.width - 32), maxHeight: 340)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                            .background(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .fill(.ultraThinMaterial)
                                                    .shadow(color: Color.black.opacity(0.07), radius: 6, y: 2)
                                            )
                                        if showCopyAnimation.indices.contains(idx), showCopyAnimation[idx] {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 48))
                                                .scaleEffect(showCopyAnimation[idx] ? 1 : 0.2)
                                                .opacity(showCopyAnimation[idx] ? 1 : 0)
                                                .animation(.spring(), value: showCopyAnimation[idx])
                                        }
                                    }
                                    .contextMenu {
                                        Button("Скопировать") {
                                            downloadAndCopyImage(from: url, index: idx)
                                        }
                                        Button(role: .destructive) {
                                            cardStore.deleteCard(at: idx)
                                            if showCopyAnimation.indices.contains(idx) {
                                                showCopyAnimation.remove(at: idx)
                                            }
                                            if isCopyAlertPresented.indices.contains(idx) {
                                                isCopyAlertPresented.remove(at: idx)
                                            }
                                        } label: {
                                            Label("Удалить", systemImage: "trash")
                                        }
                                    }
                                .alert("Открытка скопирована", isPresented: Binding(
                                    get: { isCopyAlertPresented.indices.contains(idx) ? isCopyAlertPresented[idx] : false },
                                    set: { newValue in
                                        if isCopyAlertPresented.indices.contains(idx) {
                                            isCopyAlertPresented[idx] = newValue
                                        }
                                    }
                                )) {
                                    Button("OK", role: .cancel) { }
                                }
                                case .failure:
                                    Text("Ошибка загрузки")
                                        .foregroundColor(.red)
                                        .padding()
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                    .padding(.top, 64)
                }
            }
        }
        .overlay(alignment: .topLeading) {
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
        }
        .onAppear {
            cardStore.loadSavedCards()
            showCopyAnimation = Array(repeating: false, count: cardStore.savedCards.count)
            isCopyAlertPresented = Array(repeating: false, count: cardStore.savedCards.count)
        }
    }
    
    private func downloadAndCopyImage(from url: URL, index: Int) {
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                UIPasteboard.general.image = image
                DispatchQueue.main.async {
                    if showCopyAnimation.indices.contains(index) {
                        showCopyAnimation[index] = true
                    }
                    if isCopyAlertPresented.indices.contains(index) {
                        isCopyAlertPresented[index] = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        if showCopyAnimation.indices.contains(index) {
                            showCopyAnimation[index] = false
                        }
                    }
                }
            }
        }
        task.resume()
    }
}
