import Foundation

enum LLMError: LocalizedError {
    case http(Int, String)
    var errorDescription: String? {
        switch self {
        case .http(let code, let body): return "HTTP \(code): \(body)"
        }
    }
}

struct GeminiChunk: Decodable {
    struct Candidate: Decodable { let content: Content? }
    struct Content: Decodable { let parts: [Part]? }
    struct Part: Decodable { let text: String? }
    let candidates: [Candidate]?
}

final class GeminiService: LLMService {
    private let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
    private let model = "gemini-2.5-flash"   // check AI Studio for the current name
    private let systemPrompt = "You are a helpful assistant. Keep answers short and simple."

    var unavailableReason: String? {
        apiKey.isEmpty ? "GEMINI_API_KEY is not set in the Xcode scheme" : nil
    }

    func reset() {}   // stateless: history lives in the app, not in the model

    func stream(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

                    let contents: [[String: Any]] = messages
                        .filter { !$0.text.isEmpty }
                        .map { m -> [String: Any] in
                            ["role": m.role == .user ? "user" : "model",
                             "parts": [["text": m.text]]]
                        }
                    let body: [String: Any] = [
                        "systemInstruction": ["parts": [["text": systemPrompt]]],
                        "contents": contents
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                    guard http.statusCode == 200 else {
                        var errorBody = ""
                        for try await line in bytes.lines { errorBody += line }
                        throw LLMError.http(http.statusCode, errorBody)
                    }

                    // The server sends lines like:  data: {json}
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let data = Data(line.dropFirst(6).utf8)
                        let chunk = try JSONDecoder().decode(GeminiChunk.self, from: data)
                        if let text = chunk.candidates?.first?.content?.parts?.first?.text {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
