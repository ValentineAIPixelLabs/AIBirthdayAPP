import Foundation
import UIKit

final class ChatGPTService {
    static let shared = ChatGPTService()
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-3.5-turbo"
    
    private init() {}

    // MARK: - Генерация поздравления

    // Новый синтаксис: без appleId параметра, токен берём из AppleSignInManager
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
        // Получаем токен авторизации через AppleSignInManager
        guard let token = AppleSignInManager.shared.currentJWTToken else {
            completion(.failure(NSError(domain: "Нет токена авторизации", code: -401)))
            return
        }
        guard let url = URL(string: "https://aibirthday-backend.up.railway.app/api/generate") else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Не передаём apple_id в body
        let body: [String: Any] = [
            "prompt": prompt,
            "type": "birthday"
        ]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error)); return
        }
        // Добавляем Authorization: Bearer <токен>
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1))); return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success,
                   let result = json["result"] as? String {
                    completion(.success(result.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let errorMsg = json["error"] as? String {
                    completion(.failure(NSError(domain: errorMsg, code: -2)))
                } else {
                    completion(.failure(NSError(domain: "Unexpected response", code: -3)))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    // MARK: - Генерация открытки (prompt формируется во View!)
    // Новый синтаксис: без appleId параметра, токен берём из AppleSignInManager
    func generateCard(for contact: Contact, prompt: String, quality: String, referenceImage: UIImage? = nil, size: String, completion: @escaping () -> Void) {
        let finalPrompt = prompt
        print("🧠 Final image prompt: \n\(finalPrompt)")
        var referenceImageData: Data? = nil
        if let referenceImage = referenceImage,
           let imageData = referenceImage.jpegData(compressionQuality: 0.92) {
            referenceImageData = imageData
        }
        self.requestImageGeneration(prompt: finalPrompt, contactId: contact.id, quality: quality, referenceImageData: referenceImageData, size: size, completion: completion)
    }

    // Новый синтаксис: без appleId параметра, токен берём из AppleSignInManager
    private func requestImageGeneration(prompt: String, contactId: UUID, quality: String, referenceImageData: Data? = nil, size: String, completion: @escaping () -> Void) {
        guard let token = AppleSignInManager.shared.currentJWTToken else {
            DispatchQueue.main.async {
                showAlert(title: "Ошибка", message: "Нет токена авторизации")
                completion()
            }
            return
        }
        guard let url = URL(string: "https://aibirthday-backend.up.railway.app/api/generate_card_image") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 240
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        // Добавляем Authorization: Bearer <токен>
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Отладочные принты для проверки передаваемых параметров
        print("prompt:", prompt)
        print("quality:", quality)
        print("size:", size)
        print("referenceImageData size:", referenceImageData?.count ?? 0)

        var body = Data()

        // prompt
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
        body.append(prompt.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // quality
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"quality\"\r\n\r\n".data(using: .utf8)!)
        body.append(quality.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // size
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"size\"\r\n\r\n".data(using: .utf8)!)
        body.append(size.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // reference (если есть)
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
                    showAlert(title: "Ошибка", message: error.localizedDescription)
                    completion()
                }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    showAlert(title: "Ошибка", message: "Нет данных от сервера")
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
                    // JPEG для истории
                    let jpegData = image.jpegData(compressionQuality: 0.92)
                    let imageToSave = jpegData.flatMap { UIImage(data: $0) } ?? image
                    let newCardId = UUID()
                    let newCard = CardHistoryItem(id: newCardId, date: Date(), cardID: newCardId.uuidString)
                    CardHistoryManager.addCard(item: newCard, image: imageToSave, for: contactId)
                    DispatchQueue.main.async { completion() }
                    return
                } else {
                    DispatchQueue.main.async {
                        showAlert(title: "Ошибка генерации", message: "Не удалось получить изображение.")
                        completion()
                    }
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    showAlert(title: "Ошибка", message: error.localizedDescription)
                    completion()
                }
            }
        }
        task.resume()
    }
    
    // MARK: - Универсальное поздравление с праздником (без персонализации)
    func generateHolidayGreeting(for holidayTitle: String, apiKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        let prompt = """
        Составь оригинальное, душевное и универсальное поздравление с праздником "\(holidayTitle)" на русском языке. Не указывай имя, возраст, профессию или личные качества — поздравление должно подойти для любого человека (родственника, коллеги, знакомого, друга). Стиль выбери подходящий для массовых рассылок и открыток.
        Поздравление должно быть завершённым и не обрываться на середине. Если токены заканчиваются, закончи мысль максимально кратко.
        """
        let messages: [[String: String]] = [
            ["role": "system", "content": "Ты — дружелюбный и оригинальный автор поздравлений на русском языке. Всегда отвечай полным законченным текстом. Не обрывай поздравление на середине."],
            ["role": "user", "content": prompt]
        ]
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 240
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 600,
            "temperature": 0.8
        ]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error)); return
        }
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1))); return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let error = json["error"] as? [String: Any],
                          let message = error["message"] as? String {
                    completion(.failure(NSError(domain: message, code: -2)))
                } else {
                    completion(.failure(NSError(domain: "Unexpected response", code: -3)))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    // MARK: - Персональное поздравление с праздником для контакта
    func generateHolidayGreeting(for contact: Contact, holidayTitle: String, apiKey: String, completion: @escaping (Result<String, Error>) -> Void) {
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
        let messages: [[String: String]] = [
            ["role": "system", "content": "Ты — дружелюбный и оригинальный автор поздравлений на русском языке. Всегда отвечай полным законченным текстом."],
            ["role": "user", "content": prompt]
        ]
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 240
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 600,
            "temperature": 0.8
        ]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error)); return
        }
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1))); return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let error = json["error"] as? [String: Any],
                          let message = error["message"] as? String {
                    completion(.failure(NSError(domain: message, code: -2)))
                } else {
                    completion(.failure(NSError(domain: "Unexpected response", code: -3)))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    // MARK: - Креативный промт для открытки (новая реализация)
    // Новый синтаксис: без appleId параметра, токен берём из AppleSignInManager
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

        // Получаем токен авторизации через AppleSignInManager
        guard let token = AppleSignInManager.shared.currentJWTToken else {
            completion(.failure(NSError(domain: "Нет токена авторизации", code: -401)))
            return
        }
        guard let url = URL(string: "https://aibirthday-backend.up.railway.app/api/generate_card_prompt") else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1))); return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Не передаём apple_id в body
        let body: [String: Any] = [
            "info_block": infoBlock
        ]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error)); return
        }
        // Добавляем Authorization: Bearer <токен>
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1))); return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success,
                   let result = json["result"] as? String {
                    completion(.success(result.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let errorMsg = json["error"] as? String {
                    completion(.failure(NSError(domain: errorMsg, code: -2)))
                } else {
                    completion(.failure(NSError(domain: "Unexpected response", code: -3)))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
}

// MARK: - Вспомогательная функция для показа UIAlert в главном потоке
private func showAlert(title: String, message: String) {
    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let root = scene.windows.first?.rootViewController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        root.present(alert, animated: true)
    }
}
