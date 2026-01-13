# Voice Notes Feature Design

## Overview

Extend the Notes feature to support voice recordings with automatic transcription, alongside a redesigned three-column UI that prioritizes note creation.

## Decisions Summary

| Aspect | Decision |
|--------|----------|
| Voice storage | Audio file (.m4a) + transcript |
| Library display | Unified list, 🎤 icon for voice notes |
| Recording UI | Minimal: mic button, waveform, done |
| Text creation | Dedicated screen (existing flow) |
| Layout proportions | 35% / 35% / 30% (buttons dominant) |
| View existing notes | Full takeover |

---

## Data Model

The `Note` model will be extended to support both text and voice notes:

```swift
struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    var content: String           // Text content OR transcript
    let createdAt: Date
    var modifiedAt: Date
    var isPinned: Bool
    
    // Voice note support
    var type: NoteType            // .text or .voice
    var audioFileName: String?    // "uuid.m4a" for voice notes
    var audioDuration: TimeInterval?  // Length in seconds
}

enum NoteType: String, Codable {
    case text
    case voice
}
```

**Audio storage:** Voice recordings saved as `.m4a` files in `~/Library/Application Support/boringNotch/voice_notes/`. The `audioFileName` links to the file.

**Transcript:** When recording finishes, macOS `SFSpeechRecognizer` transcribes the audio. The transcript goes in `content`, so voice notes are searchable just like text notes.

**Backward compatibility:** Existing notes without a `type` field default to `.text`, so current notes.json migrates seamlessly.

---

## Main View Layout

The main view transforms from a single-column list to a three-column layout:

```
┌─────────────────────────────────────────────────────────────────┐
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │             │  │             │  │ 🔍 Search...            │  │
│  │     📝      │  │     🎤      │  ├─────────────────────────┤  │
│  │             │  │             │  │ 🎤 Meeting thoughts  2m │  │
│  │   Write     │  │   Voice     │  │ 📝 Todo list        5m  │  │
│  │   Note      │  │   Note      │  │ 📝 Ideas           12m  │  │
│  │             │  │             │  │ 🎤 Quick reminder   1h  │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
│     ~35%              ~35%                  ~30%                 │
└─────────────────────────────────────────────────────────────────┘
```

**Left & Middle columns:** Large rounded buttons with icon + label. Tapping transitions to the respective creation screen.

**Right column (Library):** Compact vertical list with:
- Search bar at top
- Each row: type icon (📝/🎤) + preview text + time ago
- Voice notes also show duration
- Tap → full takeover to view/edit/play

**State management:** New `notesViewMode` enum:
- `.main` — three-column layout
- `.creatingText` — text editor (existing NoteDetailView)
- `.creatingVoice` — voice recorder
- `.viewingNote(UUID)` — viewing/editing existing note

---

## Voice Recording Screen

When tapping "Voice Note", the view transitions to a minimal recording interface:

```
┌─────────────────────────────────────────────────────────────────┐
│  ← Back                                              Done ✓     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│                        ○ ○ ○ ○ ○ ○ ○ ○ ○                       │
│                      ~~~waveform bars~~~                        │
│                                                                 │
│                          0:00:12                                │
│                                                                 │
│                      ┌───────────┐                              │
│                      │     ⏺     │  ← Big mic button            │
│                      │           │    (red when recording)      │
│                      └───────────┘                              │
│                     Tap to record                               │
└─────────────────────────────────────────────────────────────────┘
```

**Components:**
- **Back button:** Cancels and returns to main view (discards recording)
- **Done button:** Saves note, triggers transcription, returns to main view
- **Waveform:** Real-time audio level visualization (simple bars)
- **Timer:** Shows elapsed recording time
- **Mic button:** Tap to start, tap again to stop. Toggles red/gray state.

**Recording flow:**
1. Tap mic → starts `AVAudioRecorder`, button turns red, timer starts
2. Tap mic again → stops recording, button turns gray
3. Tap "Done" → saves audio file, kicks off `SFSpeechRecognizer` transcription in background, adds note to library, returns to main view

**Transcription:** Happens async after save. Note appears immediately with "Transcribing..." placeholder, updates when complete.

---

## Voice Note Playback

When tapping an existing voice note in the library:

```
┌─────────────────────────────────────────────────────────────────┐
│  ← Back                                    📌  🗑               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│                      ┌───────────┐                              │
│                      │     ▶     │  ← Play/Pause button         │
│                      └───────────┘                              │
│                                                                 │
│            ────●───────────────────────                         │
│           0:15                    1:23                          │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  Transcript                                                     │
│  ─────────────────────────────────────────────────────────────  │
│  "Meeting notes: discussed the Q4 roadmap, need to follow up    │
│   with design team about the new dashboard..."                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Components:**
- **Header:** Back button, pin toggle, delete button (matches text note detail)
- **Player:** Large play/pause button, scrubber with current time/duration
- **Transcript section:** Read-only display of transcribed text (scrollable if long)

**Audio playback:** Uses `AVAudioPlayer` for simple play/pause/seek.

**No editing:** Unlike text notes, voice notes can't be edited — just played back and read. User can delete and re-record if needed.

---

## File Structure

New and modified files:

```
boringNotch/components/Notes/
├── Note.swift              # MODIFY: Add type, audioFileName, audioDuration
├── NotesService.swift      # MODIFY: Add voice note CRUD, audio file management
├── NotesView.swift         # REWRITE: Three-column layout + state management
├── NoteDetailView.swift    # KEEP: Text note editor (minor tweaks)
├── NoteRowView.swift       # MODIFY: Add voice icon, duration display
├── VoiceRecorderView.swift # NEW: Recording screen
├── VoicePlayerView.swift   # NEW: Playback screen
└── AudioService.swift      # NEW: AVAudioRecorder/Player + SFSpeechRecognizer
```

**AudioService responsibilities:**
- `startRecording()` / `stopRecording()` → manages `AVAudioRecorder`
- `playAudio(fileName:)` / `pauseAudio()` / `seekTo(_:)` → manages `AVAudioPlayer`
- `transcribe(audioURL:completion:)` → async speech recognition
- `deleteAudioFile(fileName:)` → cleanup when note deleted
- `audioLevelPublisher` → real-time levels for waveform visualization

---

## Permissions

The app requires:
- **Microphone access** — `NSMicrophoneUsageDescription` in Info.plist
- **Speech Recognition** — `NSSpeechRecognitionUsageDescription` in Info.plist

First voice note attempt prompts user for permission.

---

## Error Handling

- **Transcription fails:** Note saves with empty transcript, shows "Transcription unavailable"
- **Microphone denied:** Show alert explaining how to enable in System Preferences
- **Audio file missing:** Show error state in player, offer to delete corrupted note

---

## User Flow Summary

1. **Main view** → Three columns with big add buttons + compact library
2. **Tap "Write Note"** → Text editor, type, back to save
3. **Tap "Voice Note"** → Recorder, tap mic, record, done to save
4. **Tap library item** → Full editor (text) or player (voice)
5. **Transcription** → Happens in background, note searchable once complete
