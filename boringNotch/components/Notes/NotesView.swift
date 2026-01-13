//
//  NotesView.swift
//  boringNotch
//
//  Main view for the notes feature
//

import SwiftUI

struct NotesView: View {
    @ObservedObject private var service = NotesService.shared
    @State private var selectedNoteId: UUID? = nil
    @State private var isShowingDetail = false
    
    var body: some View {
        Group {
            if isShowingDetail, let noteId = selectedNoteId {
                NoteDetailView(
                    noteId: noteId,
                    onBack: {
                        // Clean up empty notes when going back
                        if let note = service.notes.first(where: { $0.id == noteId }),
                           note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            service.deleteNote(id: noteId)
                        }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isShowingDetail = false
                            selectedNoteId = nil
                        }
                    },
                    onDelete: {
                        service.deleteNote(id: noteId)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isShowingDetail = false
                            selectedNoteId = nil
                        }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                listView
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var listView: some View {
        VStack(spacing: 8) {
            // Search bar + New button
            searchBar
            
            // Notes list or empty state
            if service.displayedNotes.isEmpty {
                emptyState
            } else {
                notesList
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Search notes...", text: $service.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.callout)
                
                if !service.searchQuery.isEmpty {
                    Button(action: { service.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Button(action: createAndOpenNote) {
                Image(systemName: "plus")
                    .font(.body.weight(.medium))
                    .foregroundColor(.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            
            if service.searchQuery.isEmpty {
                Text("No notes yet")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Text("Tap + to create one")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
            } else {
                Text("No matching notes")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var notesList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 2) {
                ForEach(service.displayedNotes) { note in
                    NoteRowView(
                        note: note,
                        onTap: {
                            selectedNoteId = note.id
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isShowingDetail = true
                            }
                        },
                        onDelete: {
                            service.deleteNote(id: note.id)
                        },
                        onTogglePin: {
                            service.togglePin(id: note.id)
                        }
                    )
                }
            }
        }
    }
    
    private func createAndOpenNote() {
        let note = service.createNote()
        selectedNoteId = note.id
        withAnimation(.easeInOut(duration: 0.2)) {
            isShowingDetail = true
        }
    }
}

#Preview {
    NotesView()
        .frame(width: 400, height: 150)
        .background(.black)
}
