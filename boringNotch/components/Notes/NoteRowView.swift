//
//  NoteRowView.swift
//  boringNotch
//
//  Row component for displaying a note in the list
//

import SwiftUI

struct NoteRowView: View {
    let note: Note
    let onTap: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Type icon
            Image(systemName: note.type == .voice ? "mic.fill" : "note.text")
                .font(.caption)
                .foregroundColor(note.type == .voice ? .red : .secondary)
                .frame(width: 14)
            
            // Pin indicator
            if note.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            
            // Content preview
            VStack(alignment: .leading, spacing: 2) {
                Text(note.preview)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Show second line preview if available
                let lines = note.content.components(separatedBy: .newlines).filter { !$0.isEmpty }
                if lines.count > 1 {
                    Text(lines[1])
                        .font(.caption)
                        .foregroundColor(Color(white: 0.65))
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 4)
            
            // Duration for voice notes
            if note.type == .voice, !note.formattedDuration.isEmpty {
                Text(note.formattedDuration)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            // Time ago
            Text(note.timeAgo)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.white.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button(action: onTogglePin) {
                Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
