import SwiftUI

struct GalleryCardView: View {
    let gallery: GalleryDetails
    let onSelect: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Preview Image or Fallback
            if let imageUrl = gallery.previewImageUrl {
                AsyncImage(url: imageUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 64, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } placeholder: {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(width: 64, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 64, height: 48)
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
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .controlBackgroundColor))
                .opacity(isHovered ? 1.0 : 0.5)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }
}
