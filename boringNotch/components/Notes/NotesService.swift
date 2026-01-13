//
//  NotesService.swift
//  boringNotch
//
//  Service for managing notes persistence and business logic
//

import Foundation
import SwiftUI

@MainActor
class NotesService: ObservableObject {
    static let shared = NotesService()
    
    @Published var notes: [Note] = []
    @Published var searchQuery: String = ""
    
    private let fileURL: URL
    private var saveTask: Task<Void, Never>?
    private var hasPendingChanges = false
    
    /// Notes filtered by search and sorted (pinned first, then by modified date)
    var displayedNotes: [Note] {
        let filtered = searchQuery.isEmpty
            ? notes
            : notes.filter { $0.content.localizedCaseInsensitiveContains(searchQuery) }
        
        return filtered.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.modifiedAt > $1.modifiedAt
        }
    }
    
    private init() {
        // Set up file path in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("boringNotch", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        self.fileURL = appFolder.appendingPathComponent("notes.json")
        load()
    }
    
    // MARK: - CRUD Operations
    
    /// Creates a new empty note and returns it
    func createNote() -> Note {
        let note = Note()
        notes.insert(note, at: 0)
        save()
        return note
    }
    
    /// Creates a new voice note with audio file reference
    func createVoiceNote(audioFileName: String, duration: TimeInterval) -> Note {
        let note = Note(
            type: .voice,
            audioFileName: audioFileName,
            audioDuration: duration
        )
        notes.insert(note, at: 0)
        debouncedSave()
        return note
    }
    
    /// Updates an existing note
    func updateNote(_ note: Note) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        var updatedNote = note
        updatedNote.modifiedAt = Date()
        notes[index] = updatedNote
        debouncedSave()
    }
    
    /// Updates the transcript for a voice note
    func updateTranscript(id: UUID, transcript: String) {
        if let index = notes.firstIndex(where: { $0.id == id }) {
            notes[index].content = transcript
            notes[index].modifiedAt = Date()
            debouncedSave()
        }
    }
    
    /// Deletes a note by ID
    func deleteNote(id: UUID) {
        if let note = notes.first(where: { $0.id == id }) {
            // Clean up audio file for voice notes
            if let audioFileName = note.audioFileName {
                AudioService.shared.deleteAudioFile(fileName: audioFileName)
            }
            notes.removeAll { $0.id == id }
            save()
        }
    }
    
    /// Toggles pin status for a note
    func togglePin(id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isPinned.toggle()
        notes[index].modifiedAt = Date()
        save()
    }
    
    /// Force save any pending changes immediately
    func flushPendingChanges() {
        if hasPendingChanges {
            saveTask?.cancel()
            saveTask = nil
            hasPendingChanges = false
            save()
        }
    }
    
    // MARK: - Persistence
    
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            notes = try decoder.decode([Note].self, from: data)
        } catch {
            print("Failed to load notes: \(error)")
        }
    }
    
    private func save() {
        hasPendingChanges = false
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(notes)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save notes: \(error)")
        }
    }
    
    /// Debounced save to avoid excessive writes while typing
    private func debouncedSave() {
        hasPendingChanges = true
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            save()
        }
    }
}
