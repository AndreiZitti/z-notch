//
//  Note.swift
//  boringNotch
//
//  Model for notes feature
//

import Foundation

public enum NoteType: String, Codable {
    case text
    case voice
}

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    var content: String
    let createdAt: Date
    var modifiedAt: Date
    var isPinned: Bool
    var type: NoteType
    var audioFileName: String?
    var audioDuration: TimeInterval?
    
    init(id: UUID = UUID(), content: String = "", createdAt: Date = Date(), modifiedAt: Date = Date(), isPinned: Bool = false, type: NoteType = .text, audioFileName: String? = nil, audioDuration: TimeInterval? = nil) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isPinned = isPinned
        self.type = type
        self.audioFileName = audioFileName
        self.audioDuration = audioDuration
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
    
    /// Formatted duration string for voice notes (e.g., "1:23")
    var formattedDuration: String {
        guard let duration = audioDuration else { return "" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
