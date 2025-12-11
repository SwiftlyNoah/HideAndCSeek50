//
//  HandView.swift
//  HideAndCSeek50
//
//  Created by Assistant on 12/9/25.
//

import SwiftUI

struct HandView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var gameManager: GameManager
        
    @Binding var pendingDrawAction: DrawAction?
    
    let gameId: String
    
    @State private var selectedCards: Set<String> = []
    @State private var isProcessing = false
    
    var deckState: DeckState? {
        gameManager.currentGame?.deck
    }
    var isInDrawMode: Bool {
        pendingDrawAction != nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color.green.opacity(0.1),
                        Color.blue.opacity(0.05),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    if let pendingAction = pendingDrawAction {
                        // Draw mode header
                        drawModeHeader(action: pendingAction)
                    } else {
                        // Normal hand header
                        handHeader
                    }
                    
                    ScrollView {
                        if let state = deckState {
                            if isInDrawMode {
                                drawModeContent(state: state)
                            } else {
                                normalHandContent(state: state)
                            }
                        } else {
                            ProgressView("Loading deck...")
                                .padding()
                        }
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    if isInDrawMode, let action = pendingDrawAction {
                        drawModeActions(action: action)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(isInDrawMode)
                }
            }
        }
    }
    
    // MARK: - Headers
    
    private var handHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Your Hand")
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            if let state = deckState {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(state.hand.count)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Cards in Hand")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack(spacing: 4) {
                        Text("\(state.deck.count)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Cards in Deck")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func drawModeHeader(action: DrawAction) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("Question Reward")
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            Text(action.description)
                .font(.headline)
                .foregroundColor(.orange)
            
            Text("Select \(action.keepCount) card\(action.keepCount == 1 ? "" : "s") to keep")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 2)
        )
    }
    
    // MARK: - Content
    
    private func normalHandContent(state: DeckState) -> some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 16)
        ], spacing: 16) {
            ForEach(state.hand) { card in
                CardView(card: card, isSelected: false, isInteractive: false)
            }
        }
        .padding()
    }
    
    private func drawModeContent(state: DeckState) -> some View {
        VStack(spacing: 24) {
            // Check if we have the drawn cards yet
            let drawCount = pendingDrawAction?.drawCount ?? 0
            let drawnCards = Array(state.deck.prefix(drawCount))
            
            if drawnCards.isEmpty || drawnCards.count < drawCount {
                // Still waiting for cards to be drawn
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Drawing cards...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                // Drawn cards (to select from)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Drawn Cards")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 16)
                    ], spacing: 16) {
                        ForEach(drawnCards) { card in
                            CardView(
                                card: card,
                                isSelected: selectedCards.contains(card.id),
                                isInteractive: true
                            )
                            .onTapGesture {
                                toggleCardSelection(card)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Existing hand
                if !state.hand.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Existing Hand")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 16)
                        ], spacing: 16) {
                            ForEach(state.hand) { card in
                                CardView(card: card, isSelected: false, isInteractive: false)
                                    .opacity(0.6)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func drawModeActions(action: DrawAction) -> some View {
        VStack(spacing: 12) {
            Button(action: { confirmSelection() }) {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Keep Selected Cards")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canConfirmSelection ? Color.green : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(!canConfirmSelection || isProcessing)
            
            Text("\(selectedCards.count) of \(action.keepCount) selected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    // MARK: - Helper Methods
    
    private var canConfirmSelection: Bool {
        guard let action = pendingDrawAction,
              let state = deckState else { return false }
        
        // Check if we have received the drawn cards
        let drawCount = action.drawCount
        let drawnCards = Array(state.deck.prefix(drawCount))
        
        // Only allow confirmation if:
        // 1. We have the right number of drawn cards
        // 2. The user has selected the right number of cards
        return drawnCards.count >= drawCount && selectedCards.count == action.keepCount
    }
    
    private func toggleCardSelection(_ card: Card) {
        guard let action = pendingDrawAction else { return }
        
        if selectedCards.contains(card.id) {
            selectedCards.remove(card.id)
        } else if selectedCards.count < action.keepCount {
            selectedCards.insert(card.id)
        }
    }
    
    private func confirmSelection() {
        guard let state = deckState,
              let action = pendingDrawAction,
              canConfirmSelection else { return }
        
        isProcessing = true
        
        Task {
            do {
                // Get the drawn cards (first n cards in deck)
                let drawnCards = Array(state.deck.prefix(action.drawCount))
                
                // Determine which cards to discard
                let cardsToDiscard = drawnCards.filter { !selectedCards.contains($0.id) }
                let cardsToKeep = drawnCards.filter { selectedCards.contains($0.id) }
                
                // Clear the pending action
                await MainActor.run {
                    pendingDrawAction = nil
                    selectedCards.removeAll()
                    isProcessing = false
                    dismiss()
                }
            } catch {
                print("Error confirming card selection: \(error)")
                await MainActor.run {
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - Card View

struct CardView: View {
    let card: Card
    let isSelected: Bool
    let isInteractive: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Card background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                // Selection overlay
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green, lineWidth: 3)
                    
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                                .background(
                                    Circle()
                                        .fill(Color(.systemBackground))
                                        .frame(width: 24, height: 24)
                                )
                        }
                        Spacer()
                    }
                    .padding(8)
                }
                
                // Card content
                VStack(spacing: 4) {
                    // Top rank and suit
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.rank.displayValue)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(card.color)
                            Image(systemName: card.suit.iconName)
                                .font(.system(size: 16))
                                .foregroundColor(card.color)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    // Center suit symbol
                    Image(systemName: card.suit.iconName)
                        .font(.system(size: 40))
                        .foregroundColor(card.color.opacity(0.8))
                    
                    Spacer()
                    
                    // Bottom rank and suit (rotated)
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Image(systemName: card.suit.iconName)
                                .font(.system(size: 16))
                                .foregroundColor(card.color)
                            Text(card.rank.displayValue)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(card.color)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                    .rotationEffect(.degrees(180))
                }
            }
            .aspectRatio(0.7, contentMode: .fit)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
        }
        .opacity(isInteractive ? 1.0 : 0.9)
    }
}

#Preview {
    HandView(pendingDrawAction: .constant(nil), gameId: "")
}
