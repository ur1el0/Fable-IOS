import SwiftUI

/// Literary Donut Activity & Page Loading Indicator
public struct FableDonutLoader: View {
    let size: CGFloat
    let lineWidth: CGFloat
    let message: String?
    
    @State private var isSpinning: Bool = false
    @State private var pulseScale: CGFloat = 1.0
    
    public init(size: CGFloat = 44, lineWidth: CGFloat = 3.8, message: String? = nil) {
        self.size = size
        self.lineWidth = lineWidth
        self.message = message
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Outer subtle donut track
                Circle()
                    .stroke(FableTheme.brandPrimary.opacity(0.14), lineWidth: lineWidth)
                    .frame(width: size, height: size)
                
                // Active rotating gradient donut arc
                Circle()
                    .trim(from: 0.08, to: 0.78)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                FableTheme.brandPrimary.opacity(0.2),
                                FableTheme.brandPrimary
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .animation(
                        .linear(duration: 0.85)
                        .repeatForever(autoreverses: false),
                        value: isSpinning
                    )
                
                // Center filigree serif motif dot
                Circle()
                    .fill(FableTheme.brandPrimary)
                    .frame(width: size * 0.18, height: size * 0.18)
                    .scaleEffect(pulseScale)
                    .animation(
                        .easeInOut(duration: 0.85)
                        .repeatForever(autoreverses: true),
                        value: pulseScale
                    )
            }
            
            if let text = message {
                Text(text)
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundColor(FableTheme.textSecondary)
                    .tracking(0.6)
            }
        }
        .onAppear {
            self.isSpinning = true
            self.pulseScale = 1.3
        }
    }
}

/// Floating Page Transition Donut Modal
public struct PageTransitionDonutOverlay: View {
    let message: String
    
    public init(message: String = "Turning page...") {
        self.message = message
    }
    
    public var body: some View {
        ZStack {
            Color.black.opacity(0.08)
                .ignoresSafeArea()
            
            VStack(spacing: 14) {
                FableDonutLoader(size: 46, lineWidth: 4, message: message)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 16, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(FableTheme.lightBorder, lineWidth: 1)
            )
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
