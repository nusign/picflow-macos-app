//
//  StreamingStatusView.swift
//  Picflow
//
//  Created by Michel Luarasi on 31.10.2025.
//

import SwiftUI

// MARK: - Public entry
struct StreamCounterView: View {
    let count: Int
    
    // Style knobs you can tune
    private let cornerRadius: CGFloat = 36        // large corner radius for rounded corners
    private let lineWidth: CGFloat = 3
    private let sideInset: CGFloat = 24           // padding from the outer edge
    private let topBottomInset: CGFloat = 24
    private let gapPadding: CGFloat = 48          // extra space to keep around the text
    
    private var formattedCount: String {
        String(format: "%04d", count)
    }
    
    var body: some View {
        ZStack {
            // Count in center
            Text(formattedCount)
                .font(.system(size: 96, weight: .regular, design: .monospaced))
                .monospacedDigit()
            
            // 4 corners with gaps
            VStack(spacing: 0) {
                // Top corners
                HStack(spacing: 0) {
                    CornerView(edges: [.top, .leading], cornerRadius: cornerRadius, lineWidth: lineWidth)
                    Spacer()
                        .frame(width: measuredTextWidth + gapPadding)
                    CornerView(edges: [.top, .trailing], cornerRadius: cornerRadius, lineWidth: lineWidth)
                }
                .frame(height: topBottomInset + cornerRadius)
                
                Spacer()
                
                // Bottom corners
                HStack(spacing: 0) {
                    CornerView(edges: [.bottom, .leading], cornerRadius: cornerRadius, lineWidth: lineWidth)
                    Spacer()
                        .frame(width: measuredTextWidth + gapPadding)
                    CornerView(edges: [.bottom, .trailing], cornerRadius: cornerRadius, lineWidth: lineWidth)
                }
                .frame(height: topBottomInset + cornerRadius)
            }
        }
        .padding(8)
        .animation(.easeInOut(duration: 0.25), value: count)
    }
    
    private var measuredTextWidth: CGFloat {
        let fontSize: CGFloat = 96
        let charWidth = fontSize * 0.6
        return CGFloat(formattedCount.count) * charWidth
    }
}

// MARK: - Corner View
/// A single corner with borders on 2 edges and rounded corners
private struct CornerView: View {
    let edges: [Edge]
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let width = geo.size.width
                let height = geo.size.height
                
                if edges.contains(.top) && edges.contains(.leading) {
                    // Top-left: horizontal line from gap to corner, then arc down, then vertical line down
                    path.move(to: CGPoint(x: width, y: 0))
                    path.addLine(to: CGPoint(x: cornerRadius, y: 0))
                    path.addArc(
                        center: CGPoint(x: cornerRadius, y: cornerRadius),
                        radius: cornerRadius,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(180),
                        clockwise: true
                    )
                    path.addLine(to: CGPoint(x: 0, y: height))
                } else if edges.contains(.top) && edges.contains(.trailing) {
                    // Top-right: horizontal line from left to corner, vertical line from corner down
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))
                    path.addArc(
                        center: CGPoint(x: width - cornerRadius, y: cornerRadius),
                        radius: cornerRadius,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(0),
                        clockwise: false
                    )
                    path.addLine(to: CGPoint(x: width, y: height))
                } else if edges.contains(.bottom) && edges.contains(.leading) {
                    // Bottom-left: vertical line from top to corner, horizontal line from corner right
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: height - cornerRadius))
                    path.addArc(
                        center: CGPoint(x: cornerRadius, y: height - cornerRadius),
                        radius: cornerRadius,
                        startAngle: .degrees(180),
                        endAngle: .degrees(90),
                        clockwise: true
                    )
                    path.addLine(to: CGPoint(x: width, y: height))
                } else if edges.contains(.bottom) && edges.contains(.trailing) {
                    // Bottom-right: vertical line from top to corner, horizontal line from corner left
                    path.move(to: CGPoint(x: width, y: 0))
                    path.addLine(to: CGPoint(x: width, y: height - cornerRadius))
                    path.addArc(
                        center: CGPoint(x: width - cornerRadius, y: height - cornerRadius),
                        radius: cornerRadius,
                        startAngle: .degrees(0),
                        endAngle: .degrees(90),
                        clockwise: false
                    )
                    path.addLine(to: CGPoint(x: 0, y: height))
                }
            }
            .stroke(Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edges.contains(.leading) ? .leading : .trailing)
    }
}


#Preview {
    StreamCounterView(count: 104)
        .frame(width: 600, height: 300)
        .padding()
        .background(Color.white)
}

