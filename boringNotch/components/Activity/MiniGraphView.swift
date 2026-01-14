import SwiftUI

struct MiniGraphView: View {
    let data: [Double]  // Array of values 0-100
    let color: Color
    let label: String
    
    private let height: CGFloat = 60
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Label
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                if let last = data.last {
                    Text("\(Int(last))%")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                }
            }
            
            // Graph
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Grid lines
                    VStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { _ in
                            Divider()
                                .background(Color.gray.opacity(0.2))
                            Spacer()
                        }
                    }
                    
                    // Filled area
                    if data.count > 1 {
                        filledPath(in: geometry.size)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [color.opacity(0.4), color.opacity(0.0)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    
                    // Line
                    if data.count > 1 {
                        linePath(in: geometry.size)
                            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    } else if data.count == 1 {
                        // Single point - show as dot
                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                            .position(x: geometry.size.width / 2, y: geometry.size.height * (1 - data[0] / 100))
                    }
                }
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private func linePath(in size: CGSize) -> Path {
        var path = Path()
        
        guard data.count > 1 else { return path }
        
        let stepX = size.width / CGFloat(data.count - 1)
        
        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * stepX
            let y = size.height * (1 - value / 100)
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                // Smooth curve using quadratic bezier
                let prevX = CGFloat(index - 1) * stepX
                let prevY = size.height * (1 - data[index - 1] / 100)
                let midX = (prevX + x) / 2
                
                path.addQuadCurve(
                    to: CGPoint(x: x, y: y),
                    control: CGPoint(x: midX, y: prevY)
                )
            }
        }
        
        return path
    }
    
    private func filledPath(in size: CGSize) -> Path {
        var path = linePath(in: size)
        
        guard data.count > 1 else { return path }
        
        let stepX = size.width / CGFloat(data.count - 1)
        
        // Close the path to create a filled area
        path.addLine(to: CGPoint(x: CGFloat(data.count - 1) * stepX, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    VStack(spacing: 16) {
        MiniGraphView(
            data: [20, 35, 45, 30, 55, 70, 65, 80, 75, 60, 45],
            color: Color(red: 0.204, green: 0.780, blue: 0.349),
            label: "CPU"
        )
        
        MiniGraphView(
            data: [60, 62, 65, 63, 67, 70, 68, 72, 75, 73],
            color: Color(red: 1.0, green: 0.839, blue: 0.039),
            label: "Memory"
        )
        
        MiniGraphView(
            data: [80, 85, 90, 88, 92, 95, 93, 90, 88, 85],
            color: Color(red: 1.0, green: 0.231, blue: 0.188),
            label: "GPU"
        )
    }
    .padding()
    .background(Color.black)
}
