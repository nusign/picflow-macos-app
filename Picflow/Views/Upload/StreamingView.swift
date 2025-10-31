//
//  StreamingView.swift
//  Picflow
//
//  Created by Michel Luarasi on 31.10.2025.
//

import SwiftUI

// MARK: - Public entry
struct StreamCounterView: View {
    @State var count: Int = 104
    
    // Style knobs you can tune
    private let cornerRadius: CGFloat = 36        // stays constant as the view scales
    private let lineWidth: CGFloat = 3
    private let sideInset: CGFloat = 24           // padding from the outer edge
    private let topBottomInset: CGFloat = 24
    private let gapPadding: CGFloat = 48          // extra space to keep around the text
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background "S" lines
                SDecor(
                    gap: measuredTextWidth(geo.size) + gapPadding,
                    radius: cornerRadius,
                    lineWidth: lineWidth,
                    sideInset: sideInset,
                    topBottomInset: topBottomInset
                )
                .animation(.easeInOut(duration: 0.25), value: count)

                // Center content
                VStack(spacing: 16) {
                    Text("\(count)")
                        .font(.system(size: bestFontSize(for: geo.size),
                                      weight: .black,
                                      design: .rounded))
                        .monospacedDigit()
                        .kerning(1)
                        .foregroundStyle(.primary)

                    Text("Files Streamed")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.clear)
        }
        .padding(8)
    }
    
    // Make the big number responsive but sane.
    private func bestFontSize(for size: CGSize) -> CGFloat {
        min(size.width, size.height) * 0.35
    }
    
    // Approximate text width based on the current size and font scaling.
    // We don’t need millimetre accuracy—just enough to keep the lines off the text.
    private func measuredTextWidth(_ container: CGSize) -> CGFloat {
        let w = bestFontSize(for: container) * 0.62 * CGFloat(String(count).count) // ~0.62 is a good average for rounded/mono
        return max(180, min(w, container.width * 0.7))
    }
}

// MARK: - The decorative S-shaped lines
private struct SDecor: View {
    let gap: CGFloat
    let radius: CGFloat
    let lineWidth: CGFloat
    let sideInset: CGFloat
    let topBottomInset: CGFloat
    
    var body: some View {
        GeometryReader { g in
            let size = g.size
            let safeR = min(radius, (size.height - 2*topBottomInset) / 2 - 1) // never let radius exceed available height
            let centerX = size.width / 2
            let leftEndX = max(sideInset + safeR, centerX - gap/2)
            let rightStartX = min(size.width - sideInset - safeR, centerX + gap/2)
            
            // Left path (solid gray)
            SSidePath(isRightSide: false,
                      leftEndX: leftEndX,
                      rightStartX: rightStartX,
                      sideInset: sideInset,
                      topBottomInset: topBottomInset,
                      radius: safeR)
                .stroke(Color.secondary.opacity(0.35),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            
            // Right path base (gray)
            SSidePath(isRightSide: true,
                      leftEndX: leftEndX,
                      rightStartX: rightStartX,
                      sideInset: sideInset,
                      topBottomInset: topBottomInset,
                      radius: safeR)
                .stroke(Color.secondary.opacity(0.35),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .overlay {
                    // Red accent only on the bottom segment of the right side
                    SSidePath(isRightSide: true,
                              leftEndX: leftEndX,
                              rightStartX: rightStartX,
                              sideInset: sideInset,
                              topBottomInset: topBottomInset,
                              radius: safeR)
                        .trim(from: 0.80, to: 1.0) // adjust which portion is red
                        .stroke(
                            LinearGradient(colors: [.red.opacity(0.7), .red],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )
                }
        }
    }
}

// MARK: - Single “S” side shape
/// Draws a single S-shaped stroke on either the left or the right.
/// The corner radius is **absolute** (does not stretch with the view).
private struct SSidePath: Shape {
    let isRightSide: Bool
    let leftEndX: CGFloat     // where the left stroke should stop (near gap)
    let rightStartX: CGFloat  // where the right stroke should start (near gap)
    let sideInset: CGFloat
    let topBottomInset: CGFloat
    let radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var p = Path()
        
        let topY = topBottomInset
        let bottomY = rect.height - topBottomInset
        
        if !isRightSide {
            // LEFT:   ┌───────────╮
            //         │           │
            //         ╰───────────┘
            p.move(to: CGPoint(x: leftEndX, y: topY))
            // top horizontal to the rounded corner
            p.addLine(to: CGPoint(x: sideInset + radius, y: topY))
            // top-left arc (clockwise 90°)
            p.addArc(center: CGPoint(x: sideInset + radius, y: topY + radius),
                     radius: radius,
                     startAngle: .degrees(-90),
                     endAngle: .degrees(-180),
                     clockwise: true)
            // left vertical
            p.addLine(to: CGPoint(x: sideInset, y: bottomY - radius))
            // bottom-left arc (clockwise 90°)
            p.addArc(center: CGPoint(x: sideInset + radius, y: bottomY - radius),
                     radius: radius,
                     startAngle: .degrees(180),
                     endAngle: .degrees(90),
                     clockwise: true)
            // bottom horizontal toward the gap
            p.addLine(to: CGPoint(x: leftEndX, y: bottomY))
        } else {
            // RIGHT:  ╮───────────┐
            //         │           │
            //         └───────────╯
            p.move(to: CGPoint(x: rightStartX, y: topY))
            p.addLine(to: CGPoint(x: rect.width - sideInset - radius, y: topY))
            p.addArc(center: CGPoint(x: rect.width - sideInset - radius, y: topY + radius),
                     radius: radius,
                     startAngle: .degrees(-90),
                     endAngle: .degrees(0),
                     clockwise: false)
            p.addLine(to: CGPoint(x: rect.width - sideInset, y: bottomY - radius))
            p.addArc(center: CGPoint(x: rect.width - sideInset - radius, y: bottomY - radius),
                     radius: radius,
                     startAngle: .degrees(0),
                     endAngle: .degrees(90),
                     clockwise: false)
            p.addLine(to: CGPoint(x: rightStartX, y: bottomY))
        }
        return p
    }
}

#Preview {
    StreamCounterView(count: 104)
        .frame(width: 600, height: 300)
        .padding()
        .background(Color.white)
}
