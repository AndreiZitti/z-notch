//
//  AudioService.swift
//  boringNotch
//
//  Handles audio recording, playback, and speech transcription for voice notes
//

import Foundation
import AVFoundation
import Speech
import Combine

@MainActor
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
    
    // MARK: - Permission
    
    @Published var permissionGranted: Bool = false
    @Published var permissionDenied: Bool = false
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            permissionGranted = true
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor in
                    self?.permissionGranted = granted
                    self?.permissionDenied = !granted
                    completion(granted)
                }
            }
        case .denied, .restricted:
            permissionDenied = true
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    // MARK: - Recording
    
    func startRecording() -> String? {
        // Check permission first
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        guard status == .authorized else {
            print("Microphone permission not granted. Status: \(status.rawValue)")
            return nil
        }
        
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
            
            let started = audioRecorder?.record() ?? false
            if !started {
                print("Failed to start recording")
                return nil
            }
            
            isRecording = true
            recordingTime = 0
            audioLevel = 0
            
            // Start timers on main run loop
            startRecordingTimers()
            
            print("Recording started: \(fileName)")
            return fileName
        } catch {
            print("Failed to start recording: \(error)")
            return nil
        }
    }
    
    private func startRecordingTimers() {
        // Update recording time every 0.1 seconds
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingTime += 0.1
            }
        }
        
        // Update audio levels every 0.05 seconds
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let recorder = self.audioRecorder else { return }
                recorder.updateMeters()
                let power = recorder.averagePower(forChannel: 0)
                // Normalize from dB (-60 to 0) to 0-1 range
                let normalizedLevel = max(0, min(1, (power + 60) / 60))
                self.audioLevel = normalizedLevel
            }
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
        _ = stopRecording()
        if let fileName = fileName {
            deleteAudioFile(fileName: fileName)
        }
    }
    
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
}

// MARK: - AVAudioPlayerDelegate

extension AudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.stopPlayback()
        }
    }
}
