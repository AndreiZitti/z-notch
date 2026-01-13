//
//  Note.swift
//  boringNotch
//
//  Model for notes feature
//

import Foundation

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    var content: String
    let createdAt: Date
    var modifiedAt: Date
    var isPinned: Bool
    
    init(id: UUID = UUID(), content: String = "", createdAt: Date = Date(), modifiedAt: Date = Date(), isPinned: Bool = false) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isPinned = isPinned
    }
    
    /// First line of content as preview, or placeholder if empty
    var preview: String {
        let firstLine = content.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces) ?? ""
        return firstLine.isEmpty ? "Empty note" : firstLine
    }
    
    /// Relative time string for display
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: modifiedAt, relativeTo: Date())
    }
}
