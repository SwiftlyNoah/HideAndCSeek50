//
//  HandView.swift
//  HideAndCSeek50
//

import SwiftUI
import FirebaseAuth
internal import Combine

struct HandView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var gameManager: GameManager

    @Binding var pendingQuestionWithReward: QuestionData?

    let gameId: String
    let chatViewModel: ChatViewModel
    let currentUser: User?
    let currentPlayerTeam: Team

    @State private var selectedCards: Set<String> = []
    @State private var isProcessing = false
    @State private var gameObserver: AnyCancellable?
    @State private var sharedCardId: String?
    @State private var isDrawingCard = false

    private var pendingDrawAction: DrawAction? {
        guard let question = pendingQuestionWithReward else { return nil }
        return QuestionData.parseDrawAction(from: question.reward)
    }

    var deckState: DeckState? {
        gameManager.currentGame?.deck
    }
    var isInDrawMode: Bool {
        pendingQuestionWithReward != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.indigo.opacity(0.08),
                        Color.purple.opacity(0.04),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    if let pendingAction = pendingDrawAction {
                        drawModeHeader(action: pendingAction)
                    } else {
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
            .onAppear {
                setupGameObserver()
            }
            .onDisappear {
                gameObserver?.cancel()
            }
        }
    }

    // MARK: - Observer Setup

    private func setupGameObserver() {
        guard pendingQuestionWithReward != nil else { return }

        gameObserver = gameManager.$currentGame
            .sink { game in
                guard let game = game,
                      let questionId = pendingQuestionWithReward?.questionId else { return }

                for message in game.messages.values {
                    if let questionData = message.questionData,
                       questionData.questionId == questionId,
                       questionData.isRewarded {
                        pendingQuestionWithReward = nil
                        gameObserver?.cancel()
                        break
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
                            colors: [.indigo, .purple],
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

                // Draw card button
                Button {
                    drawCardManually()
                } label: {
                    HStack {
                        if isDrawingCard {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "plus.rectangle.on.rectangle")
                            Text("Draw Card")
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        (state.deck.isEmpty && state.discardPile.isEmpty)
                            ? Color.gray
                            : Color.indigo
                    )
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isDrawingCard || (state.deck.isEmpty && state.discardPile.isEmpty))
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
        VStack(spacing: 12) {
            if !state.hand.isEmpty {
                Text("Use the ··· menu on a card to share or delete it")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
            ], spacing: 16) {
                ForEach(state.hand) { card in
                    CardView(
                        card: card,
                        isSelected: sharedCardId == card.id,
                        isInteractive: true
                    )
                    .overlay(alignment: .topTrailing) {
                        cardMenuButton(for: card)
                    }
                }
            }

            if state.hand.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.on.rectangle.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No cards in hand")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Draw a card using the button above")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 40)
            }
        }
        .padding()
    }

    private func drawModeContent(state: DeckState) -> some View {
        VStack(spacing: 24) {
            let drawCount = pendingDrawAction?.drawCount ?? 0
            let drawnCards = Array(state.deck.prefix(drawCount))

            if drawnCards.isEmpty || drawnCards.count < drawCount {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Drawing cards...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Drawn Cards")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
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

                if !state.hand.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Existing Hand")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
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

        let drawCount = action.drawCount
        let drawnCards = Array(state.deck.prefix(drawCount))
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
              let questionWithReward = pendingQuestionWithReward,
              canConfirmSelection else { return }

        isProcessing = true

        Task {
            do {
                let drawnCards = Array(state.deck.prefix(action.drawCount))
                let cardsToKeep = drawnCards.filter { selectedCards.contains($0.id) }
                let cardsToDiscard = drawnCards.filter { !selectedCards.contains($0.id) }

                let newDeckState = DeckState(
                    deck: Array(state.deck.suffix(state.deck.count - action.drawCount)),
                    hand: state.hand + cardsToKeep,
                    discardPile: state.discardPile + cardsToDiscard
                )

                try await gameManager.updateDeckState(gameId: gameId, deckState: newDeckState)

                if let messageId = gameManager.currentGame?.messages.first(where: {
                    $0.value.questionData?.questionId == questionWithReward.questionId
                })?.key {
                    try await gameManager.markQuestionRewarded(gameId: gameId, questionMessageId: messageId)
                }

                await MainActor.run {
                    pendingQuestionWithReward = nil
                    selectedCards.removeAll()
                    isProcessing = false
                    gameObserver?.cancel()
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

    // MARK: - Card Menu

    private func cardMenuButton(for card: Card) -> some View {
        Menu {
            Button {
                shareCardInChat(card)
            } label: {
                Label("Send to Other Team", systemImage: "paperplane")
            }

            Divider()

            Button(role: .destructive) {
                discardCard(card)
            } label: {
                Label("Discard", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial, in: Circle())
        }
        .padding(6)
    }

    // MARK: - Share Card in Chat

    private func shareCardInChat(_ card: Card) {
        sharedCardId = card.id

        guard let displayName = currentUser?.displayName ?? currentUser?.email else { return }

        Task {
            await chatViewModel.sendCardMessage(
                gameId: gameId,
                card: card.definition,
                currentUser: currentUser,
                currentUserName: displayName,
                currentPlayerTeam: currentPlayerTeam
            )
            try? await Task.sleep(for: .seconds(0.6))
            sharedCardId = nil
        }
    }

    // MARK: - Manual Draw

    private func drawCardManually() {
        guard var state = deckState else { return }
        isDrawingCard = true

        let drawn = state.drawCards(1)
        state.addToHand(drawn)

        Task {
            do {
                try await gameManager.updateDeckState(gameId: gameId, deckState: state)
            } catch {
                print("Error drawing card: \(error)")
            }
            isDrawingCard = false
        }
    }

    // MARK: - Discard Card

    private func discardCard(_ card: Card) {
        guard var state = deckState else { return }

        state.removeFromHand([card])
        state.discardCards([card])

        Task {
            do {
                try await gameManager.updateDeckState(gameId: gameId, deckState: state)
            } catch {
                print("Error discarding card: \(error)")
            }
        }
    }
}

// MARK: - Card View

struct CardView: View {
    let card: Card
    let isSelected: Bool
    let isInteractive: Bool

    private var def: CustomCard { card.definition }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.10), radius: 5, x: 0, y: 3)

            if isSelected {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.green, lineWidth: 3)
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                            .background(Circle().fill(Color(.systemBackground)).frame(width: 24, height: 24))
                    }
                    Spacer()
                }
                .padding(8)
            }

            VStack(alignment: .leading, spacing: 6) {
                CardTypeBadge(type: def.type)

                Text(def.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .lineLimit(2)
                    .foregroundColor(.primary)

                Text(def.displaySubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)

                if def.type == .curse, let cost = def.castingCost {
                    Spacer(minLength: 4)
                    Divider()
                    Label(cost, systemImage: "creditcard.fill")
                        .font(.caption2)
                        .foregroundColor(CardType.curse.themeColor)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
        }
        .aspectRatio(0.7, contentMode: .fit)
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
        .opacity(isInteractive ? 1.0 : 0.9)
    }
}

#Preview {
    HandView(
        pendingQuestionWithReward: .constant(nil),
        gameId: "",
        chatViewModel: ChatViewModel(),
        currentUser: nil,
        currentPlayerTeam: .hiders
    )
}
