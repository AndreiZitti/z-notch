//
//  VoiceRecorderView.swift
//  boringNotch
//
//  Voice recording interface with waveform visualization
//

import SwiftUI
import AppKit

struct VoiceRecorderView: View {
    @ObservedObject private var audioService = AudioService.shared
    @State private var currentFileName: String?
    @State private var recordedDuration: TimeInterval = 0
    @State private var hasCheckedPermission = false
    
    let onCancel: () -> Void
    let onSave: (String, TimeInterval) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Header with recording indicator
            HStack {
                Button(action: cancel) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.callout)
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Recording indicator
                if audioService.isRecording {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("REC")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.2))
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                Button(action: save) {
                    Text("Done")
                        .font(.callout.weight(.medium))
                        .foregroundColor(recordedDuration > 0 && !audioService.isRecording ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(recordedDuration <= 0 || audioService.isRecording)
            }
            
            Spacer()
            
            // Waveform visualization
            WaveformView(level: audioService.audioLevel, isActive: audioService.isRecording)
                .frame(height: 50)
                .padding(.horizontal, 16)
            
            // Timer - larger and more prominent when recording
            Text(formatTime(audioService.isRecording ? audioService.recordingTime : recordedDuration))
                .font(.system(size: audioService.isRecording ? 32 : 24, weight: .light, design: .monospaced))
                .foregroundColor(audioService.isRecording ? .red : .primary)
                .animation(.easeInOut(duration: 0.2), value: audioService.isRecording)
            
            // Record button with pulse animation
            Button(action: toggleRecording) {
                ZStack {
                    // Pulse ring when recording
                    if audioService.isRecording {
                        Circle()
                            .stroke(Color.red.opacity(0.3), lineWidth: 4)
                            .frame(width: 76, height: 76)
                    }
                    
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
            Text(hintText)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if !hasCheckedPermission {
                hasCheckedPermission = true
                audioService.requestMicrophonePermission { granted in
                    print("Microphone permission: \(granted)")
                }
            }
        }
        .overlay {
            // Permission denied overlay
            if audioService.permissionDenied {
                VStack(spacing: 12) {
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.red)
                    Text("Microphone Access Denied")
                        .font(.headline)
                    Text("Enable in System Settings → Privacy & Security → Microphone")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Open Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
            }
        }
    }
    
    private var hintText: String {
        if audioService.isRecording {
            return "Tap to stop recording"
        } else if recordedDuration > 0 {
            return "Tap Done to save, or record again"
        } else {
            return "Tap the microphone to start"
        }
    }
    
    private func toggleRecording() {
        if audioService.isRecording {
            recordedDuration = audioService.stopRecording()
        } else {
            currentFileName = audioService.startRecording()
            recordedDuration = 0
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
        // Use stored duration (captured when recording stopped)
        let duration = recordedDuration > 0 ? recordedDuration : audioService.recordingTime
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
