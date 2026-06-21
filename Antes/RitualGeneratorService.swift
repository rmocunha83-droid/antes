import Foundation

struct AIRitual: Codable, Equatable {
    let title: String
    let category: String
    let durationMinutes: Int
    let unlockMinutes: Int
    let summary: String
    let steps: [AIRitualStep]
    let completionAction: String
}

struct AIRitualStep: Codable, Equatable {
    let title: String
    let detail: String
    let kind: String
    let target: String
}

struct RitualGeneratorService {
    private var endpoint: URL {
        let baseURLString = Bundle.main.object(forInfoDictionaryKey: "ANTES_API_BASE_URL") as? String
        let normalizedBaseURL = (baseURLString?.isEmpty == false ? baseURLString : "http://127.0.0.1:8790") ?? "http://127.0.0.1:8790"
        return URL(string: normalizedBaseURL)!.appending(path: "api/generate-ritual")
    }

    func generate(habit: String, apps: [String]) async throws -> AIRitual {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(RitualRequest(habit: habit, apps: apps))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(RitualResponse.self, from: data).ritual
    }
}

private struct RitualRequest: Encodable {
    let habit: String
    let apps: [String]
}

private struct RitualResponse: Decodable {
    let ritual: AIRitual
}
