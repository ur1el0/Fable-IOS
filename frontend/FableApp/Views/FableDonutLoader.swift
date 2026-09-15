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
                                FableTheme.brandPrimary.opacity(0.15),
                                FableTheme.brandPrimary
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                
                // Center filigree serif motif dot
                Circle()
                    .fill(FableTheme.brandPrimary)
                    .frame(width: size * 0.18, height: size * 0.18)
                    .scaleEffect(pulseScale)
            }
            
            if let text = message {
                Text(text)
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundColor(FableTheme.textSecondary)
                    .tracking(0.6)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) {
                self.isSpinning = true
            }
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                self.pulseScale = 1.3
            }
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

/// Inline Donut Refresh Bar for ScrollViews
public struct InlineDonutRefreshView: View {
    let message: String
    
    public init(message: String = "Syncing archive...") {
        self.message = message
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            FableDonutLoader(size: 18, lineWidth: 2.4)
            Text(message)
                .font(.system(size: 12, weight: .medium, design: .serif))
                .foregroundColor(FableTheme.brandPrimary)
                .tracking(0.5)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
