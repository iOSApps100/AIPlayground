//
//  OllamaService.swift
//  AIPlayground
//
//  Created by Vikram Kumar on 28/11/26.
//

import Foundation

struct OllamaChunk: Decodable {
    struct Msg: Decodable { let content: String }
    let message: Msg?
    let done: Bool?
}

final class OllamaService: LLMService {
    private let model = "llama3.2"
    private let systemPrompt = "You are a helpful assistant. Keep answers short and simple."

    var unavailableReason: String? { nil }
    func reset() {}

    func stream(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: URL(string: "http://localhost:11434/api/chat")!)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    var chat: [[String: String]] = [["role": "system", "content": systemPrompt]]
                    chat += messages
                        .filter { !$0.text.isEmpty }
                        .map { ["role": $0.role == .user ? "user" : "assistant", "content": $0.text] }

                    let body: [String: Any] = ["model": model, "messages": chat, "stream": true]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                    guard http.statusCode == 200 else {
                        var errorBody = ""
                        for try await line in bytes.lines { errorBody += line }
                        throw LLMError.http(http.statusCode, errorBody)
                    }

                    for try await line in bytes.lines {
                        let chunk = try JSONDecoder().decode(OllamaChunk.self, from: Data(line.utf8))
                        if let text = chunk.message?.content, !text.isEmpty {
                            continuation.yield(text)
                        }
                        if chunk.done == true { break }
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
