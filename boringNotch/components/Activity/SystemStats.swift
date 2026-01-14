import Foundation

struct SystemStats: Identifiable {
    let id = UUID()
    let timestamp: Date
    let cpuUsage: Double      // 0-100
    let memoryUsage: Double   // 0-100
    let gpuUsage: Double?     // 0-100, nil if unavailable
    
    static let empty = SystemStats(
        timestamp: Date(),
        cpuUsage: 0,
        memoryUsage: 0,
        gpuUsage: nil
    )
}
