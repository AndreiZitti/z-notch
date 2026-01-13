//
//  DisplaySleepHelper.swift
//  boringNotch
//
//  Puts the display to sleep using IOKit
//

import Foundation
import IOKit

class DisplaySleepHelper {
    /// Put the display to sleep using IODisplayWrangler
    static func sleepDisplay() {
        let wranglerPath = "IOService:/IOResources/IODisplayWrangler"
        let wrangler = IORegistryEntryFromPath(kIOMainPortDefault, wranglerPath)

        guard wrangler != 0 else {
            print("DisplaySleepHelper: Failed to get IODisplayWrangler")
            return
        }

        defer { IOObjectRelease(wrangler) }

        let result = IORegistryEntrySetCFProperty(wrangler, "IORequestIdle" as CFString, kCFBooleanTrue)

        if result != KERN_SUCCESS {
            print("DisplaySleepHelper: Failed to set IORequestIdle, error: \(result)")
        }
    }
}
