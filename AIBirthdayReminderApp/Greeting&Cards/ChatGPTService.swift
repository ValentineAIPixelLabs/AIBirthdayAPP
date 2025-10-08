import Foundation
import UIKit

final class ChatGPTService {
    static let shared = ChatGPTService()
    
    private init() {}

    // MARK: - Генерация поздравления

    // Новый синтаксис: backend будет работать с appAccountToken от DeviceAccountManager
    func generateGreeting(for contact: Contact, completion: @escaping (Result<String, Error>) -> Void) {
        // 1. Формируем prompt как раньше
        var ageString = ""
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        if let year = contact.birthday?.year {
            let age = currentYear - year
            ageString = "Возраст: \(age)"
        }

        var promptLines = ["Составь оригинальное и искреннее поздравление с днём рождения для следующего человека:"]
        promptLines.append("")
        promptLines.append("Имя: \(contact.name),")
        if let nickname = contact.nickname, !nickname.isEmpty { promptLines.append("Прозвище: \(nickname),") }
        if !ageString.isEmpty { promptLines.append("\(ageString),") }
        if let relation = contact.relationType, !relation.isEmpty { promptLines.append("Тип отношений: \(relation),") }
        if let occupation = contact.occupation, !occupation.isEmpty { promptLines.append("Род деятельности: \(occupation),") }
        if let hobbies = contact.hobbies, !hobbies.isEmpty { promptLines.append("Увлечения/Хобби: \(hobbies),") }
        if let leisure = contact.leisure, !leisure.isEmpty { promptLines.append("Как любит проводить свободное время: \(leisure),") }
        if let info = contact.additionalInfo, !info.isEmpty { promptLines.append("Дополнительная информация: \(info),") }
        var birthdayLine = "Дата рождения: "
        if let birthday = contact.birthday,
           let day = birthday.day,
           let month = birthday.month {
            birthdayLine += "\(day).\(month)"
            if let year = birthday.year { birthdayLine += ".\(year)" }
        }
        promptLines.append("\(birthdayLine),")
        promptLines.append("")
        promptLines.append("""
Учитывай, что это поздравление для \(contact.relationType ?? "человека"). Стиль поздравления должен быть уместным: если это родственник — более тепло, если начальник, руководитель - более сдержано и формально, если клиент, коллега, товарищ - также формально и не многословно, если друг — более открыто и неформально. Не используй слишком фамильярный стиль для малознакомых или официальных отношений. Обращайся на "ты" только если это уместно.
""")
        promptLines.append("Поздравление должно быть завершённым и не обрываться на середине. Если токены заканчиваются, закончи мысль максимально кратко.")
        let prompt = promptLines.joined(separator: "\n")
        
        // 2. Готовим запрос к своему серверу
        // Читаем токен на главном акторе (DeviceAccountManager помечен @MainActor)
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
            // В теле запроса только данные генерации; идентификатор пользователя уходит в заголовке
            let body: [String: Any] = [
                "prompt": prompt,
                "type": "birthday"
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
            promptLines.append("Сгенерируй изображение праздничной открытки на тему \"\(holidayTitle)\" с учётом следующей информации о человеке:")

            promptLines.append("Имя: \(contact.name)")
            if let nickname = contact.nickname, !nickname.isEmpty { promptLines.append("Прозвище: \(nickname)") }
            if let gender = contact.gender, !gender.isEmpty { promptLines.append("Пол: \(gender)") }
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: Date())
            if let year = contact.birthday?.year { promptLines.append("Возраст: \(currentYear - year)") }
            if let relation = contact.relationType, !relation.isEmpty { promptLines.append("Тип отношений: \(relation)") }
            if let occupation = contact.occupation, !occupation.isEmpty { promptLines.append("Профессия: \(occupation)") }
            if let hobbies = contact.hobbies, !hobbies.isEmpty { promptLines.append("Хобби: \(hobbies)") }
            if let leisure = contact.leisure, !leisure.isEmpty { promptLines.append("Как проводит досуг: \(leisure)") }
            if let info = contact.additionalInfo, !info.isEmpty { promptLines.append("Дополнительно: \(info)") }

            promptLines.append("Формат: открытка для цифровой отправки, яркая, позитивная.")
        } else {
            promptLines.append("Сгенерируй изображение праздничной открытки на тему \"\(holidayTitle)\".")
            promptLines.append("Формат: универсальная праздничная открытка, яркая, цифровая, подходящая для поздравления любого человека.")
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
    
    // MARK: - Универсальное поздравление с праздником (без персонализации)
    func generateHolidayGreeting(for holidayTitle: String, completion: @escaping (Result<String, Error>) -> Void) {
        let prompt = """
        Составь оригинальное, душевное и универсальное поздравление с праздником "\(holidayTitle)" на русском языке. Не указывай имя, возраст, профессию или личные качества — поздравление должно подойти для любого человека (родственника, коллеги, знакомого, друга). Стиль выбери подходящий для массовых рассылок и открыток.
        Поздравление должно быть завершённым и не обрываться на середине. Если токены заканчиваются, закончи мысль максимально кратко. Если токены заканчиваются, закончи мысль максимально кратко.
        """

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
                "type": "holiday"
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
        var promptLines = ["Составь оригинальное, искреннее и персональное поздравление с праздником \"\(holidayTitle)\" для следующего человека:\n"]
        promptLines.append("Имя: \(contact.name)")
        if let nickname = contact.nickname, !nickname.isEmpty { promptLines.append("Прозвище: \(nickname)") }
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        if let year = contact.birthday?.year { promptLines.append("Возраст: \(currentYear - year)") }
        if let relation = contact.relationType, !relation.isEmpty { promptLines.append("Тип отношений: \(relation)") }
        if let occupation = contact.occupation, !occupation.isEmpty { promptLines.append("Род деятельности: \(occupation)") }
        if let hobbies = contact.hobbies, !hobbies.isEmpty { promptLines.append("Увлечения/Хобби: \(hobbies)") }
        if let leisure = contact.leisure, !leisure.isEmpty { promptLines.append("Как любит проводить свободное время: \(leisure)") }
        if let info = contact.additionalInfo, !info.isEmpty { promptLines.append("Дополнительная информация: \(info)") }
        var birthdayLine = "Дата рождения: "
        if let birthday = contact.birthday,
           let day = birthday.day,
           let month = birthday.month {
            birthdayLine += "\(day).\(month)"
            if let year = birthday.year { birthdayLine += ".\(year)" }
        }
        promptLines.append(birthdayLine)
        promptLines.append("""

Поздравление должно соответствовать ситуации (родственник — тепло, начальник — формально, друг — открыто и неформально и т.д.) Не используй фамильярный стиль для официальных отношений. Не обращайся по имени или на "ты", если не уместно. Поздравление должно быть завершённым и не обрываться на середине.
""")
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
                "type": "holiday_personal"
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
            // В теле запроса только данные генерации; идентификатор пользователя уходит в заголовке
            let body: [String: Any] = [
                "info_block": infoBlock
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
