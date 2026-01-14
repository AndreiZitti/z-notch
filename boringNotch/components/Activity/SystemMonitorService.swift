import Foundation
import Combine
import IOKit

class SystemMonitorService: ObservableObject {
    static let shared = SystemMonitorService()
    
    @Published var currentStats: SystemStats = .empty
    @Published var history: [SystemStats] = []
    
    private var timer: Timer?
    private let refreshInterval: TimeInterval = 5.0
    private let maxHistoryCount = 24  // 2 minutes at 5s intervals
    
    // CPU tracking
    private var previousCPUTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?
    
    private init() {}
    
    func startMonitoring() {
        guard timer == nil else { return }
        
        // Initial sample
        updateStats()
        
        // Start timer
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateStats() {
        let cpu = getCPUUsage()
        let memory = getMemoryUsage()
        let gpu = getGPUUsage()
        
        let stats = SystemStats(
            timestamp: Date(),
            cpuUsage: cpu,
            memoryUsage: memory,
            gpuUsage: gpu
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentStats = stats
            self.history.append(stats)
            if self.history.count > self.maxHistoryCount {
                self.history.removeFirst()
            }
        }
    }
    
    // MARK: - CPU Usage (Mach API)
    
    private func getCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0
        
        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )
        
        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return 0
        }
        
        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0
        var totalNice: UInt64 = 0
        
        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            totalUser += UInt64(info[offset + Int(CPU_STATE_USER)])
            totalSystem += UInt64(info[offset + Int(CPU_STATE_SYSTEM)])
            totalIdle += UInt64(info[offset + Int(CPU_STATE_IDLE)])
            totalNice += UInt64(info[offset + Int(CPU_STATE_NICE)])
        }
        
        // Deallocate
        let size = vm_size_t(MemoryLayout<integer_t>.stride * Int(numCPUInfo))
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        
        // Calculate delta from previous sample
        var cpuUsage: Double = 0
        
        if let prev = previousCPUTicks {
            let userDelta = totalUser - prev.user
            let systemDelta = totalSystem - prev.system
            let idleDelta = totalIdle - prev.idle
            let niceDelta = totalNice - prev.nice
            
            let totalDelta = userDelta + systemDelta + idleDelta + niceDelta
            
            if totalDelta > 0 {
                cpuUsage = Double(userDelta + systemDelta + niceDelta) / Double(totalDelta) * 100.0
            }
        }
        
        previousCPUTicks = (totalUser, totalSystem, totalIdle, totalNice)
        
        return min(max(cpuUsage, 0), 100)
    }
    
    // MARK: - Memory Usage (Mach API)
    
    private func getMemoryUsage() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return 0
        }
        
        let pageSize = UInt64(vm_kernel_page_size)
        
        // Used memory = Active + Wired + Compressed
        let activeMemory = UInt64(stats.active_count) * pageSize
        let wiredMemory = UInt64(stats.wire_count) * pageSize
        let compressedMemory = UInt64(stats.compressor_page_count) * pageSize
        
        let usedMemory = activeMemory + wiredMemory + compressedMemory
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        
        let percentage = Double(usedMemory) / Double(totalMemory) * 100.0
        return min(max(percentage, 0), 100)
    }
    
    // MARK: - GPU Usage (IOKit)
    
    private func getGPUUsage() -> Double? {
        // Try to get GPU utilization from IOKit
        var iterator: io_iterator_t = 0
        
        let matchDict = IOServiceMatching("IOAccelerator")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator)
        
        guard result == KERN_SUCCESS else {
            return nil
        }
        
        defer { IOObjectRelease(iterator) }
        
        var gpuUtilization: Double?
        var service = IOIteratorNext(iterator)
        
        while service != 0 {
            defer { 
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            
            var properties: Unmanaged<CFMutableDictionary>?
            let propResult = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
            
            guard propResult == KERN_SUCCESS, let props = properties?.takeRetainedValue() as? [String: Any] else {
                continue
            }
            
            // Look for PerformanceStatistics
            if let perfStats = props["PerformanceStatistics"] as? [String: Any] {
                // Try different keys that might contain GPU utilization
                if let utilization = perfStats["Device Utilization %"] as? Int {
                    gpuUtilization = Double(utilization)
                    break
                } else if let utilization = perfStats["GPU Activity(%)"] as? Int {
                    gpuUtilization = Double(utilization)
                    break
                } else if let utilization = perfStats["hardwareWaitTime"] as? Int,
                          let totalTime = perfStats["allGPUTime"] as? Int,
                          totalTime > 0 {
                    // Calculate utilization from wait time
                    gpuUtilization = Double(totalTime - utilization) / Double(totalTime) * 100.0
                    break
                }
            }
        }
        
        if let util = gpuUtilization {
            return min(max(util, 0), 100)
        }
        
        return nil
    }
}
