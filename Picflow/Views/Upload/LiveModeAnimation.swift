//
//  LiveModeAnimation.swift
//  Picflow
//
//  Created by AI Assistant
//
//  Visual indicator showing live folder monitoring is active

import SwiftUI

/// Expanding/radiating gradient border that indicates live mode is active
struct LiveModeAnimation: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Outer expanding glow (250px when expanded)
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    RadialGradient(
                        colors: [
                            Color.red.opacity(0.3),
                            Color.red.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: isAnimating ? 250 : 50  // GROWS from 50px to 250px
                    ),
                    lineWidth: isAnimating ? 250 : 50  // Border width grows too
                )
                .blur(radius: isAnimating ? 30 : 10)  // Blur increases as it expands
                .opacity(isAnimating ? 0.3 : 0.6)     // Fades out as it grows
            
            // Inner consistent border (always visible)
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0.5),
                            Color.red.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 12
                )
                .blur(radius: 12)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.5)              // 2.5 seconds per pulse
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

/// View modifier to add live mode animation effect
struct LiveModeAnimationModifier: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isActive {
                        LiveModeAnimation()
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
            )
            .animation(.easeInOut(duration: 2.0), value: isActive)
    }
}

extension View {
    /// Adds a pulsing animated border when live mode is active
    func liveModeAnimation(isActive: Bool) -> some View {
        modifier(LiveModeAnimationModifier(isActive: isActive))
    }
}

// MARK: - Preview

#Preview("Live Mode Animation") {
    VStack(spacing: 24) {
        Image("Folder-Sync-Connect")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 80, height: 80)
        
        VStack(spacing: 8) {
            Text("Picflow Live")
                .font(.title)
                .fontWeight(.bold)
            
            Text("The fullscreen pulsing border indicates")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("live folder monitoring is active")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
    }
    .frame(width: 400, height: 300)
    .padding(40)
    .liveModeAnimation(isActive: true)
    .frame(width: 500, height: 400)
}


