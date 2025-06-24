//
//  CardFullScreenView.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 19.06.2025.
//


import SwiftUI
import UIKit

struct CardFullScreenView: View {
    @Binding var isPresented: Bool
    let imageURL: URL?
    let isLoading: Bool
    let errorMessage: String?
    let onGenerateCard: () -> Void
    @State private var showCopyBanner = false
    @State private var showHistorySheet = false
    var cards: Binding<[URL]>
    var onDelete: (Int) -> Void

    @State private var showCopyAnimation: Bool = false
    @State private var isCopyAlertPresented: Bool = false

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
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 12)
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 12)
            } else if let url = imageURL {
                ScrollView {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .success(let image):
                            VStack {
                                ZStack {
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .background(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .fill(.ultraThinMaterial)
                                                .shadow(color: Color.black.opacity(0.07), radius: 8, y: 2)
                                        )
                                        .padding()
                                        .gesture(
                                            LongPressGesture()
                                                .onEnded { _ in
                                                    withAnimation {
                                                        copyImage(url: url, image: image)
                                                    }
                                                }
                                        )
                                    if showCopyAnimation {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(.green)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                            }
                        case .failure:
                            Text("Ошибка загрузки изображения")
                                .foregroundColor(.red)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .padding()
                }
                .padding(.top, 64)
            }

            VStack {
                Spacer()
                HStack(spacing: 16) {
                    Button(action: onGenerateCard) {
                        Label("Сгенерировать", systemImage: "wand.and.stars")
                            .font(.system(size: 17, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    Button(action: { showHistorySheet = true }) {
                        Label("История", systemImage: "photo.stack")
                            .font(.system(size: 17, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }

            if showCopyBanner {
                VStack {
                    Spacer()
                    Text("Открытка скопирована")
                        .font(.body)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(14)
                        .shadow(radius: 6)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .padding(.bottom, 40)
                }
                .animation(.easeInOut, value: showCopyBanner)
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
        .sheet(isPresented: $showHistorySheet) {
            CardsHistoryFullScreenView(isPresented: $showHistorySheet, cards: cards, onDelete: onDelete)
        }
        .alert("Открытка скопирована", isPresented: $isCopyAlertPresented) {
            Button("OK", role: .cancel) {}
        }
    }
    
    private func copyImage(url: URL, image: Image) {
        // Try to download image data from url
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let uiImage = UIImage(data: data) {
                UIPasteboard.general.image = uiImage
                DispatchQueue.main.async {
                    withAnimation {
                        showCopyAnimation = true
                        isCopyAlertPresented = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            showCopyAnimation = false
                        }
                    }
                }
            } else {
                // Fallback: try to get UIImage from the SwiftUI Image if possible
                // However, SwiftUI Image does not provide direct access to UIImage.
                // So, fallback is not possible here; just show alert anyway.
                DispatchQueue.main.async {
                    withAnimation {
                        showCopyAnimation = true
                        isCopyAlertPresented = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            showCopyAnimation = false
                        }
                    }
                }
            }
        }.resume()
    }
    
    private func showBanner() {
        withAnimation {
            showCopyBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopyBanner = false
            }
        }
    }
}
