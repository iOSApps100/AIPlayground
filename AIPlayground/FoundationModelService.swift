//
//  FoundationModelService.swift
//  AIPlayground
//
//  Created by Vikram Kumar on 26/11/26.
//

import Foundation
import FoundationModels

final class FoundationModelService: LLMService {

    private static let instructions = "You are a helpful assistant. Keep answers short and simple."
    private var session = LanguageModelSession(instructions: FoundationModelService.instructions)

    var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available: return nil
        case .unavailable(let reason): return "Model उपलब्ध नहीं: \(reason)"
        }
    }

    func reset() {
        session = LanguageModelSession(instructions: Self.instructions)
    }

    func stream(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // Apple का session पिछली बातचीत ख़ुद याद रखता है,
                    // इसलिए सिर्फ़ आख़िरी user message भेजना काफ़ी है
                    guard let prompt = messages.last(where: { $0.role == .user })?.text else {
                        continuation.finish()
                        return
                    }

                    var previous = ""
                    for try await snapshot in session.streamResponse(to: prompt) {
                        let full = snapshot.content          // अब तक का पूरा text
                        let delta = String(full.dropFirst(previous.count))  // सिर्फ़ नया हिस्सा
                        previous = full
                        if !delta.isEmpty { continuation.yield(delta) }
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
