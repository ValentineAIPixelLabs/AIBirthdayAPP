import Foundation
import UIKit

final class ChatGPTService {
    static let shared = ChatGPTService()
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-3.5-turbo"

    private init() {}

    /// Генерирует поздравление на основе данных контакта
    func generateGreeting(for contact: Contact, apiKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Рассчитываем возраст, если есть год рождения
        var ageString = ""
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        if let year = contact.birthday?.year {
            let age = currentYear - year
            ageString = "Возраст: \(age)"
        } else {
            ageString = ""
        }

        // Формируем части prompt по наличию данных
        var promptLines = ["Составь оригинальное и искреннее поздравление с днём рождения для следующего человека:\n"]
        promptLines.append("Имя: \(contact.name)")
        if let nickname = contact.nickname, !nickname.isEmpty {
            promptLines.append("Прозвище: \(nickname)")
        }
        if !ageString.isEmpty {
            promptLines.append(ageString)
        }
        if let relation = contact.relationType, !relation.isEmpty {
            promptLines.append("Тип отношений: \(relation)")
        }
        if let occupation = contact.occupation, !occupation.isEmpty {
            promptLines.append("Род деятельности: \(occupation)")
        }
        if let hobbies = contact.hobbies, !hobbies.isEmpty {
            promptLines.append("Увлечения/Хобби: \(hobbies)")
        }
        if let leisure = contact.leisure, !leisure.isEmpty {
            promptLines.append("Как любит проводить свободное время: \(leisure)")
        }
        if let info = contact.additionalInfo, !info.isEmpty {
            promptLines.append("Дополнительная информация: \(info)")
        }
        var birthdayLine = "Дата рождения: "
        if let birthday = contact.birthday,
           let day = birthday.day,
           let month = birthday.month {
            birthdayLine += "\(day).\(month)"
            if let year = birthday.year {
                birthdayLine += ".\(year)"
            }
        }
        promptLines.append(birthdayLine)

        promptLines.append("""
        
Учитывай, что это поздравление для \(contact.relationType ?? "человека"). Стиль поздравления должен быть уместным: если это родственник — более тепло, если начальник, руководитель - более сдержано и формально, если клиент, коллега, товарищь - также формально и не многословно,  если друг — более открыто и неформально, если   Не используй слишком фамильярный стиль для малознакомых или официальных отношений. Обращайся на "ты" только если это уместно.
""")
        promptLines.append("Поздравление должно быть завершённым и не обрываться на середине. Если токены заканчиваются, закончи мысль максимально кратко.")

        let prompt = promptLines.joined(separator: "\n")

        let messages: [[String: String]] = [
            ["role": "system", "content": "Ты — дружелюбный и оригинальный автор поздравлений на русском языке. Всегда отвечай полным законченным текстом. Не обрывай поздравление на середине, даже если не хватает токенов — постарайся завершить мысль или закончить поздравление кратко."],
            ["role": "user", "content": prompt]
        ]

        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 240 // 4 минуты
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
            completion(.failure(error))
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
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

    /// Генерирует праздничную иллюстрацию для контакта.
    /// Теперь prompt формируется во View, а старое поведение закомментировано для последующего рефакторинга или восстановления.
    func generateCard(for contact: Contact, prompt: String, apiKey: String, quality: String, referenceImage: UIImage? = nil, size: String, completion: @escaping () -> Void) {
//        let description = """
//        Name: \(contact.name)
//        Gender: \(contact.gender ?? "")
//        Nickname: \(contact.nickname ?? "")
//        Age: \(Calendar.current.component(.year, from: Date()) - (contact.birthday?.year ?? Calendar.current.component(.year, from: Date())))
//        Occupation: \(contact.occupation ?? "")
//        Hobbies: \(contact.hobbies ?? "")
//        Leisure: \(contact.leisure ?? "")
//        Additional Info: \(contact.additionalInfo ?? "")
//        """
//
//        let finalPrompt = """
//        A cute cartoonish personage with a thin outline is the main character of a birthday illustration. The phrase “С днём рождения!” in Cyrillic should be clearly visible at the top of the image with enough margin so it is not cut off. \(description) The background is a warm textured cream tone. Around the  personage are colorful and playful confetti in warm shades, conveying a festive and harmonious atmosphere. No people, no faces, no text, no words, no letters or symbols.
//        """

        let finalPrompt = prompt

        print("🧠 Final image prompt: \n\(finalPrompt)")

        var referenceImageData: Data? = nil
        if let referenceImage = referenceImage,
           let imageData = referenceImage.jpegData(compressionQuality: 0.92) {
            referenceImageData = imageData
        }

        self.requestImageGeneration(prompt: finalPrompt, apiKey: apiKey, contactId: contact.id, quality: quality, referenceImageData: referenceImageData, size: size, completion: completion)
    }

    private func requestImageGeneration(prompt: String, apiKey: String, contactId: UUID, quality: String, referenceImageData: Data? = nil, size: String, completion: @escaping () -> Void) {
        if referenceImageData == nil {
            // Обычная генерация без референса
            guard let url = URL(string: "https://api.openai.com/v1/images/generations") else {
                return
            }
            var request = URLRequest(url: url)
            request.timeoutInterval = 240 // 4 минуты
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "model": "gpt-image-1",
                "prompt": prompt,
                "n": 1,
                "size": size,
                "quality": quality
            ]

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                print("Ошибка сериализации тела запроса: \(error)")
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Ошибка", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let root = scene.windows.first?.rootViewController {
                        root.present(alert, animated: true)
                    }
                    completion()
                }
                return
            }

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Ошибка dataTask: \(error)")
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "Ошибка", message: error.localizedDescription, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let root = scene.windows.first?.rootViewController {
                            root.present(alert, animated: true)
                        }
                        completion()
                    }
                    return
                }
                guard let data = data else {
                    print("Нет данных от OpenAI")
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "Ошибка", message: "Нет данных от OpenAI", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let root = scene.windows.first?.rootViewController {
                            root.present(alert, animated: true)
                        }
                        completion()
                    }
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let dataArr = json["data"] as? [[String: Any]],
                           let base64String = dataArr.first?["b64_json"] as? String,
                           let imageData = Data(base64Encoded: base64String),
                           let image = UIImage(data: imageData) {
                            // Сохраняем как JPEG с качеством 0.92, чтобы было, как и при reference
                            if let jpegData = image.jpegData(compressionQuality: 0.92),
                               let jpegImage = UIImage(data: jpegData) {
                                let newCardId = UUID()
                                let newCard = CardHistoryItem(id: newCardId, date: Date(), cardID: newCardId.uuidString)
                                CardHistoryManager.addCard(item: newCard, image: jpegImage, for: contactId)
                            } else {
                                // Fallback, если вдруг не удалось конвертировать в jpeg
                                let newCardId = UUID()
                                let newCard = CardHistoryItem(id: newCardId, date: Date(), cardID: newCardId.uuidString)
                                CardHistoryManager.addCard(item: newCard, image: image, for: contactId)
                            }
                            DispatchQueue.main.async {
                                completion()
                            }
                            return
                        } else {
                            // Если не удалось получить картинку
                            DispatchQueue.main.async {
                                let alert = UIAlertController(title: "Ошибка генерации", message: "Не удалось получить изображение.", preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let root = scene.windows.first?.rootViewController {
                                    root.present(alert, animated: true)
                                }
                                completion()
                            }
                            return
                        }
                    }
                    // Обработка ошибок OpenAI после успешного парса, если нет картинки
                    else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let error = json["error"] as? [String: Any],
                              let message = error["message"] as? String {
                        DispatchQueue.main.async {
                            let alert = UIAlertController(title: "Ошибка генерации", message: message, preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let root = scene.windows.first?.rootViewController {
                                root.present(alert, animated: true)
                            }
                            completion()
                        }
                        return
                    } else {
                        DispatchQueue.main.async {
                            let alert = UIAlertController(title: "Ошибка генерации", message: "Неизвестная ошибка", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let root = scene.windows.first?.rootViewController {
                                root.present(alert, animated: true)
                            }
                            completion()
                        }
                        return
                    }
                } catch {
                    print("Ошибка парсинга JSON: \(error)")
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "Ошибка", message: error.localizedDescription, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let root = scene.windows.first?.rootViewController {
                            root.present(alert, animated: true)
                        }
                        completion()
                    }
                    return
                }
            }
            task.resume()
        } else {
            // Генерация с референс-изображением (image edit)
            guard let url = URL(string: "https://api.openai.com/v1/images/edits"),
                  let referenceImageData = referenceImageData else {
                return
            }
            var request = URLRequest(url: url)
            request.timeoutInterval = 240 // 4 минуты
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            var body = Data()

            // image
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"reference.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(referenceImageData)
            body.append("\r\n".data(using: .utf8)!)

            // prompt
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append(prompt.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)

            // model
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
            body.append("gpt-image-1".data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)

            // n
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"n\"\r\n\r\n".data(using: .utf8)!)
            body.append("1".data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)

            // size
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"size\"\r\n\r\n".data(using: .utf8)!)
            body.append(size.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)

            // quality
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"quality\"\r\n\r\n".data(using: .utf8)!)
            body.append(quality.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)

            // Finish boundary
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            request.httpBody = body

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Ошибка dataTask: \(error)")
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "Ошибка", message: error.localizedDescription, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let root = scene.windows.first?.rootViewController {
                            root.present(alert, animated: true)
                        }
                        completion()
                    }
                    return
                }
                guard let data = data else {
                    print("Нет данных от OpenAI")
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "Ошибка", message: "Нет данных от OpenAI", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let root = scene.windows.first?.rootViewController {
                            root.present(alert, animated: true)
                        }
                        completion()
                    }
                    return
                }
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let dataArr = json["data"] as? [[String: Any]],
                           let base64String = dataArr.first?["b64_json"] as? String,
                           let imageData = Data(base64Encoded: base64String),
                           let image = UIImage(data: imageData) {
                            // Только если картинка успешно создана, сохраняем
                            let newCardId = UUID()
                            let newCard = CardHistoryItem(id: newCardId, date: Date(), cardID: newCardId.uuidString)
                            CardHistoryManager.addCard(item: newCard, image: image, for: contactId)
                            DispatchQueue.main.async {
                                completion()
                            }
                            return
                        } else {
                            // Если не удалось получить картинку
                            DispatchQueue.main.async {
                                let alert = UIAlertController(title: "Ошибка генерации", message: "Не удалось получить изображение.", preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let root = scene.windows.first?.rootViewController {
                                    root.present(alert, animated: true)
                                }
                                completion()
                            }
                            return
                        }
                    }
                    // Обработка ошибок OpenAI после успешного парса, если нет картинки
                    else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let error = json["error"] as? [String: Any],
                              let message = error["message"] as? String {
                        DispatchQueue.main.async {
                            let alert = UIAlertController(title: "Ошибка генерации", message: message, preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let root = scene.windows.first?.rootViewController {
                                root.present(alert, animated: true)
                            }
                            completion()
                        }
                        return
                    } else {
                        DispatchQueue.main.async {
                            let alert = UIAlertController(title: "Ошибка генерации", message: "Неизвестная ошибка", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let root = scene.windows.first?.rootViewController {
                                root.present(alert, animated: true)
                            }
                            completion()
                        }
                        return
                    }
                } catch {
                    print("Ошибка парсинга JSON: \(error)")
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "Ошибка", message: error.localizedDescription, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let root = scene.windows.first?.rootViewController {
                            root.present(alert, animated: true)
                        }
                        completion()
                    }
                    return
                }
            }
            task.resume()
        }
    }
    /// Генерирует универсальное поздравление с праздником (без персонализации)
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
        request.timeoutInterval = 240 // 4 минуты
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
            completion(.failure(error))
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
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

    /// Генерирует персональное поздравление с праздником для конкретного человека
    func generateHolidayGreeting(for contact: Contact, holidayTitle: String, apiKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        var promptLines = ["Составь оригинальное, искреннее и персональное поздравление с праздником \"\(holidayTitle)\" для следующего человека:\n"]
        promptLines.append("Имя: \(contact.name)")
        if let nickname = contact.nickname, !nickname.isEmpty {
            promptLines.append("Прозвище: \(nickname)")
        }
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        if let year = contact.birthday?.year {
            let age = currentYear - year
            promptLines.append("Возраст: \(age)")
        }
        if let relation = contact.relationType, !relation.isEmpty {
            promptLines.append("Тип отношений: \(relation)")
        }
        if let occupation = contact.occupation, !occupation.isEmpty {
            promptLines.append("Род деятельности: \(occupation)")
        }
        if let hobbies = contact.hobbies, !hobbies.isEmpty {
            promptLines.append("Увлечения/Хобби: \(hobbies)")
        }
        if let leisure = contact.leisure, !leisure.isEmpty {
            promptLines.append("Как любит проводить свободное время: \(leisure)")
        }
        if let info = contact.additionalInfo, !info.isEmpty {
            promptLines.append("Дополнительная информация: \(info)")
        }
        var birthdayLine = "Дата рождения: "
        if let birthday = contact.birthday,
           let day = birthday.day,
           let month = birthday.month {
            birthdayLine += "\(day).\(month)"
            if let year = birthday.year {
                birthdayLine += ".\(year)"
            }
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
        request.timeoutInterval = 240 // 4 минуты
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
            completion(.failure(error))
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
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
}

    
