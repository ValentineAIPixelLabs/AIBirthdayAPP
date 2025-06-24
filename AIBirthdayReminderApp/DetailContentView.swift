//
//  DetailContentView.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 19.06.2025.
//

import Foundation
import SwiftUI

struct DetailContentView: View {
    let contact: Contact
    let geo: GeometryProxy
    @Binding var isEditing: Bool
    @Binding var showAvatarSheet: Bool
    @Binding var showImagePicker: Bool
    @Binding var showCameraPicker: Bool
    @Binding var showEmojiPicker: Bool
    @Binding var showMonogramPicker: Bool
    @Binding var pickedEmoji: String?
    @Binding var pickedMonogram: String?
    @Binding var monogramColor: Color
    @Binding var pickedImage: UIImage?
    @Binding var showGreetingSheet: Bool
    @Binding var showGreetingsHistory: Bool
    @Binding var showCardSheet: Bool
    @Binding var showCardsHistory: Bool
    @Binding var showCardError: Bool
    @Binding var errorMessage: String?
    @Binding var showDeleteConfirmation: Bool
    @Binding var generatedGreeting: String
    @Binding var generatedGreetings: [String]
    @Binding var generatedCardURL: URL?
    @Binding var generatedCardURLs: [URL]
    // добавь сюда остальные необходимые @Binding параметры

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let birthday = contact.birthday {
                BirthdayBlockView(birthday: birthday)
            } else {
                Text("Дата рождения не указана")
                    .foregroundColor(.gray)
                    .italic()
            }
            
            
            // Actions Section
            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 4) {
                    Button(action: { showGreetingSheet = true }) {
                        Text("Генерация поздравления")
                    }
                    Text("Генерация поздравления")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(Color.red.opacity(0.3))
                }
                VStack(spacing: 4) {
                    Button(action: { showGreetingsHistory = true }) {
                        Text("История поздравлений")
                    }
                    Text("История поздравлений")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(Color.red.opacity(0.3))
                }
                VStack(spacing: 4) {
                    Button(action: { showCardSheet = true }) {
                        Text("Генерация открытки")
                    }
                    Text("Генерация открытки")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(Color.red.opacity(0.3))
                }
                VStack(spacing: 4) {
                    Button(action: { showCardsHistory = true }) {
                        Text("История открыток")
                    }
                    Text("История открыток")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(Color.red.opacity(0.3))
                }
            }
            .padding(.horizontal)
            
            // Avatar Section
            VStack(spacing: 12) {
                Button(action: {
                    showAvatarSheet = true
                }) {
                    Text("Change Avatar")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                if isEditing {
                    Button(action: {
                        showEmojiPicker = true
                    }) {
                        Text("Pick Emoji")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        showMonogramPicker = true
                    }) {
                        Text("Pick Monogram")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        showImagePicker = true
                    }) {
                        Text("Choose Image")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        showCameraPicker = true
                    }) {
                        Text("Take Photo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
            
            // Error display
            if showCardError, let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding(.top)
    }
}
