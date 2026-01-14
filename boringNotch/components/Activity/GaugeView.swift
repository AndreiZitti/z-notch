import SwiftUI

struct GaugeView: View {
    let label: String
    let value: Double?  // nil means unavailable
    let isSelected: Bool
    let onTap: () -> Void
    
    private let size: CGFloat = 50
    private let lineWidth: CGFloat = 6
    
    private var displayValue: Double {
        value ?? 0
    }
    
    private var color: Color {
        guard value != nil else { return .gray }
        
        if displayValue < 50 {
            return Color(red: 0.204, green: 0.780, blue: 0.349) // #34C759
        } else if displayValue < 80 {
            return Color(red: 1.0, green: 0.839, blue: 0.039) // #FFD60A
        } else {
            return Color(red: 1.0, green: 0.231, blue: 0.188) // #FF3B30
        }
    }
    
    private var displayText: String {
        if value == nil {
            return "N/A"
        }
        return "\(Int(displayValue))%"
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
                    
                    // Foreground ring
                    Circle()
                        .trim(from: 0, to: CGFloat(displayValue / 100))
                        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: displayValue)
                    
                    // Glow effect for high usage
                    if displayValue >= 80 && value != nil {
                        Circle()
                            .trim(from: 0, to: CGFloat(displayValue / 100))
                            .stroke(color.opacity(0.5), lineWidth: lineWidth + 4)
                            .rotationEffect(.degrees(-90))
                            .blur(radius: 4)
                    }
                    
                    // Center text
                    Text(displayText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(value == nil ? .gray : .white)
                }
                .frame(width: size, height: size)
                
                // Label
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(GaugeButtonStyle())
    }
}

struct GaugeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    HStack(spacing: 16) {
        GaugeView(label: "CPU", value: 45, isSelected: false, onTap: {})
        GaugeView(label: "MEM", value: 67, isSelected: true, onTap: {})
        GaugeView(label: "GPU", value: 85, isSelected: false, onTap: {})
        GaugeView(label: "GPU", value: nil, isSelected: false, onTap: {})
    }
    .padding()
    .background(Color.black)
}
