//
//  GalleryCardView.swift
//  Picflow
//
//  Square gallery card with image background, title and asset count overlay
//

import SwiftUI

struct GalleryCardView: View {
    let gallery: GalleryDetails
    let onSelect: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Background Image
                Group {
                    if let imageUrl = gallery.previewImageUrl {
                        AsyncImage(url: imageUrl) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                            case .failure, .empty:
                                fallbackBackground
                            @unknown default:
                                fallbackBackground
                            }
                        }
                    } else {
                        fallbackBackground
                    }
                }
                
                // Gradient overlay for text readability
                LinearGradient(
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Text overlay (title and count)
                VStack(alignment: .leading, spacing: 4) {
                    Text(gallery.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    let count = gallery.assetCount
                    Text(count > 0 ? "\(count) \(count == 1 ? "asset" : "assets")" : "No assets")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        Color.white.opacity(isHovered ? 0.3 : 0),
                        lineWidth: 2
                    )
            )
            .shadow(
                color: Color.black.opacity(isPressed ? 0.3 : (isHovered ? 0.2 : 0.1)),
                radius: isPressed ? 8 : (isHovered ? 6 : 4),
                y: isPressed ? 4 : (isHovered ? 3 : 2)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .aspectRatio(4/3, contentMode: .fit) // 4:3 aspect ratio
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                    onSelect()
                }
        )
    }
    
    private var fallbackBackground: some View {
        ZStack {
            // Gradient background when no image
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.3),
                    Color.accentColor.opacity(0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Fallback icon
            Image(systemName: "photo.stack")
                .font(.system(size: 40))
                .foregroundColor(.primary.opacity(0.3))
        }
    }
}
