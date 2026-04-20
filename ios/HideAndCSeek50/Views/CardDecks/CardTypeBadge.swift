//
//  CardTypeBadge.swift
//  HideAndCSeek50
//

import SwiftUI

struct CardTypeBadge: View {
    let type: CardType

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.iconName)
                .font(.caption2)
            Text(type.displayName)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(type.themeColor.opacity(0.15))
        .foregroundColor(type.themeColor)
        .cornerRadius(6)
    }
}

#Preview {
    VStack(spacing: 8) {
        CardTypeBadge(type: .curse)
        CardTypeBadge(type: .powerup)
        CardTypeBadge(type: .timeBonus)
    }
    .padding()
}
