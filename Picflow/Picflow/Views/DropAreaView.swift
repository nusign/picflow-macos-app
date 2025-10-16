import SwiftUI
import UniformTypeIdentifiers

struct DropAreaView: View {
    let isEnabled: Bool
    let onDrop: ([URL]) -> Void
    @State private var isTargeted = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                .foregroundColor(isEnabled ? (isTargeted ? .blue : .gray) : .gray.opacity(0.5))
            
            VStack {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 30))
                Text(isEnabled ? "Drop images here" : "Select a gallery first")
                    .font(.headline)
            }
            .foregroundColor(isEnabled ? (isTargeted ? .blue : .gray) : .gray.opacity(0.5))
        }
        .frame(height: 120)
        .padding()
        .onDrop(of: [UTType.image], isTargeted: $isTargeted) { providers in
            guard isEnabled else { return false }
            
            providers.forEach { provider in
                _ = provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                    guard error == nil, let url = url else { return }
                    
                    // Create a local copy of the file since the original URL might be temporary
                    let fileName = url.lastPathComponent
                    let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                    
                    try? FileManager.default.copyItem(at: url, to: localURL)
                    
                    DispatchQueue.main.async {
                        onDrop([localURL])
                    }
                }
            }
            
            return true
        }
    }
} 