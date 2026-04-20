# Plan: Card Interaction & Hand Management

## Overview
Add three features to the HandView:
1. **Tap to share in chat** - Tapping a card in your hand sends its info as a chat message
2. **Manual draw** - A button to draw a card from the deck into your hand
3. **Manual delete** - A button/gesture to discard a card from your hand

## Files to Modify

### 1. `HandView.swift` - Main changes
- **Tap-to-share**: Make each card in `normalHandContent` tappable. On tap, send a text message to the game chat with the card's details (type, title, description/cost). After sending, show brief confirmation feedback.
- **Manual draw button**: Add a "Draw Card" button in the `handHeader` area (visible only when NOT in draw mode). Tapping it draws the top card from the deck, adds it to the hand, and persists via `updateDeckState`. Disable when deck is empty.
- **Manual delete**: Add a tap-to-select mode or swipe-to-delete on cards in normal hand view. Selected card gets a "Discard" confirmation, then is removed from hand and added to the discard pile via `updateDeckState`.

### 2. `ChatViewModel.swift` - New method
- Add a `sendCardMessage()` method that creates a `GameMessage` of type `.text` with a formatted string describing the card (e.g. "[Curse] Silent Step - Seekers can't see hiders' locations for 2 min. | Cost: Reveal your current region").

### 3. `GameView.swift` - Pass dependencies
- Pass `chatViewModel`, `currentUser`, and `currentPlayerTeam` into the `HandView` so it can send chat messages. Update the `handSheet` computed property accordingly.

### 4. `Game.swift` (models) - No changes needed
- The existing `MessageType.text` and `GameMessage` structure are sufficient.

## Detailed Implementation

### Step 1: Update HandView to accept chat dependencies
Add new parameters to `HandView`:
- `chatViewModel: ChatViewModel`
- `currentUser: User?`
- `currentPlayerTeam: Team`

Update the `handSheet` in `GameView.swift` to pass these through.

### Step 2: Tap card to send in chat
In `normalHandContent`, wrap each `CardView` in a `Button` or add `.onTapGesture`. On tap:
1. Build a formatted string from `card.definition` (type badge + title + subtitle + casting cost if applicable)
2. Call `chatViewModel.sendMessage()` with that string
3. Show a brief toast/overlay confirming "Card shared in chat"

### Step 3: Manual draw card
Add a "Draw Card" button below the hand header (or as part of it). On tap:
1. Check `deckState.deck` is non-empty
2. Create new DeckState: remove first card from deck, append to hand
3. Call `gameManager.updateDeckState()` to persist
4. If deck is empty after shuffle from discard pile, still allow draw (DeckState.drawCards handles reshuffling)

### Step 4: Manual discard card
Add a way to delete cards from hand. Two approaches (using context menu):
- Long-press a card to show a "Discard" context menu option
- On confirm: remove card from hand, add to discard pile, persist via `updateDeckState()`

### Step 5: Update GameView's handSheet
Pass the new required parameters to `HandView` in the `handSheet` computed property.
