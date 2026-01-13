//
//  NoteDetailView.swift
//  boringNotch
//
//  Detail view for editing a single note
//

import SwiftUI
import AppKit

struct NoteDetailView: View {
    let noteId: UUID
    let onBack: () -> Void
    let onDelete: () -> Void
    
    @ObservedObject private var service = NotesService.shared
    @State private var content: String = ""
    @FocusState private var isEditorFocused: Bool
    
    /// Get current note from service
    private var note: Note? {
        service.notes.first { $0.id == noteId }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.bottom, 8)
            
            // Text editor
            editor
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear {
            // Load initial content
            content = note?.content ?? ""
            
            // Activate app and focus editor
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.activate(ignoringOtherApps: true)
                // Make the window key
                NSApp.windows.first { $0.isVisible }?.makeKey()
                isEditorFocused = true
            }
        }
        .onChange(of: content) { _, newValue in
            guard var currentNote = note else { return }
            currentNote.content = newValue
            service.updateNote(currentNote)
        }
    }
    
    private var header: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Notes")
                }
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Timestamp
            if let note = note {
                Text(note.modifiedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Pin button
            Button(action: { service.togglePin(id: noteId) }) {
                Image(systemName: note?.isPinned == true ? "pin.fill" : "pin")
                    .foregroundColor(note?.isPinned == true ? .orange : .secondary)
            }
            .buttonStyle(.plain)
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
    }
    
    private var editor: some View {
        TextEditor(text: $content)
            .font(.body)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .focused($isEditorFocused)
    }
}
