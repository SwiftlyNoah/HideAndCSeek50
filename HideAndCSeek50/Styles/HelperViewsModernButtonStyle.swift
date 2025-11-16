//
//  ModernButtonStyle.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/15/25.
//

import SwiftUI

struct ModernButtonStyle: ButtonStyle {
    let color: Color
    let isSecondary: Bool
    
    init(color: Color, isSecondary: Bool = false) {
        self.color = color
        self.isSecondary = isSecondary
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSecondary ?
                        color.opacity(0.1) :
                        color
                    )
            )
            .foregroundColor(isSecondary ? color : .white)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 16) {
        Button("Primary Button") {
            // Preview action
        }
        .buttonStyle(ModernButtonStyle(color: .blue))
        
        Button("Secondary Button") {
            // Preview action
        }
        .buttonStyle(ModernButtonStyle(color: .blue, isSecondary: true))
    }
    .padding()
}