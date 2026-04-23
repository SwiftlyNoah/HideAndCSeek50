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

    // Normal draw mode: which drawn cards to keep
    @State private var selectedCards: Set<String> = []
    // Over-limit mode: which cards (drawn + hand) to keep. Pre-populated on entry.
    @State private var keptCardIds: Set<String> = []
    @State private var isProcessing = false
    @State private var gameObserver: AnyCancellable?
    @State private var sharedCardId: String?
    @State private var isDrawingCard = false
    @State private var cardDetailToShow: CustomCard?

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

    private var maxHandSize: Int {
        gameManager.currentGame?.info.settings.maxHandSize ?? 5
    }

    /// Whether keeping all `keepCount` reward cards would exceed the hand limit.
    private var isOverLimit: Bool {
        guard let action = pendingDrawAction, let state = deckState else { return false }
        return state.hand.count + action.keepCount > maxHandSize
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
            .sheet(item: $cardDetailToShow) { def in
                CardDetailSheet(definition: def)
                    .presentationDetents([.medium, .large])
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
                let isAtHandLimit = state.hand.count >= maxHandSize
                let isDeckEmpty = state.deck.isEmpty && state.discardPile.isEmpty
                Button {
                    drawCardManually()
                } label: {
                    HStack {
                        if isDrawingCard {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: isAtHandLimit ? "hand.raised.slash" : "plus.rectangle.on.rectangle")
                            Text(isAtHandLimit ? "Hand Full (\(state.hand.count)/\(maxHandSize))" : "Draw Card")
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isAtHandLimit || isDeckEmpty ? Color.gray : Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isDrawingCard || isDeckEmpty || isAtHandLimit)
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
                Text("Question Reward")
                    .font(.title)
                    .fontWeight(.bold)
            }

            Text(action.description)
                .font(.headline)
                .foregroundColor(.orange)

            if isOverLimit {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Hand limit reached (\(maxHandSize) max)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                    Text("Select the \(maxHandSize) cards from the draw and your existing hand that you want to keep.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(10)
                .background(Color.red.opacity(0.08))
                .cornerRadius(10)
            } else {
                Text("Select \(action.keepCount) card\(action.keepCount == 1 ? "" : "s") to keep")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
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
                Text("Tap a card for details. Use the ··· menu to share or discard.")
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
                    .onTapGesture {
                        cardDetailToShow = card.definition
                    }
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
                Color.clear
                    .frame(height: 0)
                    .onAppear {
                        // Pre-populate keptCardIds with all existing hand cards when entering over-limit mode
                        if isOverLimit && keptCardIds.isEmpty {
                            keptCardIds = Set(state.hand.map(\.id))
                        }
                    }

                // MARK: Drawn cards section
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
                                isSelected: isOverLimit ? keptCardIds.contains(card.id) : selectedCards.contains(card.id),
                                isInteractive: true
                            )
                            .onTapGesture {
                                if isOverLimit {
                                    toggleOverLimitCard(card, isDrawnCard: true)
                                } else {
                                    toggleCardSelection(card)
                                }
                            }
                        }
                    }
                }

                Divider()

                // MARK: Existing hand section
                if !state.hand.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Existing Hand")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
                        ], spacing: 16) {
                            ForEach(state.hand) { card in
                                if isOverLimit {
                                    // Tappable — toggling kept/discarded
                                    CardView(
                                        card: card,
                                        isSelected: keptCardIds.contains(card.id),
                                        isInteractive: true
                                    )
                                    .onTapGesture {
                                        toggleOverLimitCard(card, isDrawnCard: false)
                                    }
                                } else {
                                    // Normal: existing hand is read-only
                                    CardView(card: card, isSelected: false, isInteractive: false)
                                        .opacity(0.6)
                                }
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
        VStack(spacing: 8) {
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

            if isOverLimit {
                Text("\(keptCardIds.count) of \(maxHandSize) selected")
                    .font(.caption)
                    .foregroundColor(keptCardIds.count == maxHandSize ? .green : .secondary)
            } else {
                Text("\(selectedCards.count) of \(action.keepCount) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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
        guard drawnCards.count >= drawCount else { return false }

        if isOverLimit {
            // Must have selected exactly maxHandSize cards to keep
            return keptCardIds.count == maxHandSize
        } else {
            return selectedCards.count == action.keepCount
        }
    }

    // Normal mode: toggle a drawn card in/out of the keep set
    private func toggleCardSelection(_ card: Card) {
        guard let action = pendingDrawAction else { return }
        if selectedCards.contains(card.id) {
            selectedCards.remove(card.id)
        } else if selectedCards.count < action.keepCount {
            selectedCards.insert(card.id)
        }
    }

    // Over-limit mode: toggle a card in/out of the unified keep set.
    // Drawn cards are capped at keepCount; hand cards are capped only by maxHandSize total.
    private func toggleOverLimitCard(_ card: Card, isDrawnCard: Bool) {
        guard let action = pendingDrawAction else { return }
        if keptCardIds.contains(card.id) {
            keptCardIds.remove(card.id)
        } else if keptCardIds.count < maxHandSize {
            if isDrawnCard {
                // Count how many drawn cards are already kept
                let keptDrawnCount = keptCardIds.filter { id in
                    action.drawCount > 0 && (deckState?.deck.prefix(action.drawCount).contains(where: { $0.id == id }) ?? false)
                }.count
                guard keptDrawnCount < action.keepCount else { return }
            }
            keptCardIds.insert(card.id)
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

                let newHand: [Card]
                let discardedFromDraw: [Card]
                let discardedFromHand: [Card]

                if isOverLimit {
                    // Keep only cards in keptCardIds, across both drawn and existing hand
                    let keptDrawn = drawnCards.filter { keptCardIds.contains($0.id) }
                    let keptHand = state.hand.filter { keptCardIds.contains($0.id) }
                    newHand = keptHand + keptDrawn
                    discardedFromDraw = drawnCards.filter { !keptCardIds.contains($0.id) }
                    discardedFromHand = state.hand.filter { !keptCardIds.contains($0.id) }
                } else {
                    // Normal: keep selected drawn cards, existing hand unchanged
                    let keptDrawn = drawnCards.filter { selectedCards.contains($0.id) }
                    newHand = state.hand + keptDrawn
                    discardedFromDraw = drawnCards.filter { !selectedCards.contains($0.id) }
                    discardedFromHand = []
                }

                let newDeckState = DeckState(
                    deck: Array(state.deck.suffix(state.deck.count - action.drawCount)),
                    hand: newHand,
                    discardPile: state.discardPile + discardedFromDraw + discardedFromHand
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
                    keptCardIds.removeAll()
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

// MARK: - Card Detail Sheet

struct CardDetailSheet: View {
    let definition: CustomCard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Type badge + title
                    CardTypeBadge(type: definition.type)

                    Text(definition.displayTitle)
                        .font(.title2)
                        .fontWeight(.bold)

                    // Full description
                    Text(definition.displaySubtitle)
                        .font(.body)
                        .foregroundColor(.secondary)

                    // Casting cost for curses
                    if definition.type == .curse, let cost = definition.castingCost {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Casting Cost")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(CardType.curse.themeColor)
                            Label(cost, systemImage: "creditcard.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Card Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
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
