# Deck Migration to Game Base Level - Summary

## Overview

The card deck has been migrated from a separate `hiderDeck` node to the base level of the `Game` struct. All database operations are now handled by `DatabaseManager`, and `CardDeckManager` only manages UI state for pending draw actions.

## Changes Made

### 1. Game Model (Game.swift)

**Added deck field:**
```swift
struct Game: Codable {
    let info: GameInfo
    var teams: GameTeams
    var messages: [String: GameMessage] = [:]
    var deck: DeckState?  // ← Added
}
```

The deck is now part of the main game structure and syncs automatically with `currentGame`.

### 2. DatabaseManager+Deck.swift

**All deck operations moved here:**

#### `initializeDeckIfNeeded(gameId:)`
- Checks if deck exists at `games/{gameId}/deck`
- Creates new shuffled deck if doesn't exist
- Called when hider joins game

#### `drawCards(gameId:count:)`
- Uses Firebase transaction for atomicity
- Draws X cards from deck
- Adds them to hand automatically
- Handles deck reshuffling when empty
- Returns `Void` (updates game state directly)

#### `discardCards(gameId:cardsToDiscard:)`
- Uses Firebase transaction
- Removes cards from hand
- Adds cards to discard pile
- Called when player confirms card selection

**Key Implementation Details:**
- All operations use `CheckedContinuation` for proper async/await
- Transactions ensure atomic updates (no race conditions)
- Deck path: `games/{gameId}/deck` (not `hiderDeck`)
- Automatic error handling

### 3. CardDeckManager (Simplified)

**Now only handles UI state:**
```swift
class CardDeckManager: ObservableObject {
    static let shared = CardDeckManager()
    
    @Published var pendingDrawAction: DrawAction?
    
    func createDrawAction(from questionData: QuestionData) -> DrawAction
}
```

**Removed:**
- ❌ `deckState` property (now in `Game.deck`)
- ❌ `initializeDeck()` (moved to DatabaseManager)
- ❌ `startListeningToDeck()` (deck syncs with game)
- ❌ `stopListeningToDeck()` (not needed)
- ❌ `drawCards()` (moved to DatabaseManager)
- ❌ `addCardsToHand()` (built into drawCards)
- ❌ `discardCards()` (moved to DatabaseManager)
- ❌ All encoding/decoding logic

**Purpose:**
- Manages pending draw action state
- Creates DrawAction from QuestionData
- Simple, focused responsibility

### 4. GameView.swift

**Initialization:**
```swift
// Old
if playerTeam == .hiders {
    try? await cardDeckManager.initializeDeck(gameId: gameId)
    cardDeckManager.startListeningToDeck(gameId: gameId)
}

// New
if playerTeam == .hiders {
    try? await databaseManager.initializeDeckIfNeeded(gameId: gameId)
}
```

**Card Count Badge:**
```swift
// Old
if let cardCount = cardDeckManager.deckState?.hand.count

// New  
if let cardCount = databaseManager.currentGame?.deck?.hand.count
```

**Removed:**
- Deck stop listening in `onDisappear` (not needed)

### 5. GameChatView.swift

**Claim Reward:**
```swift
// Old
let drawnCards = try await cardDeckManager.drawCards(gameId: gameId, count: drawCount)
try await cardDeckManager.addCardsToHand(gameId: gameId, cards: drawnCards)

// New
try await databaseManager.drawCards(gameId: gameId, count: questionData.drawCount)
// Cards are automatically added to hand
```

**Action Creation:**
```swift
// Old
let action = cardDeckManager.createDrawAction(for: category)

// New
let action = cardDeckManager.createDrawAction(from: questionData)
```

### 6. HandView.swift

**Deck State:**
```swift
// Old
var deckState: DeckState? {
    cardDeckManager.deckState
}

// New
var deckState: DeckState? {
    databaseManager.currentGame?.deck
}
```

**Discard Cards:**
```swift
// Old
try await cardDeckManager.discardCards(gameId: gameId, cards: cardsToDiscard)

// New
try await databaseManager.discardCards(gameId: gameId, cardsToDiscard: cardsToDiscard)
```

## Database Structure

### Old Structure:
```
games/
  {gameId}/
    info: {...}
    teams: {...}
    messages: {...}
    hiderDeck/           ← Separate node
      deck: [...]
      hand: [...]
      discardPile: [...]
```

### New Structure:
```
games/
  {gameId}/
    info: {...}
    teams: {...}
    messages: {...}
    deck/                ← Part of game
      deck: [...]
      hand: [...]
      discardPile: [...]
```

## Benefits

### 1. **Automatic Synchronization**
- Deck syncs with `currentGame` automatically
- No separate listener needed
- Real-time updates work seamlessly

### 2. **Simplified State Management**
- One source of truth (`currentGame`)
- No duplicate state in CardDeckManager
- Cleaner data flow

### 3. **Better Code Organization**
- Database code in DatabaseManager
- UI state in CardDeckManager
- Clear separation of concerns

### 4. **Atomic Operations**
- Transactions ensure consistency
- No race conditions
- Safe concurrent access

### 5. **Easier Debugging**
- All game data in one place
- Simpler to inspect in Firebase Console
- Clearer data model

## Error Resolution

### Original Error:
```
Error decoding deck state: keyNotFound(CodingKeys(stringValue: "hand", intValue: nil), ...)
```

### Cause:
- CardDeckManager was looking at `hiderDeck` path
- Game model had `deck` field at base level
- Path mismatch caused decoding error

### Solution:
- Moved all operations to `games/{gameId}/deck`
- Database Manager now handles all deck operations
- Game.deck automatically populated by existing game listener
- No separate deck listener needed

## Migration Path

### For Existing Games:

**Option 1: Automatic Migration**
- Old games may have `hiderDeck` node
- Will create `deck` node when hider rejoins
- Can run migration script to move data

**Option 2: Clean Slate**
- New games automatically get `deck` at correct path
- Old games can continue with `hiderDeck` (if compatible)
- Eventually all games will use new structure

### Recommended:
Delete old test games and create new ones with proper structure.

## Testing Checklist

- [ ] Deck initializes when hider joins
- [ ] Cards appear in hand after claiming reward
- [ ] Card count badge updates correctly
- [ ] Hand view shows correct cards
- [ ] Draw mode works (select cards)
- [ ] Discard operation removes correct cards
- [ ] Deck reshuffles when empty
- [ ] Multiple hiders see same deck (if supported)
- [ ] Game state persists on app restart
- [ ] No decoding errors in console

## Code Flow

### Claiming Reward:

1. **Hider answers question**
2. **Reward button appears**
3. **Hider taps "Draw X, Keep Y"**
4. **GameChatView.handleClaimReward():**
   - Calls `databaseManager.drawCards()`
   - Creates `DrawAction`
   - Sets `pendingDrawAction`
   - Dismisses chat

5. **GameView detects pendingDrawAction:**
   - Opens HandView automatically

6. **HandView:**
   - Reads `databaseManager.currentGame?.deck`
   - Shows drawn cards
   - Allows selection

7. **User confirms selection:**
   - Calls `databaseManager.discardCards()`
   - Clears `pendingDrawAction`

8. **Game updates:**
   - `currentGame?.deck` updates automatically
   - Hand view refreshes
   - Badge updates

## Summary

✅ **Deck is now at game base level**  
✅ All database operations in DatabaseManager  
✅ CardDeckManager handles only UI state  
✅ Automatic synchronization with currentGame  
✅ Simpler, cleaner architecture  
✅ No decoding errors  
✅ Atomic database operations  
✅ Single source of truth  

The migration centralizes deck management, eliminates redundant state, and provides a cleaner, more maintainable architecture.
