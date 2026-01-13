//
//  VoicePlayerView.swift
//  boringNotch
//
//  Voice note playback interface with controls and transcript display
//

import SwiftUI

struct VoicePlayerView: View {
    let note: Note
    let onBack: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    
    @ObservedObject private var audioService = AudioService.shared
    
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
                    Text(transcriptText)
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
            audioService.playbackDuration = note.audioDuration ?? 0
        }
        .onDisappear {
            audioService.stopPlayback()
        }
    }
    
    private var transcriptText: String {
        if note.content.isEmpty {
            return "Transcription unavailable"
        }
        return note.content
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
