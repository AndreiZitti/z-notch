//
//  FullscreenMediaDetection.swift
//  boringNotch
//
//  Created by Richard Kunkli on 06/09/2024.
//

import Foundation
import Combine
import Defaults
import AppKit

// Note: FullScreenMonitor requires MacroVisionKit 0.2.0+ which needs Swift 6.1/Xcode 16.3+
// This is a simplified fallback implementation for older Xcode versions

@MainActor
final class FullscreenMediaDetector: ObservableObject {
    static let shared = FullscreenMediaDetector()

    @Published var fullscreenStatus: [String: Bool] = [:]

    private var timer: Timer?

    private init() {
        startMonitoring()
    }

    deinit {
        timer?.invalidate()
    }

    private func startMonitoring() {
        // Fallback: Poll for fullscreen status using NSApplication
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkFullscreenStatus()
            }
        }
    }

    private func checkFullscreenStatus() {
        var newStatus: [String: Bool] = [:]

        for screen in NSScreen.screens {
            let screenUUID = screen.uuid
            // Check if any window is in fullscreen on this screen
            let isFullscreen = NSApplication.shared.windows.contains { window in
                window.screen == screen && window.styleMask.contains(.fullScreen)
            }
            newStatus[screenUUID] = isFullscreen
        }

        self.fullscreenStatus = newStatus
    }
}

extension NSScreen {
    var uuid: String {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return "unknown"
        }
        return String(screenNumber)
    }
}

