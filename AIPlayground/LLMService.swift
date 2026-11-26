//
//  LLMService.swift
//  AIPlayground
//
//  Created by Vikram Kumar on 26/11/26.
//

import Foundation

enum Role {
    case user
    case assistant
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var text: String
}

protocol LLMService {
    
    /// पूरी बातचीत दो, जवाब टुकड़ों (chunks) में वापस लो
        func stream(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error>
        /// नई बातचीत शुरू करो
        func reset()
        /// अगर model चल नहीं सकता तो वजह, वरना nil
        var unavailableReason: String? { get }
    }

