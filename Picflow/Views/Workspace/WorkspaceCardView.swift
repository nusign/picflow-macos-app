//
//  WorkspaceCardView.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI

struct WorkspaceCardView: View {
    let tenant: Tenant
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Favicon or placeholder with initial (with border when selected)
                Group {
                    if let faviconUrl = tenant.faviconUrl, let url = URL(string: faviconUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            placeholderIcon
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        placeholderIcon
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                
                // Tenant info
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Text(tenant.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        // Show "Guest" badge for shared tenants
                        if tenant.isShared {
                            Text("Guest")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.orange)
                                )
                        }
                    }
                    
                    Text("\(tenant.path).picflow.com")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Always show chevron
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
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var placeholderIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.2))
            
            // Show initial letter of workspace name
            Text(String(tenant.name.prefix(1)).uppercased())
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.accentColor)
        }
        .frame(width: 48, height: 48)
    }
}

