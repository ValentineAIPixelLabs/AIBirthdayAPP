import Foundation
import UIKit

final class ChatGPTService {
    static let shared = ChatGPTService()
    
    private init() {}
    
    private typealias InterfaceLanguageDetails = (identifier: String, code: String, displayName: String)
    private static let languagePreferenceKey = "app.language.code"

    // MARK: - Генерация поздравления

    // Новый синтаксис: backend будет работать с appAccountToken от DeviceAccountManager
    func generateGreeting(for contact: Contact, completion: @escaping (Result<String, Error>) -> Void) {
        let languageDetails = interfaceLanguageDetails()
        let languageInstruction = interfaceLanguageInstruction(for: languageDetails)
        let interfaceLanguage = interfaceLanguagePayload(for: languageDetails)

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        var promptLines: [String] = [
            "Compose an original and heartfelt birthday greeting for the person described below.",
            ""
        ]
        promptLines.append("Name: \(contact.name)")
        if let nickname = contact.nickname, !nickname.isEmpty { promptLines.append("Nickname: \(nickname)") }
        if let birthdayYear = contact.birthday?.year {
            let age = max(0, currentYear - birthdayYear)
            promptLines.append("Age: \(age)")
        }
        if let relation = contact.relationType, !relation.isEmpty { promptLines.append("Relationship: \(relation)") }
        if let occupation = contact.occupation, !occupation.isEmpty { promptLines.append("Occupation: \(occupation)") }
        if let hobbies = contact.hobbies, !hobbies.isEmpty { promptLines.append("Hobbies: \(hobbies)") }
        if let leisure = contact.leisure, !leisure.isEmpty { promptLines.append("Leisure activities: \(leisure)") }
        if let info = contact.additionalInfo, !info.isEmpty { promptLines.append("Additional details: \(info)") }
        if let birthday = contact.birthday,
           let day = birthday.day,
           let month = birthday.month {
            var birthdayValue = "\(day).\(month)"
            if let year = birthday.year {
                birthdayValue += ".\(year)"
            }
            promptLines.append("Birthday: \(birthdayValue)")
        }
        promptLines.append("")
        promptLines.append("Match the tone to the relationship: keep it warm for relatives, respectful and concise for managers, clients, or colleagues, and relaxed for friends when appropriate. Avoid an overly familiar tone when the relationship is formal or distant.")
        promptLines.append(languageInstruction)
        promptLines.append("Deliver a complete greeting and finish the thought even if you must shorten the ending.")
        let prompt = promptLines.joined(separator: "\n")

        // Prepare request to the backend; the user identifier travels in the header
        DispatchQueue.main.async {
            let token = DeviceAccountManager.shared.appAccountToken()
            guard !token.isEmpty else {
                completion(.failure(self.missingTokenError()))
                return
            }
            guard let url = URL(string: "https://aibirthday-backend.up.railway.app/api/generate") else {
                completion(.failure(NSError(domain: "Invalid URL", code: -1)))
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            // Include only generation data in the body; the account identifier is sent via header
            let body: [String: Any] = [
                "prompt": prompt,
                "type": "birthday",
                "interface_language": interfaceLanguage
            ]
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(.failure(error))
                return
            }
            // Send the stable device identifier in the header
            request.setValue(token, forHTTPHeaderField: "X-App-Account-Token")
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async { completion(.failure(error)) }
                    return
                }
                guard let data = data else {
                    DispatchQueue.main.async { completion(.failure(NSError(domain: "No data", code: -1))) }
                    return
                }
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = json["success"] as? Bool, success,
                       let result = json["result"] as? String {
                        DispatchQueue.main.async { completion(.success(result.trimmingCharacters(in: .whitespacesAndNewlines))) }
                    } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let errorMsg = json["error"] as? String {
                        DispatchQueue.main.async { completion(.failure(NSError(domain: errorMsg, code: -2))) }
                    } else {
                        DispatchQueue.main.async { completion(.failure(NSError(domain: "Unexpected response", code: -3))) }
                    }
                } catch {
                    DispatchQueue.main.async { completion(.failure(error)) }
                }
            }
            task.resume()
        }
    }
    
    // MARK: - Генерация открытки (prompt формируется во View!)
    // Новый синтаксис: backend будет работать с appAccountToken от DeviceAccountManager
    func generateCard(for contact: Contact, prompt: String, quality: String, referenceImage: UIImage? = nil, size: String, completion: @escaping () -> Void) {
        let finalPrompt = prompt
        print("🧠 Final image prompt: \n\(finalPrompt)")
        var referenceImageData: Data? = nil
        if let referenceImage = referenceImage,
           let imageData = referenceImage.jpegData(compressionQuality: 0.92) {
            referenceImageData = imageData
        }
        self.requestImageGeneration(prompt: finalPrompt, target: .contact(contact.id), quality: quality, referenceImageData: referenceImageData, size: size, completion: completion)
    }

    // Генерация открытки по празднику с персонализацией (или без)
    func generateCardForHoliday(holidayId: UUID, holidayTitle: String, contact: Contact?, completion: @escaping () -> Void) {
        var promptLines: [String] = []

        if let contact = contact {
            promptLines.append("Create a festive greeting card image themed \"\(holidayTitle)\" that reflects the following person:")

            promptLines.append("Name: \(contact.name)")
            if let nickname = contact.nickname, !nickname.isEmpty { promptLines.append("Nickname: \(nickname)") }
            if let gender = contact.gender, !gender.isEmpty { promptLines.append("Gender: \(gender)") }
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: Date())
            if let year = contact.birthday?.year { promptLines.append("Age: \(max(0, currentYear - year))") }
            if let relation = contact.relationType, !relation.isEmpty { promptLines.append("Relationship: \(relation)") }
            if let occupation = contact.occupation, !occupation.isEmpty { promptLines.append("Occupation: \(occupation)") }
            if let hobbies = contact.hobbies, !hobbies.isEmpty { promptLines.append("Hobbies: \(hobbies)") }
            if let leisure = contact.leisure, !leisure.isEmpty { promptLines.append("Leisure activities: \(leisure)") }
            if let info = contact.additionalInfo, !info.isEmpty { promptLines.append("Additional details: \(info)") }

            promptLines.append("Format: digital greeting card, bright and upbeat.")
        } else {
            promptLines.append("Create a festive greeting card image themed \"\(holidayTitle)\".")
            promptLines.append("Format: versatile digital holiday card that looks bright and suitable for anyone.")
        }

        let prompt = promptLines.joined(separator: "\n")

        self.requestImageGeneration(prompt: prompt, target: .holiday(holidayId), completion: completion)
    }

    // MARK: - Универсальная функция генерации изображения открытки
    private enum SaveTarget {
        case contact(UUID)
        case holiday(UUID)
    }

    private func missingTokenError() -> NSError {
        NSError(domain: "DeviceAccountToken", code: -401, userInfo: [
            NSLocalizedDescriptionKey: String(localized: "auth.token.missing")
        ])
    }

    private func requestImageGeneration(prompt: String, target: SaveTarget, quality: String?, referenceImageData: Data? = nil, size: String?, completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            let token = DeviceAccountManager.shared.appAccountToken()
            guard !token.isEmpty else {
                showAlert(
                    title: String(localized: "common.error"),
                    message: String(localized: "auth.token.missing")
                )
                completion()
                return
            }
            guard let url = URL(string: "https://aibirthday-backend.up.railway.app/api/generate_card_image") else { completion(); return }
            var request = URLRequest(url: url)
            request.timeoutInterval = 240
            request.httpMethod = "POST"

            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.setValue(token, forHTTPHeaderField: "X-App-Account-Token")

            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append(prompt.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
            if let quality = quality {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"quality\"\r\n\r\n".data(using: .utf8)!)
                body.append(quality.data(using: .utf8)!)
                body.append("\r\n".data(using: .utf8)!)
            }
            if let size = size {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"size\"\r\n\r\n".data(using: .utf8)!)
                body.append(size.data(using: .utf8)!)
                body.append("\r\n".data(using: .utf8)!)
            }
            if let referenceImageData = referenceImageData {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"reference\"; filename=\"reference.jpg\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                body.append(referenceImageData)
                body.append("\r\n".data(using: .utf8)!)
            }
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            request.httpBody = body

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        showAlert(
                            title: String(localized: "common.error"),
                            message: error.localizedDescription
                        )
                        completion()
                    }
                    return
                }
                guard let data = data else {
                    DispatchQueue.main.async {
                        showAlert(
                            title: String(localized: "common.error"),
                            message: String(localized: "server.response.empty")
                        )
                        completion()
                    }
                    return
                }
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = json["success"] as? Bool, success,
                       let base64String = json["image"] as? String,
                       let imageData = Data(base64Encoded: base64String),
                       let image = UIImage(data: imageData) {
                        let jpegData = image.jpegData(compressionQuality: 0.92)
                        let imageToSave = jpegData.flatMap { UIImage(data: $0) } ?? image
                        let newCardId = UUID()
                        let newCard = CardHistoryItem(id: newCardId, date: Date(), cardID: newCardId.uuidString)
                        Task { @MainActor in
                            switch target {
                            case .contact(let id):
                                CardHistoryManager.addCard(item: newCard, image: imageToSave, for: id) {
                                    completion()
                                }
                            case .holiday(let id):
                                CardHistoryManager.addCardForHoliday(item: newCard, image: imageToSave, holidayId: id) {
                                    completion()
                                }
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            showAlert(
                                title: String(localized: "gen.image.error.title"),
                                message: String(localized: "gen.image.error.body")
                            )
                            completion()
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        showAlert(
                            title: String(localized: "common.error"),
                            message: error.localizedDescription
                        )
                        completion()
                    }
                }
            }
            task.resume()
        }
    }

    // MARK: - Универсальная функция генерации изображения открытки для праздников (без обязательных параметров качества и размера)
    private func requestImageGeneration(prompt: String, target: SaveTarget, completion: @escaping () -> Void) {
        self.requestImageGeneration(prompt: prompt, target: target, quality: nil, referenceImageData: nil, size: nil, completion: completion)
    }
    
    private func interfaceLanguageDetails() -> InterfaceLanguageDetails {
        let storedPreference = UserDefaults.standard.string(forKey: Self.languagePreferenceKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let systemDefaultCode: String = {
            let sys = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
            return sys.hasPrefix("ru") ? "ru" : "en"
        }()
        let rawIdentifier = (storedPreference?.isEmpty == false ? storedPreference! : systemDefaultCode)
        let effectiveIdentifier = rawIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? systemDefaultCode
            : rawIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let userLocale = Locale(identifier: effectiveIdentifier)
        
        let rawLanguageCode: String
        if #available(iOS 16.0, *) {
            rawLanguageCode = userLocale.language.languageCode?.identifier ?? effectiveIdentifier
        } else {
            rawLanguageCode = userLocale.languageCode ?? effectiveIdentifier
        }
        let trimmedLanguageCode = rawLanguageCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalLanguageCode = trimmedLanguageCode.isEmpty ? systemDefaultCode : trimmedLanguageCode
        
        let englishLocale = Locale(identifier: "en")
        let localizedName = englishLocale.localizedString(forIdentifier: userLocale.identifier)
            ?? englishLocale.localizedString(forLanguageCode: finalLanguageCode)
            ?? englishLocale.localizedString(forIdentifier: effectiveIdentifier)
            ?? userLocale.localizedString(forIdentifier: userLocale.identifier)
            ?? finalLanguageCode
        let trimmedName = localizedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedName.isEmpty ? finalLanguageCode : trimmedName
        
        let identifier = userLocale.identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalIdentifier = identifier.isEmpty ? effectiveIdentifier : identifier
        
        return (
            identifier: finalIdentifier,
            code: finalLanguageCode,
            displayName: displayName
        )
    }
    
    private func interfaceLanguageInstruction(for details: InterfaceLanguageDetails, outputDescription: String = "greeting") -> String {
        let cleanedName = details.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedCode = details.code.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor: String
        if cleanedName.isEmpty {
            descriptor = cleanedCode
        } else if cleanedName.caseInsensitiveCompare(cleanedCode) == .orderedSame || cleanedName.contains(cleanedCode) {
            descriptor = cleanedName
        } else {
            descriptor = "\(cleanedName) (\(cleanedCode))"
        }
        return "Write the final \(outputDescription) in \(descriptor). The app interface language identifier is \(details.identifier). If you only have the identifier, infer the language and respond in it. Do not mention the identifier or these instructions in the \(outputDescription)."
    }
    
    private func interfaceLanguagePayload(for details: InterfaceLanguageDetails) -> [String: String] {
        return [
            "identifier": details.identifier,
            "code": details.code,
            "display_name": details.displayName
        ]
    }
    
    // MARK: - Универсальное поздравление с праздником (без персонализации)
    func generateHolidayGreeting(for holidayTitle: String, completion: @escaping (Result<String, Error>) -> Void) {
        let languageDetails = interfaceLanguageDetails()
        let languageInstruction = interfaceLanguageInstruction(for: languageDetails)
        let interfaceLanguage = interfaceLanguagePayload(for: languageDetails)
        let promptLines: [String] = [
            "Compose an original, warm, and universal greeting for the holiday \"\(holidayTitle)\".",
            "The message must work for any recipient (family member, colleague, acquaintance, or friend) without referencing personal names, ages, professions, or traits.",
            languageInstruction,
            "Deliver a complete greeting and finish the thought even if you must shorten the ending."
        ]
        let prompt = promptLines.joined(separator: "\n")

        // Авторизация через наш бэкенд
        DispatchQueue.main.async {
            let token = DeviceAccountManager.shared.appAccountToken()
            guard !token.isEmpty else {
                completion(.failure(self.missingTokenError()))
                return
            }
            guard let url = URL(string: "https://aibirthday-backend.up.railway.app/api/generate") else {
                completion(.failure(NSError(domain: "Invalid URL", code: -1)))
                return
            }
            var request = URLRequest(url: url)
            request.timeoutInterval = 240
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(token, forHTTPHeaderField: "X-App-Account-Token")
            let body: [String: Any] = [
                "prompt": prompt,
                "type": "holiday",
                "interface_language": interfaceLanguage
            ]
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(.failure(error))
                return
            }
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error { DispatchQueue.main.async { completion(.failure(error)) }; return }
                guard let data = data else {
                    DispatchQueue.main.async { completion(.failure(NSError(domain: "No data", code: -1))) }
                    return
                }
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = json["success"] as? Bool, success,
                       let result = json["result"] as? String {
                        DispatchQueue.main.async { completion(.success(result.trimmingCharacters(in: .whitespacesAndNewlines))) }
                    } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let errorMsg = json["error"] as? String {
                        DispatchQueue.main.async { completion(.failure(NSError(domain: errorMsg, code: -2))) }
                    } else {
                        DispatchQueue.main.async { completion(.failure(NSError(domain: "Unexpected response", code: -3))) }
                    }
                } catch {
                    DispatchQueue.main.async { completion(.failure(error)) }
                }
            }
            task.resume()
        }
    }
    
    // MARK: - Персональное поздравление с праздником для контакта
    func generateHolidayGreeting(for contact: Contact, holidayTitle: String, completion: @escaping (Result<String, Error>) -> Void) {
        let languageDetails = interfaceLanguageDetails()
        let languageInstruction = interfaceLanguageInstruction(for: languageDetails)
        let interfaceLanguage = interfaceLanguagePayload(for: languageDetails)

        var promptLines = ["Compose an original, sincere, and personalized greeting for the holiday \"\(holidayTitle)\" for the person described below.", ""]
        promptLines.append("Name: \(contact.name)")
        if let nickname = contact.nickname, !nickname.isEmpty { promptLines.append("Nickname: \(nickname)") }
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        if let year = contact.birthday?.year {
            let age = max(0, currentYear - year)
            promptLines.append("Age: \(age)")
        }
        if let relation = contact.relationType, !relation.isEmpty { promptLines.append("Relationship: \(relation)") }
        if let occupation = contact.occupation, !occupation.isEmpty { promptLines.append("Occupation: \(occupation)") }
        if let hobbies = contact.hobbies, !hobbies.isEmpty { promptLines.append("Hobbies: \(hobbies)") }
        if let leisure = contact.leisure, !leisure.isEmpty { promptLines.append("Leisure activities: \(leisure)") }
        if let info = contact.additionalInfo, !info.isEmpty { promptLines.append("Additional details: \(info)") }
        if let birthday = contact.birthday,
           let day = birthday.day,
           let month = birthday.month {
            var birthdayValue = "\(day).\(month)"
            if let year = birthday.year {
                birthdayValue += ".\(year)"
            }
            promptLines.append("Birthday: \(birthdayValue)")
        }
        promptLines.append("")
        promptLines.append("Match the tone to the relationship: warm for relatives, formal and respectful for managers or official contacts, concise for clients and colleagues, and relaxed for friends when appropriate.")
        promptLines.append("Avoid overly familiar language unless the relationship clearly allows it, and only use the person's name or informal pronouns when appropriate.")
        promptLines.append(languageInstruction)
        promptLines.append("Deliver a complete greeting and finish the thought even if you must shorten the ending.")
        let prompt = promptLines.joined(separator: "\n")

        DispatchQueue.main.async {
            let token = DeviceAccountManager.shared.appAccountToken()
            guard !token.isEmpty else {
                completion(.failure(self.missingTokenError()))
                return
            }
            guard let url = URL(string: "https://aibirthday-backend.up.railway.app/api/generate") else {
                completion(.failure(NSError(domain: "Invalid URL", code: -1)))
                return
            }
            var request = URLRequest(url: url)
            request.timeoutInterval = 240
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(token, forHTTPHeaderField: "X-App-Account-Token")
            let body: [String: Any] = [
                "prompt": prompt,
                "type": "holiday_personal",
                "interface_language": interfaceLanguage
            ]
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(.failure(error))
                return
            }
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error { DispatchQueue.main.async { completion(.failure(error)) }; return }
                guard let data = data else {
                    DispatchQueue.main.async { completion(.failure(NSError(domain: "No data", code: -1))) }
                    return
                }
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = json["success"] as? Bool, success,
                       let result = json["result"] as? String {
                        DispatchQueue.main.async { completion(.success(result.trimmingCharacters(in: .whitespacesAndNewlines))) }
                    } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let errorMsg = json["error"] as? String {
                        DispatchQueue.main.async { completion(.failure(NSError(domain: errorMsg, code: -2))) }
                    } else {
                        DispatchQueue.main.async { completion(.failure(NSError(domain: "Unexpected response", code: -3))) }
                    }
                } catch {
                    DispatchQueue.main.async { completion(.failure(error)) }
                }
            }
            task.resume()
        }
    }

    // MARK: - Креативный промт для открытки
    func generateCreativePrompt(for contact: Contact, completion: @escaping (Result<String, Error>) -> Void) {
        let languageDetails = interfaceLanguageDetails()
        let interfaceLanguage = interfaceLanguagePayload(for: languageDetails)

        var infoLines = [String]()
        infoLines.append("Name: \(contact.name)")
        if let nickname = contact.nickname, !nickname.isEmpty { infoLines.append("Nickname: \(nickname)") }
        if let gender = contact.gender, !gender.isEmpty { infoLines.append("Gender: \(gender)") }
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        if let year = contact.birthday?.year { infoLines.append("Age: \(currentYear - year)") }
        if let relation = contact.relationType, !relation.isEmpty { infoLines.append("Relation type: \(relation)") }
        if let occupation = contact.occupation, !occupation.isEmpty { infoLines.append("Occupation: \(occupation)") }
        if let hobbies = contact.hobbies, !hobbies.isEmpty { infoLines.append("Hobbies: \(hobbies)") }
        if let leisure = contact.leisure, !leisure.isEmpty { infoLines.append("Leisure: \(leisure)") }
        if let info = contact.additionalInfo, !info.isEmpty { infoLines.append("Additional Info: \(info)") }
        let infoBlock = infoLines.joined(separator: "\n")

        // Получаем токен авторизации через DeviceAccountManager
        DispatchQueue.main.async {
            let token = DeviceAccountManager.shared.appAccountToken()
            guard !token.isEmpty else {
                completion(.failure(self.missingTokenError()))
                return
            }
            guard let url = URL(string: "https://aibirthday-backend.up.railway.app/api/generate_card_prompt") else {
                completion(.failure(NSError(domain: "Invalid URL", code: -1)))
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "info_block": infoBlock,
                "interface_language": interfaceLanguage
            ]
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(.failure(error))
                return
            }
            // Передаём устойчивый идентификатор устройства в заголовке
            request.setValue(token, forHTTPHeaderField: "X-App-Account-Token")
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error { DispatchQueue.main.async { completion(.failure(error)) }; return }
                guard let data = data else {
                    DispatchQueue.main.async { completion(.failure(NSError(domain: "No data", code: -1))) }
                    return
                }
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = json["success"] as? Bool, success,
                       let result = json["result"] as? String {
                        DispatchQueue.main.async { completion(.success(result.trimmingCharacters(in: .whitespacesAndNewlines))) }
                    } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let errorMsg = json["error"] as? String {
                        DispatchQueue.main.async { completion(.failure(NSError(domain: errorMsg, code: -2))) }
                    } else {
                        DispatchQueue.main.async { completion(.failure(NSError(domain: "Unexpected response", code: -3))) }
                    }
                } catch {
                    DispatchQueue.main.async { completion(.failure(error)) }
                }
            }
            task.resume()
        }
    }
}

// MARK: - Вспомогательная функция для показа UIAlert в главном потоке
private func showAlert(title: String, message: String) {
    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let root = scene.windows.first?.rootViewController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "common.ok"), style: .default))
        root.present(alert, animated: true)
    }
}
//
