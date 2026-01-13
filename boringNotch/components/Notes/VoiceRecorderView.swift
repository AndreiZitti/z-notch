//
//  VoiceRecorderView.swift
//  boringNotch
//
//  Voice recording interface with waveform visualization
//

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
