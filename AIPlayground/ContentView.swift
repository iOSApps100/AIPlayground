//
//  ContentView.swift
//  AIPlayground
//
//  Created by Vikram Kumar on 26/11/26.
//

import SwiftUI

enum Provider: String, CaseIterable, Identifiable {
    case gemini = "Gemini", ollama = "Ollama", apple = "Apple"
    var id: String { rawValue }
    func makeService() -> LLMService {
        switch self {
        case .gemini: return GeminiService()
        case .ollama: return OllamaService()
        case .apple:  return FoundationModelService()
        }
    }
}

struct ContentView: View {
    @State private var vm = ChatViewModel(service: GeminiService())
    @State private var provider: Provider = .gemini

    var body: some View {
        VStack(spacing: 0) {
            Picker("Model", selection: $provider) {
                ForEach(Provider.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: provider) { _, new in vm.use(new.makeService()) }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(vm.messages) { message in
                            MessageBubble(message: message).id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: vm.messages.last?.text) { _, _ in
                    if let last = vm.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            if let error = vm.errorText {
                Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal)
            }

            HStack(alignment: .bottom) {
                TextField("Message...", text: $vm.input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                if vm.isStreaming {
                    Button("Stop", action: vm.stop)
                } else {
                    Button("Send", action: vm.send)
                }
            }
            .padding()
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    var body: some View {
        HStack {
            if message.role == .user { Spacer() }
            Text(message.text.isEmpty ? "..." : message.text)
                .padding(10)
                .background(message.role == .user ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if message.role == .assistant { Spacer() }
        }
    }
}
#Preview {
    ContentView()
}
