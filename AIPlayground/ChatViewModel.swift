//
//  ChatViewModel.swift
//  AIPlayground
//
//  Created by Vikram Kumar on 26/11/26.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var input = ""
    var isStreaming = false
    var errorText: String?

    private let service: LLMService
    private var streamTask: Task<Void, Never>?

    init(service: LLMService) {
        self.service = service
        self.errorText = service.unavailableReason
    }

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        input = ""
        errorText = nil
        messages.append(ChatMessage(role: .user, text: text))
        messages.append(ChatMessage(role: .assistant, text: ""))   // खाली bubble, जिसमें जवाब भरेगा
        let index = messages.count - 1
        let history = Array(messages.dropLast())
        isStreaming = true

        streamTask = Task {
            do {
                for try await chunk in service.stream(messages: history) {
                    messages[index].text += chunk
                }
            } catch {
                print("Full Error: ", error)
                errorText = error.localizedDescription
            }
            isStreaming = false
        }
    }

    func stop() { streamTask?.cancel() }

    func newChat() {
        stop()
        service.reset()
        messages = []
    }
}
