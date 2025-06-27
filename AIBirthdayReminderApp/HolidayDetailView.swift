//
//  HolidayDetailView.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 25.06.2025.
//

import SwiftUI
//import Holiday

struct HolidayDetailView: View {
    let holiday: Holiday
    
    @State private var generatedGreeting: String?
    @State private var generatedCardURL: URL?
    @State private var isGeneratingGreeting = false
    @State private var isGeneratingCard = false
    @State private var selectedGreetingStyle: GreetingStyle = .formal
    @State private var showCardPreview = false
    @State private var greetingHistory: [String] = []
    @State private var cardHistory: [URL] = []
    
    enum GreetingStyle: String, CaseIterable, Identifiable {
        case formal, friendly, funny
        var id: String { rawValue }
        var title: String {
            switch self {
            case .formal: return "Формальное"
            case .friendly: return "Дружеское"
            case .funny: return "С юмором"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(holiday.icon ?? "🎈")
                        .font(.system(size: 80))
                    Text(holiday.title)
                        .font(.largeTitle)
                        .bold()
                    Text(holiday.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(holiday.type.title)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                Picker("Стиль поздравления", selection: $selectedGreetingStyle) {
                    ForEach(GreetingStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                VStack(spacing: 12) {
                    Button {
                        generateGreeting()
                    } label: {
                        if isGeneratingGreeting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .cornerRadius(10)
                        } else {
                            Text("Сгенерировать поздравление")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .disabled(isGeneratingGreeting)
                    
                    Button {
                        generateCard()
                    } label: {
                        if isGeneratingCard {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .cornerRadius(10)
                        } else {
                            Text("Сгенерировать открытку")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .disabled(isGeneratingCard)
                }
                .padding(.horizontal)
                
                if let greeting = generatedGreeting {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Предпросмотр поздравления:")
                            .font(.headline)
                        Text(greeting)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
                
                if let cardURL = generatedCardURL {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Предпросмотр открытки:")
                            .font(.headline)
                        AsyncImage(url: cardURL) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 200)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(12)
                                    .shadow(radius: 5)
                            case .failure:
                                Image(systemName: "photo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 200)
                                    .foregroundColor(.gray)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                if !greetingHistory.isEmpty || !cardHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("История генераций")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                        
                        if !greetingHistory.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Поздравления:")
                                    .font(.headline)
                                ForEach(greetingHistory.indices.reversed(), id: \.self) { index in
                                    Text(greetingHistory[index])
                                        .padding(8)
                                        .background(Color(UIColor.tertiarySystemBackground))
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        if !cardHistory.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Открытки:")
                                    .font(.headline)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(cardHistory.indices.reversed(), id: \.self) { index in
                                            AsyncImage(url: cardHistory[index]) { phase in
                                                switch phase {
                                                case .empty:
                                                    ProgressView()
                                                        .frame(width: 120, height: 160)
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 120, height: 160)
                                                        .clipped()
                                                        .cornerRadius(8)
                                                        .shadow(radius: 3)
                                                case .failure:
                                                    Image(systemName: "photo")
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 120, height: 160)
                                                        .foregroundColor(.gray)
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.bottom)
                }
            }
        }
        .navigationTitle("Праздник")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func generateGreeting() {
        isGeneratingGreeting = true
        generatedGreeting = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let exampleGreeting: String
            switch selectedGreetingStyle {
            case .formal:
                exampleGreeting = "Уважаемые дамы и господа, поздравляем вас с \(holiday.title)! Желаем вам всего наилучшего в этот знаменательный день."
            case .friendly:
                exampleGreeting = "Привет! Поздравляю тебя с \(holiday.title)! Пусть этот день принесет много радости и улыбок."
            case .funny:
                exampleGreeting = "С \(holiday.title)! Пусть твой день будет таким же ярким, как эта открытка, и веселым, как моя шутка!"
            }
            generatedGreeting = exampleGreeting
            greetingHistory.append(exampleGreeting)
            isGeneratingGreeting = false
        }
    }
    
    private func generateCard() {
        isGeneratingCard = true
        generatedCardURL = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // Mock URL for generated card image
            let url = URL(string: "https://via.placeholder.com/400x600.png?text=\(holiday.title.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? "Card")")!
            generatedCardURL = url
            cardHistory.append(url)
            isGeneratingCard = false
        }
    }
}
