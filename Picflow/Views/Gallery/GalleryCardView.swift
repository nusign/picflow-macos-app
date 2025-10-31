import SwiftUI

struct GalleryCardView: View {
    let gallery: GalleryDetails
    let onSelect: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Preview Image or Fallback
            if let imageUrl = gallery.previewImageUrl {
                AsyncImage(url: imageUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 96, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } placeholder: {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(width: 96, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 96, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            VStack(alignment: .leading, spacing: 0) {
                // Gallery name
                Text(gallery.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                // Show asset count
                let count = gallery.assetCount
                Text(count > 0 ? "\(count) \(count == 1 ? "asset" : "assets")" : "No assets")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Chevron right icon (no background)
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.system(size: 16, weight: .semibold))
        }
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.primary)
                .opacity(isPressed ? 0.1 : (isHovered ? 0.05 : 0))
        )
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
}
