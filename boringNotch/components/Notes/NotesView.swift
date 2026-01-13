//
//  NotesView.swift
//  boringNotch
//
//  Main view for the notes feature with three-column layout
//

import SwiftUI

enum NotesViewMode: Equatable {
    case main
    case creatingText
    case creatingVoice
    case viewingNote(UUID)
}

struct NotesView: View {
    @ObservedObject private var service = NotesService.shared
    @State private var viewMode: NotesViewMode = .main
    @State private var pendingVoiceNoteId: UUID?
    
    var body: some View {
        Group {
            switch viewMode {
            case .main:
                mainView
                    .transition(.opacity)
                
            case .creatingText:
                if let note = service.notes.first {
                    NoteDetailView(
                        noteId: note.id,
                        onBack: {
                            // Clean up empty notes
                            if note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                service.deleteNote(id: note.id)
                            }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewMode = .main
                            }
                        },
                        onDelete: {
                            service.deleteNote(id: note.id)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewMode = .main
                            }
                        }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                
            case .creatingVoice:
                VoiceRecorderView(
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode = .main
                        }
                    },
                    onSave: { fileName, duration in
                        let note = service.createVoiceNote(audioFileName: fileName, duration: duration)
                        pendingVoiceNoteId = note.id
                        
                        // Start transcription in background
                        AudioService.shared.transcribe(fileName: fileName) { transcript in
                            if let transcript = transcript {
                                service.updateTranscript(id: note.id, transcript: transcript)
                            }
                        }
                        
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode = .main
                        }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
                
            case .viewingNote(let noteId):
                if let note = service.notes.first(where: { $0.id == noteId }) {
                    if note.type == .voice {
                        VoicePlayerView(
                            note: note,
                            onBack: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewMode = .main
                                }
                            },
                            onDelete: {
                                service.deleteNote(id: noteId)
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewMode = .main
                                }
                            },
                            onTogglePin: {
                                service.togglePin(id: noteId)
                            }
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        NoteDetailView(
                            noteId: noteId,
                            onBack: {
                                if note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    service.deleteNote(id: noteId)
                                }
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewMode = .main
                                }
                            },
                            onDelete: {
                                service.deleteNote(id: noteId)
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewMode = .main
                                }
                            }
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Main Three-Column View
    
    private var mainView: some View {
        HStack(spacing: 8) {
            // Left: Write Note button
            AddNoteButton(
                icon: "square.and.pencil",
                label: "Write",
                color: .accentColor
            ) {
                let _ = service.createNote()
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewMode = .creatingText
                }
            }
            
            // Middle: Voice Note button
            AddNoteButton(
                icon: "mic.fill",
                label: "Voice",
                color: .red
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewMode = .creatingVoice
                }
            }
            
            // Right: Library
            libraryView
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Library Column
    
    private var libraryView: some View {
        VStack(spacing: 6) {
            // Search bar
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                TextField("Search", text: $service.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.caption)
                
                if !service.searchQuery.isEmpty {
                    Button(action: { service.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Notes list
            if service.displayedNotes.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("No notes")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(service.displayedNotes) { note in
                            CompactNoteRow(note: note) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewMode = .viewingNote(note.id)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Supporting Views

struct AddNoteButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct CompactNoteRow: View {
    let note: Note
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: note.type == .voice ? "mic.fill" : "note.text")
                    .font(.caption2)
                    .foregroundColor(note.type == .voice ? .red : .secondary)
                    .frame(width: 12)
                
                Text(note.preview)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer(minLength: 4)
                
                if note.type == .voice, !note.formattedDuration.isEmpty {
                    Text(note.formattedDuration)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(note.timeAgo)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(note.isPinned ? Color.accentColor.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NotesView()
        .frame(width: 400, height: 150)
        .background(.black)
}
