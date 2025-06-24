import Foundation

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
    
    /// Генерирует открытку через DALL-E API на основе данных контакта
    func generateCard(for contact: Contact, apiKey: String, completion: @escaping (Result<URL, Error>) -> Void) {
        // Собираем промпт для DALL-E с максимальной персонализацией
        var ageString = ""
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        if let year = contact.birthday?.year {
            let age = currentYear - year
            ageString = " (возраст: \(age))"
        }

        var prompt = "Современная стильная поздравительная открытка ко дню рождения для \(contact.name)\(ageString)"
        if let nickname = contact.nickname, !nickname.isEmpty {
            prompt += " (прозвище: \(nickname))"
        }
        if let relation = contact.relationType, !relation.isEmpty {
            prompt += ", отношения: \(relation)"
        }
        if let occupation = contact.occupation, !occupation.isEmpty {
            prompt += ". Род деятельности: \(occupation)"
        }
        if let hobbies = contact.hobbies, !hobbies.isEmpty {
            prompt += ". Увлечения/Хобби: \(hobbies)"
        }
        if let leisure = contact.leisure, !leisure.isEmpty {
            prompt += ". Как любит проводить свободное время: \(leisure)"
        }
        if let info = contact.additionalInfo, !info.isEmpty {
            prompt += ". Дополнительная информация: \(info)"
        }
        prompt += ". Открытка должна состоять только из одного листа. Открытка должна быть только на русском языке! На открытке — крупная яркая надпись: «С днём рождения!» — строго по-русски, только кириллица, без латинских букв, без английского языка, без транслита, без лишнего текста. Современный дизайн, яркие цвета, минимум текста, без водяных знаков, без логотипов, только сама картинка открытки, больше упора на дизайн и локаничность"

        // DALL-E API endpoint
        guard let url = URL(string: "https://api.openai.com/v1/images/generations") else {
            completion(.failure(NSError(domain: "Invalid DALL-E URL", code: -10)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "dall-e-3",
            "prompt": prompt,
            "n": 1,
            "size": "1024x1024"
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
                completion(.failure(NSError(domain: "No data", code: -11)))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataArr = json["data"] as? [[String: Any]],
                   let urlString = dataArr.first?["url"] as? String,
                   let imageUrl = URL(string: urlString) {
                    // Теперь скачиваем изображение по imageUrl и сохраняем локально
                    let downloadTask = URLSession.shared.dataTask(with: imageUrl) { imageData, _, downloadError in
                        if let downloadError = downloadError {
                            completion(.failure(downloadError))
                            return
                        }
                        guard let imageData = imageData else {
                            completion(.failure(NSError(domain: "No image data", code: -14)))
                            return
                        }
                        do {
                            let fileManager = FileManager.default
                            let documentsURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                            let cardsDirectory = documentsURL.appendingPathComponent("Cards")
                            if !fileManager.fileExists(atPath: cardsDirectory.path) {
                                try fileManager.createDirectory(at: cardsDirectory, withIntermediateDirectories: true)
                            }
                            let fileName = UUID().uuidString + ".png"
                            let fileURL = cardsDirectory.appendingPathComponent(fileName)
                            try imageData.write(to: fileURL)
                            // Возвращаем локальный URL файла, а не интернет-ресурс
                            completion(.success(fileURL))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                    downloadTask.resume()
                } else if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let error = json["error"] as? [String: Any],
                          let message = error["message"] as? String {
                    completion(.failure(NSError(domain: message, code: -12)))
                } else {
                    completion(.failure(NSError(domain: "Unexpected DALL-E response", code: -13)))
                }
            } catch {
                completion(.failure(error))
            }
        }

        task.resume()
    }
}
