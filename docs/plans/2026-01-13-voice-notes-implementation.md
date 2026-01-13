# Voice Notes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add voice recording with transcription to the Notes feature, with a redesigned three-column UI.

**Architecture:** Extend `Note` model with type/audio fields, create `AudioService` for recording/playback/transcription, rewrite `NotesView` as three-column layout with state machine navigation.

**Tech Stack:** SwiftUI, AVFoundation (recording/playback), Speech framework (transcription), Combine (audio levels)

---

## Task 1: Extend Note Model

**Files:**
- Modify: `boringNotch/components/Notes/Note.swift`

**Step 1: Add NoteType enum**

Add before the `Note` struct:

```swift
public enum NoteType: String, Codable {
    case text
    case voice
}
```

**Step 2: Add voice properties to Note**

Add these properties to the `Note` struct after `isPinned`:

```swift
var type: NoteType
var audioFileName: String?
var audioDuration: TimeInterval?
```

**Step 3: Update init with defaults for backward compatibility**

Replace the existing init:

```swift
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
```

**Step 4: Add formatted duration computed property**

Add after `timeAgo`:

```swift
/// Formatted duration string for voice notes (e.g., "1:23")
var formattedDuration: String {
    guard let duration = audioDuration else { return "" }
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%d:%02d", minutes, seconds)
}
```

**Step 5: Build and verify**

Run: `xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug build 2>&1 | grep -E "(error:|warning:|BUILD)"` 

Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add boringNotch/components/Notes/Note.swift
git commit -m "feat(notes): extend Note model with voice note support"
```

---

## Task 2: Create AudioService

**Files:**
- Create: `boringNotch/components/Notes/AudioService.swift`

**Step 1: Create AudioService file with basic structure**

```swift
import Foundation
import AVFoundation
import Speech
import Combine

class AudioService: NSObject, ObservableObject {
    static let shared = AudioService()
    
    // MARK: - Published State
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordingTime: TimeInterval = 0
    @Published var playbackTime: TimeInterval = 0
    @Published var playbackDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0
    
    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var playbackTimer: Timer?
    
    private var voiceNotesDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("boringNotch/voice_notes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    override private init() {
        super.init()
    }
}
```

**Step 2: Add recording methods**

Add after init:

```swift
// MARK: - Recording

func startRecording() -> String? {
    let fileName = UUID().uuidString + ".m4a"
    let fileURL = voiceNotesDirectory.appendingPathComponent(fileName)
    
    let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44100,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
    
    do {
        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()
        
        isRecording = true
        recordingTime = 0
        
        // Update recording time
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingTime += 0.1
        }
        
        // Update audio levels
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.audioRecorder?.updateMeters()
            let level = self?.audioRecorder?.averagePower(forChannel: 0) ?? -160
            // Normalize from dB (-160 to 0) to 0-1 range
            self?.audioLevel = max(0, (level + 50) / 50)
        }
        
        return fileName
    } catch {
        print("Failed to start recording: \(error)")
        return nil
    }
}

func stopRecording() -> TimeInterval {
    recordingTimer?.invalidate()
    levelTimer?.invalidate()
    recordingTimer = nil
    levelTimer = nil
    
    let duration = recordingTime
    
    audioRecorder?.stop()
    audioRecorder = nil
    isRecording = false
    audioLevel = 0
    
    return duration
}

func cancelRecording(fileName: String?) {
    stopRecording()
    if let fileName = fileName {
        deleteAudioFile(fileName: fileName)
    }
}
```

**Step 3: Add playback methods**

Add after recording methods:

```swift
// MARK: - Playback

func playAudio(fileName: String) {
    let fileURL = voiceNotesDirectory.appendingPathComponent(fileName)
    
    do {
        audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
        audioPlayer?.delegate = self
        audioPlayer?.play()
        
        isPlaying = true
        playbackDuration = audioPlayer?.duration ?? 0
        playbackTime = 0
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.playbackTime = self?.audioPlayer?.currentTime ?? 0
        }
    } catch {
        print("Failed to play audio: \(error)")
    }
}

func pauseAudio() {
    audioPlayer?.pause()
    isPlaying = false
    playbackTimer?.invalidate()
}

func resumeAudio() {
    audioPlayer?.play()
    isPlaying = true
    playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
        self?.playbackTime = self?.audioPlayer?.currentTime ?? 0
    }
}

func seekTo(_ time: TimeInterval) {
    audioPlayer?.currentTime = time
    playbackTime = time
}

func stopPlayback() {
    playbackTimer?.invalidate()
    playbackTimer = nil
    audioPlayer?.stop()
    audioPlayer = nil
    isPlaying = false
    playbackTime = 0
}
```

**Step 4: Add file management and transcription**

Add after playback methods:

```swift
// MARK: - File Management

func deleteAudioFile(fileName: String) {
    let fileURL = voiceNotesDirectory.appendingPathComponent(fileName)
    try? FileManager.default.removeItem(at: fileURL)
}

func audioFileURL(for fileName: String) -> URL {
    voiceNotesDirectory.appendingPathComponent(fileName)
}

// MARK: - Transcription

func transcribe(fileName: String, completion: @escaping (String?) -> Void) {
    let fileURL = voiceNotesDirectory.appendingPathComponent(fileName)
    
    SFSpeechRecognizer.requestAuthorization { status in
        guard status == .authorized else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = false
        
        recognizer.recognitionTask(with: request) { result, error in
            DispatchQueue.main.async {
                if let result = result, result.isFinal {
                    completion(result.bestTranscription.formattedString)
                } else {
                    completion(nil)
                }
            }
        }
    }
}
```

**Step 5: Add AVAudioPlayerDelegate conformance**

Add at the end of the file:

```swift
// MARK: - AVAudioPlayerDelegate

extension AudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.stopPlayback()
        }
    }
}
```

**Step 6: Add file to Xcode project, build and verify**

Manually add file to Xcode project, then:

Run: `xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug build 2>&1 | grep -E "(error:|warning:|BUILD)"`

Expected: BUILD SUCCEEDED

**Step 7: Commit**

```bash
git add boringNotch/components/Notes/AudioService.swift boringNotch.xcodeproj/project.pbxproj
git commit -m "feat(notes): add AudioService for recording, playback, and transcription"
```

---

## Task 3: Update NotesService for Voice Notes

**Files:**
- Modify: `boringNotch/components/Notes/NotesService.swift`

**Step 1: Add voice note creation method**

Add after `createNote()`:

```swift
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
```

**Step 2: Add transcript update method**

Add after `updateNote(_:)`:

```swift
func updateTranscript(id: UUID, transcript: String) {
    if let index = notes.firstIndex(where: { $0.id == id }) {
        notes[index].content = transcript
        notes[index].modifiedAt = Date()
        debouncedSave()
    }
}
```

**Step 3: Update deleteNote to clean up audio files**

Replace the existing `deleteNote(id:)`:

```swift
func deleteNote(id: UUID) {
    if let note = notes.first(where: { $0.id == id }) {
        // Clean up audio file for voice notes
        if let audioFileName = note.audioFileName {
            AudioService.shared.deleteAudioFile(fileName: audioFileName)
        }
        notes.removeAll { $0.id == id }
        debouncedSave()
    }
}
```

**Step 4: Build and verify**

Run: `xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug build 2>&1 | grep -E "(error:|warning:|BUILD)"`

Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add boringNotch/components/Notes/NotesService.swift
git commit -m "feat(notes): extend NotesService with voice note CRUD"
```

---

## Task 4: Update NoteRowView for Voice Notes

**Files:**
- Modify: `boringNotch/components/Notes/NoteRowView.swift`

**Step 1: Read current NoteRowView implementation**

Understand the current structure before modifying.

**Step 2: Add type icon to the row**

Update the row to show a microphone icon for voice notes and include duration. The icon should appear before the preview text.

Add to the HStack showing note content:

```swift
// Type icon
Image(systemName: note.type == .voice ? "mic.fill" : "note.text")
    .font(.caption)
    .foregroundColor(note.type == .voice ? .red : .secondary)
```

**Step 3: Show duration for voice notes**

Where the time is displayed, also show duration for voice notes:

```swift
if note.type == .voice, !note.formattedDuration.isEmpty {
    Text(note.formattedDuration)
        .font(.caption2)
        .foregroundColor(.secondary)
}
```

**Step 4: Build and verify**

Run: `xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug build 2>&1 | grep -E "(error:|warning:|BUILD)"`

Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add boringNotch/components/Notes/NoteRowView.swift
git commit -m "feat(notes): add voice note indicators to NoteRowView"
```

---

## Task 5: Create VoiceRecorderView

**Files:**
- Create: `boringNotch/components/Notes/VoiceRecorderView.swift`

**Step 1: Create the voice recorder view**

```swift
import SwiftUI

struct VoiceRecorderView: View {
    @ObservedObject private var audioService = AudioService.shared
    @State private var currentFileName: String?
    
    let onCancel: () -> Void
    let onSave: (String, TimeInterval) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Button(action: cancel) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.callout)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: save) {
                    Text("Done")
                        .font(.callout.weight(.medium))
                        .foregroundColor(currentFileName != nil && !audioService.isRecording ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(currentFileName == nil || audioService.isRecording)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            Spacer()
            
            // Waveform visualization
            WaveformView(level: audioService.audioLevel, isActive: audioService.isRecording)
                .frame(height: 40)
                .padding(.horizontal, 20)
            
            // Timer
            Text(formatTime(audioService.recordingTime))
                .font(.system(size: 24, weight: .light, design: .monospaced))
                .foregroundColor(.primary)
            
            // Record button
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(audioService.isRecording ? Color.red : Color(nsColor: .controlBackgroundColor))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: audioService.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 24))
                        .foregroundColor(audioService.isRecording ? .white : .red)
                }
            }
            .buttonStyle(.plain)
            
            // Hint text
            Text(audioService.isRecording ? "Tap to stop" : (currentFileName != nil ? "Tap Done to save" : "Tap to record"))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func toggleRecording() {
        if audioService.isRecording {
            _ = audioService.stopRecording()
        } else {
            currentFileName = audioService.startRecording()
        }
    }
    
    private func cancel() {
        if audioService.isRecording {
            audioService.cancelRecording(fileName: currentFileName)
        } else if let fileName = currentFileName {
            audioService.deleteAudioFile(fileName: fileName)
        }
        onCancel()
    }
    
    private func save() {
        guard let fileName = currentFileName else { return }
        let duration = audioService.recordingTime
        onSave(fileName, duration)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

// MARK: - Waveform Visualization

struct WaveformView: View {
    let level: Float
    let isActive: Bool
    
    private let barCount = 20
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    height: barHeight(for: index),
                    isActive: isActive
                )
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        guard isActive else { return 4 }
        
        // Create varied heights based on level and position
        let centerDistance = abs(CGFloat(index) - CGFloat(barCount) / 2) / CGFloat(barCount) * 2
        let variation = sin(Double(index) * 0.5 + Double(level) * 10) * 0.3 + 0.7
        let height = CGFloat(level) * (1 - centerDistance * 0.5) * CGFloat(variation)
        
        return max(4, height * 36 + 4)
    }
}

struct WaveformBar: View {
    let height: CGFloat
    let isActive: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(isActive ? Color.red : Color.secondary.opacity(0.3))
            .frame(width: 4, height: height)
            .animation(.easeOut(duration: 0.1), value: height)
    }
}
```

**Step 2: Add file to Xcode project, build and verify**

Manually add file to Xcode project, then:

Run: `xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug build 2>&1 | grep -E "(error:|warning:|BUILD)"`

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add boringNotch/components/Notes/VoiceRecorderView.swift boringNotch.xcodeproj/project.pbxproj
git commit -m "feat(notes): add VoiceRecorderView with waveform visualization"
```

---

## Task 6: Create VoicePlayerView

**Files:**
- Create: `boringNotch/components/Notes/VoicePlayerView.swift`

**Step 1: Create the voice player view**

```swift
import SwiftUI

struct VoicePlayerView: View {
    let note: Note
    let onBack: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    
    @ObservedObject private var audioService = AudioService.shared
    @State private var isLoaded = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Button(action: {
                    audioService.stopPlayback()
                    onBack()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.callout)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: onTogglePin) {
                    Image(systemName: note.isPinned ? "pin.fill" : "pin")
                        .font(.callout)
                        .foregroundColor(note.isPinned ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    audioService.stopPlayback()
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            Spacer()
            
            // Play button
            Button(action: togglePlayback) {
                ZStack {
                    Circle()
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: audioService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                }
            }
            .buttonStyle(.plain)
            
            // Progress bar
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Track
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 4)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor)
                            .frame(width: progressWidth(in: geometry.size.width), height: 4)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let progress = value.location.x / geometry.size.width
                                let time = Double(progress) * (note.audioDuration ?? 0)
                                audioService.seekTo(max(0, min(time, note.audioDuration ?? 0)))
                            }
                    )
                }
                .frame(height: 20)
                
                // Time labels
                HStack {
                    Text(formatTime(audioService.playbackTime))
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatTime(note.audioDuration ?? 0))
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            
            // Transcript section
            VStack(alignment: .leading, spacing: 8) {
                Text("Transcript")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                
                ScrollView {
                    Text(note.content.isEmpty ? "Transcription unavailable" : note.content)
                        .font(.callout)
                        .foregroundColor(note.content.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if let fileName = note.audioFileName {
                audioService.playbackDuration = note.audioDuration ?? 0
            }
        }
        .onDisappear {
            audioService.stopPlayback()
        }
    }
    
    private func togglePlayback() {
        guard let fileName = note.audioFileName else { return }
        
        if audioService.isPlaying {
            audioService.pauseAudio()
        } else if audioService.playbackTime > 0 {
            audioService.resumeAudio()
        } else {
            audioService.playAudio(fileName: fileName)
        }
    }
    
    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard let duration = note.audioDuration, duration > 0 else { return 0 }
        return CGFloat(audioService.playbackTime / duration) * totalWidth
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
```

**Step 2: Add file to Xcode project, build and verify**

Manually add file to Xcode project, then:

Run: `xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug build 2>&1 | grep -E "(error:|warning:|BUILD)"`

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add boringNotch/components/Notes/VoicePlayerView.swift boringNotch.xcodeproj/project.pbxproj
git commit -m "feat(notes): add VoicePlayerView with playback controls and transcript"
```

---

## Task 7: Rewrite NotesView with Three-Column Layout

**Files:**
- Modify: `boringNotch/components/Notes/NotesView.swift`

**Step 1: Define view mode enum**

Add before the struct:

```swift
enum NotesViewMode: Equatable {
    case main
    case creatingText
    case creatingVoice
    case viewingNote(UUID)
}
```

**Step 2: Rewrite NotesView**

Replace the entire struct with:

```swift
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
                let note = service.createNote()
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
```

**Step 3: Build and verify**

Run: `xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug build 2>&1 | grep -E "(error:|warning:|BUILD)"`

Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add boringNotch/components/Notes/NotesView.swift
git commit -m "feat(notes): rewrite NotesView with three-column layout"
```

---

## Task 8: Add Required Permissions

**Files:**
- Modify: `boringNotch/Info.plist` (or entitlements file)

**Step 1: Find the Info.plist location**

Run: `find boringNotch -name "Info.plist" -o -name "*.entitlements" 2>/dev/null`

**Step 2: Add microphone usage description**

Add to Info.plist:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>boringNotch needs microphone access to record voice notes.</string>
```

**Step 3: Add speech recognition usage description**

Add to Info.plist:

```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>boringNotch uses speech recognition to transcribe voice notes.</string>
```

**Step 4: Build and verify**

Run: `xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug build 2>&1 | grep -E "(error:|warning:|BUILD)"`

Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add boringNotch/Info.plist
git commit -m "feat(notes): add microphone and speech recognition permissions"
```

---

## Task 9: Manual Testing & Final Polish

**Step 1: Build and run the app**

```bash
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug build
```

**Step 2: Test checklist**

- [ ] Three-column layout displays correctly
- [ ] Write button creates and opens text note
- [ ] Voice button opens recorder
- [ ] Recording shows waveform and timer
- [ ] Saving voice note adds to library with mic icon
- [ ] Transcription appears after a few seconds
- [ ] Tapping voice note opens player
- [ ] Playback controls work (play/pause/seek)
- [ ] Tapping text note opens editor
- [ ] Search filters both text and voice notes
- [ ] Delete works for both note types
- [ ] Pin works for both note types

**Step 3: Fix any issues discovered**

Address bugs found during testing.

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat(notes): complete voice notes feature with testing fixes"
```
