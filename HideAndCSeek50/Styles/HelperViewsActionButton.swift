//
//  ActionButton.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import SwiftUI

struct ActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isPrimary: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: isPrimary ? 32 : 24))
                    .foregroundColor(isPrimary ? .white : color)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(isPrimary ? .headline : .subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isPrimary ? .white : .primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(isPrimary ? .white.opacity(0.8) : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: isPrimary ? 120 : 100)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isPrimary ?
                        LinearGradient(colors: [color, color.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [color.opacity(0.1), color.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: isPrimary ? color.opacity(0.3) : Color.black.opacity(0.1), radius: isPrimary ? 8 : 4, x: 0, y: isPrimary ? 4 : 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 16) {
        ActionButton(
            title: "Create Game",
            subtitle: "Start a new adventure",
            icon: "plus.circle.fill",
            color: .blue,
            isPrimary: true
        ) {
            // Preview action
        }
        
        ActionButton(
            title: "Quick Match",
            subtitle: "Find active games",
            icon: "bolt.circle.fill",
            color: .orange,
            isPrimary: false
        ) {
            // Preview action
        }
    }
    .padding()
}