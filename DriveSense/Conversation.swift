//
//  Conversation.swift
//  DriveSense
//
//  Created by Karthikeyan Lakshminarayanan on 01/08/25.
//

import Foundation
import SwiftData

@Model
final class Conversation {
    var prompt: String
    var response: String
    var timestamp: Date
    var isFavorite: Bool
    var tags: [String]
    
    init(prompt: String, response: String, timestamp: Date = Date(), isFavorite: Bool = false, tags: [String] = []) {
        self.prompt = prompt
        self.response = response
        self.timestamp = timestamp
        self.isFavorite = isFavorite
        self.tags = tags
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var shortPrompt: String {
        if prompt.count > 50 {
            return String(prompt.prefix(50)) + "..."
        }
        return prompt
    }
    
    var shortResponse: String {
        if response.count > 100 {
            return String(response.prefix(100)) + "..."
        }
        return response
    }
} 