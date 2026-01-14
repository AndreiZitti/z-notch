import SwiftUI

enum ActivityMetric: String, CaseIterable {
    case cpu = "CPU"
    case memory = "MEM"
    case gpu = "GPU"
}

struct ActivityView: View {
    @StateObject private var service = SystemMonitorService.shared
    @State private var expandedMetrics: Set<ActivityMetric> = []
    
    var body: some View {
        VStack(spacing: 12) {
            // Gauges row
            HStack(spacing: 16) {
                GaugeView(
                    label: "CPU",
                    value: service.currentStats.cpuUsage,
                    isSelected: expandedMetrics.contains(.cpu),
                    onTap: { toggleMetric(.cpu) }
                )
                
                GaugeView(
                    label: "MEM",
                    value: service.currentStats.memoryUsage,
                    isSelected: expandedMetrics.contains(.memory),
                    onTap: { toggleMetric(.memory) }
                )
                
                GaugeView(
                    label: "GPU",
                    value: service.currentStats.gpuUsage,
                    isSelected: expandedMetrics.contains(.gpu),
                    onTap: { toggleMetric(.gpu) }
                )
            }
            .padding(.top, 8)
            
            // Expanded graphs
            if !expandedMetrics.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(ActivityMetric.allCases, id: \.self) { metric in
                            if expandedMetrics.contains(metric) {
                                graphView(for: metric)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                        }
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: expandedMetrics)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            service.startMonitoring()
        }
    }
    
    private func toggleMetric(_ metric: ActivityMetric) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if expandedMetrics.contains(metric) {
                expandedMetrics.remove(metric)
            } else {
                expandedMetrics.insert(metric)
            }
        }
    }
    
    @ViewBuilder
    private func graphView(for metric: ActivityMetric) -> some View {
        switch metric {
        case .cpu:
            MiniGraphView(
                data: service.history.map { $0.cpuUsage },
                color: colorForValue(service.currentStats.cpuUsage),
                label: metric.rawValue
            )
        case .memory:
            MiniGraphView(
                data: service.history.map { $0.memoryUsage },
                color: colorForValue(service.currentStats.memoryUsage),
                label: metric.rawValue
            )
        case .gpu:
            MiniGraphView(
                data: service.history.compactMap { $0.gpuUsage },
                color: colorForValue(service.currentStats.gpuUsage ?? 0),
                label: metric.rawValue
            )
        }
    }
    
    private func colorForValue(_ value: Double) -> Color {
        if value < 50 {
            return Color(red: 0.204, green: 0.780, blue: 0.349) // Green
        } else if value < 80 {
            return Color(red: 1.0, green: 0.839, blue: 0.039) // Yellow
        } else {
            return Color(red: 1.0, green: 0.231, blue: 0.188) // Red
        }
    }
}

#Preview {
    ActivityView()
        .frame(width: 400, height: 300)
        .background(Color.black)
}
