//
//  HolidayDetailView.swift
//  AIBirthdayReminderApp
//
//  Created by Александр Дротенко on 25.06.2025.
//

import SwiftUI
//import ButtonStyle
//import CardStyle

struct HolidayDetailView: View {
    let holiday: Holiday
    @ObservedObject var vm: HolidaysViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showEditHolidayView = false
    @State private var navigateToEdit = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AppBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Аватар с градиентом и тенью
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.4), Color.purple.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 140, height: 140)
                                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
                            
                            Text(holiday.icon?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? holiday.icon!.trimmingCharacters(in: .whitespacesAndNewlines) : "🎉")
                                .font(.system(size: 72))
                        }
                        
                        // Название праздника - как имя и фамилия в ContactDetailView
                        VStack(spacing: 4) {
                            Text(holiday.title)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            Text("") // Placeholder, так как фамилии у праздника нет
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Карточки даты и типа
                        VStack(spacing: 12) {
                            // Карточка даты
                            HStack(alignment: .top, spacing: CardStyle.Detail.spacing) {
                                Image(systemName: "gift.fill")
                                    .foregroundColor(.pink)
                                    .font(.system(size: CardStyle.Detail.iconSize))

                                Text("Дата праздника: \(holiday.date.formatted(date: .numeric, time: .omitted))")
                                    .font(CardStyle.Detail.font)
                                    .foregroundColor(.primary)

                                Spacer()
                            }
                            .padding(.horizontal, CardStyle.Detail.innerHorizontalPadding)
                            .padding(.vertical, CardStyle.Detail.verticalPadding)
                            .background(
                                RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                                    .fill(CardStyle.backgroundColor)
                                    .shadow(color: CardStyle.shadowColor, radius: CardStyle.shadowRadius, y: CardStyle.shadowYOffset)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                                            .stroke(CardStyle.borderColor, lineWidth: 0.7)
                                    )
                            )

                            // Карточка типа
                            HStack(alignment: .top, spacing: CardStyle.Detail.spacing) {
                                Image(systemName: "tag.fill")
                                    .foregroundColor(.indigo)
                                    .font(.system(size: CardStyle.Detail.iconSize))

                                Text(holiday.type.title)
                                    .font(CardStyle.Detail.font)
                                    .foregroundColor(.primary)

                                Spacer()
                            }
                            .padding(.horizontal, CardStyle.Detail.innerHorizontalPadding)
                            .padding(.vertical, CardStyle.Detail.verticalPadding)
                            .background(
                                RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                                    .fill(CardStyle.backgroundColor)
                                    .shadow(color: CardStyle.shadowColor, radius: CardStyle.shadowRadius, y: CardStyle.shadowYOffset)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CardStyle.cornerRadius, style: .continuous)
                                            .stroke(CardStyle.borderColor, lineWidth: 0.7)
                                    )
                            )
                        }
                        .frame(maxWidth: 500)
                        .padding(.horizontal, 16)
                        
                        Spacer()
                    }
                    .padding(.top, 80)
                }
            }
            .overlay(alignment: .top) {
                TopBarButtons(onBack: { dismiss() }, onEdit: { navigateToEdit = true }, geo: geo)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToEdit) {
            EditHolidayView(
                holiday: holiday,
                onSave: { updatedHoliday in
                    vm.updateHoliday(updatedHoliday)
                    navigateToEdit = false
                },
                onCancel: {
                    navigateToEdit = false
                }
            )
        }
    }
}

struct TopBarButtons: View {
    let onBack: () -> Void
    let onEdit: () -> Void
    let geo: GeometryProxy

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.backward")
                    .frame(width: AppButtonStyle.Circular.diameter, height: AppButtonStyle.Circular.diameter)
                    .background(Circle().fill(AppButtonStyle.Circular.backgroundColor))
                    .shadow(color: AppButtonStyle.Circular.shadow, radius: AppButtonStyle.Circular.shadowRadius)
                    .foregroundColor(AppButtonStyle.Circular.iconColor)
                    .font(.system(size: AppButtonStyle.Circular.iconSize, weight: .semibold))
            }
            Spacer()
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .frame(width: AppButtonStyle.Circular.diameter, height: AppButtonStyle.Circular.diameter)
                    .background(Circle().fill(AppButtonStyle.Circular.backgroundColor))
                    .shadow(color: AppButtonStyle.Circular.shadow, radius: AppButtonStyle.Circular.shadowRadius)
                    .foregroundColor(AppButtonStyle.Circular.iconColor)
                    .font(.system(size: AppButtonStyle.Circular.iconSize, weight: .semibold))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}
