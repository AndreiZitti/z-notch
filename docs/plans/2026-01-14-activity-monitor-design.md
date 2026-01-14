# Activity Monitor Tab Design

## Overview

Add a new "Activity" tab to the notch that displays system resource usage (CPU, Memory, GPU) with compact gauges that expand to show historical graphs when clicked.

**Use case:** Monitor ML training jobs and system resource usage at a glance.

## Layout

### Default View (Gauges Only)
```
┌─────────────────────────────────────────────────────────┐
│  [CPU ◐ 45%]   [MEM ◐ 67%]   [GPU ◐ 82%]              │
└─────────────────────────────────────────────────────────┘
```

Three circular gauge widgets side-by-side showing:
- Icon/label
- Percentage in center
- Colored ring (green → yellow → red based on usage)

### Expanded View (After clicking a gauge)
```
┌─────────────────────────────────────────────────────────┐
│  [CPU ◐ 45%]   [MEM ◐ 67%]   [GPU ◐ 82%]              │
├─────────────────────────────────────────────────────────┤
│  ▁▂▃▅▆▇█▇▅▃▂▁▂▃▅▆▇█▇▅▃▂▁▂▃  (CPU graph - last 2 min)  │
└─────────────────────────────────────────────────────────┘
```

Clicking a gauge toggles a line graph below showing ~2 minutes of history.
Multiple graphs can be open at once, stacking vertically.

## Technical Architecture

### Files

Create in `boringNotch/components/Activity/`:

| File | Purpose |
|------|---------|
| `SystemStats.swift` | Model struct: CPU %, Memory %, GPU %, timestamp |
| `SystemMonitorService.swift` | Singleton polling service, stores 2min history |
| `ActivityView.swift` | Main view with three gauges, click-to-expand |
| `GaugeView.swift` | Reusable circular gauge component |
| `MiniGraphView.swift` | Line chart component for history |

### System APIs

```swift
// CPU: Mach API
host_statistics() + HOST_CPU_LOAD_INFO
→ Calculate delta ticks between polls for percentage

// Memory: Mach API
host_statistics64() + HOST_VM_INFO64
→ Used = active + wired + compressed
→ Total = ProcessInfo.processInfo.physicalMemory

// GPU: IOKit (private API)
IOServiceMatching("IOAccelerator")
→ Read "PerformanceStatistics" → "Device Utilization %"
```

### Service Pattern

```swift
class SystemMonitorService: ObservableObject {
    static let shared = SystemMonitorService()

    @Published var currentStats: SystemStats
    @Published var history: [SystemStats]  // Circular buffer, 24 entries

    private var timer: Timer?
    private let refreshInterval: TimeInterval = 5.0
}
```

- Timer fires every 5 seconds
- History = 24 entries = 2 minutes of data
- Views observe via `@StateObject`

## Visual Design

### Gauge Component
- Circular ring, ~50pt diameter
- Ring thickness: 6pt
- Background ring: gray (opacity 0.2)
- Foreground ring color by value:
  - 0-50%: Green (`#34C759`)
  - 50-80%: Yellow (`#FFD60A`)
  - 80-100%: Red (`#FF3B30`)
- Center: percentage (bold) + label (small)
- Subtle glow when > 80%

### Graph Component
- Height: ~60pt when expanded
- Smooth line chart (SwiftUI Path with curves)
- Filled gradient below line (gauge color → transparent)
- Animated slide-down on toggle

### Interactions
- Tap gauge: scale animation (0.95 → 1.0)
- Graph: spring animation on toggle
- Selected gauge: subtle border highlight

## Error Handling

### GPU Fallback
- If IOKit unavailable → show "N/A" in gauge
- Log warning, don't crash
- CPU/Memory continue normally

### Memory Calculation
- Used = Active + Wired + Compressed
- Total = physicalMemory
- Percentage = Used / Total × 100

### History Buffer
- Fixed 24 entries (2 min at 5s intervals)
- Starts empty on launch, fills over time
- Graph draws whatever exists

### Performance
- Timer pauses when notch collapsed
- Timer resumes when Activity tab visible
- ~0.1% CPU overhead at 5s polling

### App Lifecycle
- Service starts on first Activity tab access
- Continues in background (builds history)
- No persistence - resets on app restart

## Integration

### Enum Case
Add to `boringNotch/enums/generic.swift`:
```swift
case activity
```

### Tab Definition
Add to `TabSelectionView.swift`:
```swift
TabModel(label: "Activity", icon: "chart.bar.fill", view: .activity)
```

### View Switch
Add to `ContentView.swift`:
```swift
case .activity:
    ActivityView()
```

## References

- [SystemKit](https://github.com/beltex/SystemKit) - Mach API examples
- [Stats](https://github.com/exelban/stats) - macOS menu bar monitor
- [macmon](https://medium.com/@vladkens/mac-usage-monitor-in-terminal-meet-macmon-3a3391995224) - Apple Silicon GPU monitoring
