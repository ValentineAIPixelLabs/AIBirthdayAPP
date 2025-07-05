//
//  CardPromptBuilder.swift
//  AIBirthdayReminderApp
//
//  Created by Валентин Станков on 03.07.2025.
//


import Foundation

final class CardPromptBuilder {
    static func buildPrompt(for contact: Contact, apiKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        var ageString = ""
        if let year = contact.birthday?.year {
            let age = currentYear - year
            ageString = "Age: \(age)"
        }

        var facts: [String] = []
        if let gender = contact.gender, !gender.isEmpty {
            facts.append("Gender: \(gender)")
        }
        if !ageString.isEmpty {
            facts.append(ageString)
        }
        if let nickname = contact.nickname, !nickname.isEmpty {
            facts.append("Nickname: \(nickname)")
        }
        if let occupation = contact.occupation, !occupation.isEmpty {
            facts.append("Occupation: \(occupation)")
        }
        if let hobbies = contact.hobbies, !hobbies.isEmpty {
            facts.append("Hobbies: \(hobbies)")
        }
        if let leisure = contact.leisure, !leisure.isEmpty {
            facts.append("Free time: \(leisure)")
        }
        if let info = contact.additionalInfo, !info.isEmpty {
            facts.append("Extra info: \(info)")
        }

        let factsString = facts.joined(separator: ", ")

        // Переводим факты на английский (если вдруг они на русском)
        let translationPrompt = """
        Translate the following facts from Russian to English. Output only a clean English version without comments or explanations:

        \(factsString)
        """

        let translationMessages: [[String: String]] = [
            ["role": "system", "content": "You are a translation assistant. Your task is to translate from Russian to English only."],
            ["role": "user", "content": translationPrompt]
        ]

        let translationBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": translationMessages,
            "max_tokens": 150,
            "temperature": 0.2
        ]

        var translatedFactsString = factsString
        let semaphore = DispatchSemaphore(value: 0)

        guard let translationURL = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(.failure(NSError(domain: "Invalid translation URL", code: -10)))
            return
        }
        var translationRequest = URLRequest(url: translationURL)
        translationRequest.httpMethod = "POST"
        translationRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        translationRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        translationRequest.httpBody = try? JSONSerialization.data(withJSONObject: translationBody)

        URLSession.shared.dataTask(with: translationRequest) { data, _, _ in
            defer { semaphore.signal() }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String
            else {
                return
            }
            translatedFactsString = content.trimmingCharacters(in: .whitespacesAndNewlines)
        }.resume()

        semaphore.wait()

        let promptToChatGPT = """
        Based on the following facts about a person, select only 2–3 of the most visually descriptive and concise ones that could help in creating a fun birthday illustration. Output a single English sentence that describes the cat character and includes those facts in a natural way. Do not mention anything else.

        Facts: \(translatedFactsString)
        """

        let messages: [[String: String]] = [
            ["role": "system", "content": "You are a creative assistant that helps generate prompts for image creation. Output only the final sentence in English, without quotes."],
            ["role": "user", "content": promptToChatGPT]
        ]

        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": messages,
            "max_tokens": 100,
            "temperature": 0.7
        ]

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

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
                completion(.failure(NSError(domain: "No data", code: -2)))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    let finalPrompt = """
                    A cute cartoonish orange cat with a thin outline is the main character of a birthday illustration. \(content.trimmingCharacters(in: .whitespacesAndNewlines)) The background is a warm textured cream tone. Around the cat are colorful and playful confetti in warm shades, conveying a festive and harmonious atmosphere. No people, no faces, no text, no words, no letters or symbols.
                    """
                    print("Generated card prompt: \n\(finalPrompt)")
                    completion(.success(finalPrompt))
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
