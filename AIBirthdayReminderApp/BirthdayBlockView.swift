import SwiftUI

import Foundation

struct BirthdayBlockView: View {
    let birthday: Birthday
    
    var body: some View {
        let now = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: now)
        
        // Формируем дату рождения
        var birthComponents = DateComponents()
        birthComponents.day = birthday.day
        birthComponents.month = birthday.month
        birthComponents.year = birthday.year ?? 2000  // любое значение для форматирования
        
        let birthDate = calendar.date(from: birthComponents) ?? Date()
        
        // Формат даты
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = birthday.year != nil ? "d MMMM yyyy" : "d MMMM"
        let formattedDate = formatter.string(from: birthDate)
        
        // Возраст
        var ageText = ""
        if let year = birthday.year {
            let today = Date()
            var thisYearComponents = DateComponents()
            thisYearComponents.day = birthday.day
            thisYearComponents.month = birthday.month
            thisYearComponents.year = currentYear
            
            if let birthdayThisYear = calendar.date(from: thisYearComponents) {
                var age = currentYear - year
                if today < birthdayThisYear {
                    age -= 1
                }
                ageText = "(\(age) \(ageSuffix(age)))"
            }
        }

        
        return AnyView(
            VStack(alignment: .leading, spacing: 4) {
                Text("дата рождения")
                    .font(.footnote)
                    .foregroundColor(.gray)
                
                HStack(spacing: 6) {
                    Text(formattedDate)
                        .font(.body)
                        .foregroundColor(.black)
                    if !ageText.isEmpty {
                        Text(ageText)
                            .font(.body)
                            .foregroundColor(.black)
                    }
                }
            }
        )
    }
    
    private func ageSuffix(_ age: Int) -> String {
        let mod10 = age % 10
        let mod100 = age % 100
        if mod100 >= 11 && mod100 <= 14 {
            return "лет"
        }
        switch mod10 {
        case 1: return "год"
        case 2, 3, 4: return "года"
        default: return "лет"
        }
    }
    
    
}
