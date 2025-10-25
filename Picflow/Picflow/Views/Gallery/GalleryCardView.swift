import SwiftUI

struct GalleryCardView: View {
    let gallery: GalleryDetails
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Preview Image or Fallback (4:3 ratio)
            if let imageUrl = gallery.previewImageUrl {
                AsyncImage(url: imageUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } placeholder: {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(width: 80, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 80, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(gallery.displayName)
                    .fontWeight(.medium)
                
                // Show asset count
                let count = gallery.assetCount
                Text(count > 0 ? "\(count) \(count == 1 ? "asset" : "assets")" : "No assets")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Chevron right icon (no background)
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(isHovered ? 0.15 : 0.1))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
