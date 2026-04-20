# Custom Card Decks — Implementation Plan

This plan adds **user-authored card decks** to Hide and CSeek50: users can create, edit, rename, duplicate, and delete their own decks of custom cards. Each card is either a **Curse**, **Powerup**, or **Time Bonus**. Users set a multiplier for how many copies of each card are included in the deck. Decks live under the user's account in Firebase Realtime Database, persist across log-out, and can be selected per-game by the lobby host so that all players in the round draw from the chosen deck.

This plan intentionally mirrors the shape of `CUSTOM_QUESTION_SETS_PLAN.md` — the same snapshot-on-game-start pattern, the same read-only "Default" seeded deck, the same Firebase path structure under `users/{uid}/...`, and the same CRUD / listener idiom in the view model. Wherever a prior decision from question sets applies cleanly, this plan reuses it.

---

## 1. What we're changing (high level)

1. **New data model** — `CardDeck` → `CardDeckEntry` → `CustomCard` (with a `type` discriminant: `curse`, `powerup`, or `timeBonus`). Lives under each user's account.
2. **Standard 52-card poker deck becomes configurable** — today `DeckState(shouldPopulate: true)` hardcodes a shuffled 52-card deck (`Views/Card.swift:100`). It will instead be built from the selected `CardDeck` snapshot at game start. The existing draw/keep/discard mechanics stay the same.
3. **New screens off the home screen**:
   - **Card Decks** (list / management): rename, duplicate, delete, open.
   - **Edit Card Deck**: add/remove/reorder card entries, edit each card's type-specific fields, edit multiplier (count per deck).
   - **Card Editor**: one form per card with type-switching behavior (Curse / Powerup / Time Bonus).
4. **Lobby**: `CreateLobbyView` and `LobbySettingsView` get a **Card Deck** picker (host-only), beside the existing question-set picker.
5. **Game start**: a *snapshot* of the chosen deck is written onto `games/{gameId}/info/settings/cardDeck` (id + full deck). All players read the deck from the snapshot; mid-game edits to the source deck do **not** affect running games.
6. **Gameplay**: `DeckState` is populated by expanding the snapshot (each `CardDeckEntry` → N copies of its `CustomCard`), shuffled once on game start. Card drawing, hand management, and the reshuffle-discard-when-empty behavior in `DeckState.drawCards` (`Views/Card.swift:120`) stay the same. `HandView`/`CardView` are updated to render the new card types (title, description, casting cost, bonus minutes) instead of the poker suit/rank visuals.
7. **Default deck**: every user gets a seeded `Default` deck on signup and idempotently on launch — mirrors a sensible starter set of curses, powerups, and time bonuses so gameplay "just works" for users who never open the editor.

### Important constraints from the existing code

- `Game.deck: DeckState` is already persisted per-game in RTDB (see `Game` struct in `Models/Game.swift:20` and `updateDeckState` in `GameManager.swift:745`). The wire format of `DeckState` changes (cards are no longer `{suit, rank}`); we keep the field name `deck` on `Game` so the `Game.toDictionary`/`fromDictionary` round-trip just swaps which `Card` dictionary shape is written.
- `HandView` reads `gameManager.currentGame?.deck` (`Views/HandView.swift:29`) and the draw/keep flow is driven entirely by `QuestionData.reward` parsed as `"Draw X, Keep Y"`. That contract is **unchanged**. The only thing that changes is what a "card" is and how it renders.
- `DeckState.drawCards` automatically reshuffles `discardPile` back into the deck when empty (`Views/Card.swift:120`). Keep that behavior — custom decks benefit from the same rule so players never run out mid-game.

---

## 2. New / changed Swift models

### 2a. `Models/CardDeck.swift` (new file)

```swift
struct CardDeck: Codable, Identifiable, Equatable {
    let id: String                   // UUID; "default" for seeded deck
    var name: String
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date
    var entries: [CardDeckEntry]     // ordered by orderIndex on read

    static let defaultId = "default"
    static let defaultName = "Default"

    var cardCount: Int { entries.reduce(0) { $0 + $1.multiplier } }
    var uniqueCardCount: Int { entries.count }
}

struct CardDeckEntry: Codable, Identifiable, Equatable {
    let id: String                   // UUID — stable id for the entry (card definition)
    var card: CustomCard
    var multiplier: Int              // how many copies of this card go into the deck (1–20)
}

struct CustomCard: Codable, Equatable {
    // Shared
    let id: String                   // UUID — re-used when expanding copies; each copy gets "<id>#<n>" at game start
    var type: CardType

    // Curse
    var curseTitle: String?          // required when type == .curse
    var curseDescription: String?
    var castingCost: String?         // free-form text (per spec)

    // Powerup
    var powerupTitle: String?        // required when type == .powerup
    var powerupDescription: String?

    // Time Bonus
    var timeBonusMinutes: Int?       // required when type == .timeBonus (1–120)
}

enum CardType: String, Codable, CaseIterable {
    case curse
    case powerup
    case timeBonus

    var displayName: String {
        switch self {
        case .curse: return "Curse"
        case .powerup: return "Powerup"
        case .timeBonus: return "Time Bonus"
        }
    }

    var iconName: String {
        switch self {
        case .curse: return "bolt.trianglebadge.exclamationmark.fill"
        case .powerup: return "sparkles"
        case .timeBonus: return "clock.badge.fill"
        }
    }

    var themeColor: Color {
        switch self {
        case .curse: return .purple
        case .powerup: return .yellow
        case .timeBonus: return .blue
        }
    }
}
```

**Why one `CustomCard` struct with optional fields instead of an enum with associated values?** RTDB dictionary round-trip is much simpler when every field is a top-level key on a flat `[String: Any]`. The `type` discriminant tells the UI and validation which fields apply. Validation (see §6) ensures the right fields are populated before saving or using at game start.

Add `toDictionary()` / `fromDictionary(_:)` to each type — follow the pattern in `Extensions/GameModels+Dictionary.swift` (RTDB needs `[String: Any]`, no `Date` direct; use `Date.toFirebaseTimestamp()`).

### 2b. Update `Views/Card.swift` — `Card`/`Suit`/`Rank` → generic card

Today `Card` is `{suit: Suit, rank: Rank}` with poker visuals. Replace with a deck-agnostic card that references the originating `CustomCard` content plus a per-copy instance id:

```swift
struct Card: Identifiable, Codable, Equatable {
    let instanceId: String           // stable id per physical copy, e.g. "<customCardId>#<copyIndex>"
    let definition: CustomCard       // snapshot of the card content at game start
    var id: String { instanceId }
}
```

Keep `DeckState` intact — the `deck`/`hand`/`discardPile` arrays still hold `[Card]`. Only `init(shouldPopulate:)` goes away; see §2c.

**Why embed `definition` on each `Card` instead of storing a reference and looking it up on the deck snapshot?**
- Keeps `Card` self-contained so `HandView`/`CardView` don't need the deck snapshot to render.
- `Game.deck.deck/hand/discardPile` are already Codable and round-trip through RTDB as dictionaries; embedding the definition mirrors how `GameMessage` carries `QuestionData` inline.
- Trade-off: 52-card decks become larger in RTDB. In practice `CustomCard` is tiny (<1 KB) so the total deck size stays well under RTDB write limits.

### 2c. `DeckState` construction from a snapshot

Remove `DeckState.init(shouldPopulate: Bool)` and replace with:

```swift
extension DeckState {
    static func makeShuffled(from deck: CardDeck) -> DeckState {
        var cards: [Card] = []
        for entry in deck.entries {
            for copyIndex in 0..<max(entry.multiplier, 0) {
                let instanceId = "\(entry.card.id)#\(copyIndex)"
                cards.append(Card(instanceId: instanceId, definition: entry.card))
            }
        }
        cards.shuffle()
        return DeckState(deck: cards, hand: [], discardPile: [])
    }
}
```

Leave `drawCards`, `addToHand`, `removeFromHand`, `discardCards` unchanged. The reshuffle-discard-when-empty path already handles any deck size.

### 2d. Update `Models/Game.swift`

`GameSettings` gets two new fields (analogous to the question-set snapshot):

```swift
struct GameSettings: Codable {
    // ...
    var cardDeckId: String? = nil
    var cardDeck: CardDeck? = nil
}
```

No other changes to `GameInfo`/`Game`. The existing `Game.deck: DeckState` is still the live deck for the running game — it's just been populated from the snapshot instead of the hardcoded 52.

### 2e. Update `Models/Lobby.swift`

Same pattern as question sets: lightweight id+name on the lobby, full snapshot deferred to game start.

```swift
struct Lobby: Codable, Equatable {
    // ...
    var cardDeckId: String? = nil
    var cardDeckName: String? = nil
}
```

Update `Lobby.toDictionary`/`fromDictionary` to read/write both (default `nil` so old lobbies still parse).

### 2f. Wire-format migration of `Card`

`Suit` and `Rank` enums get deleted with `init(shouldPopulate:)`. Any in-progress games persisted before the migration still have `{suit, rank}` cards in their `DeckState`. Options:

- **(Preferred) Legacy decoder fallback** — in `Extensions/GameModels+Dictionary.swift`, `Card.fromDictionary` tries the new shape first (`instanceId` + `definition`). On failure, falls back to parsing `{suit, rank}` and synthesizes a `CustomCard(type: .powerup, powerupTitle: "\(rank) of \(suit)", powerupDescription: "Legacy card from a previous game")`. This lets old in-progress games finish without crashing.
- **(Fallback) Fresh deploy** — if Ryan can drain in-progress games before deploying, skip the legacy decoder and crash-loud on parse failure.

This plan assumes the **preferred** option.

---

## 3. Firebase Realtime Database changes

### 3a. New path

```
users/{uid}/cardDecks/{cardDeckId}/
  id, name, isDefault, createdAt, updatedAt
  entries/
    {entryId}/
      id, multiplier, orderIndex
      card/
        id, type
        curseTitle, curseDescription, castingCost              // iff type == curse
        powerupTitle, powerupDescription                       // iff type == powerup
        timeBonusMinutes                                       // iff type == timeBonus
```

Notes:
- Use UUIDs for ids. For the seeded Default deck, use `"default"` as `cardDeckId`.
- Store `orderIndex` on each entry; sort by it on read (RTDB doesn't preserve dictionary order).
- Write only the type-specific fields that apply, so the wire shape reflects the card's type. The decoder requires all fields for the declared `type` and rejects rows missing required data.

### 3b. Snapshot on the game

```
games/{gameId}/info/settings/cardDeckId: "<uuid>"
games/{gameId}/info/settings/cardDeck:    { ...full CardDeck snapshot... }
```

Players read the snapshot from `games/{gameId}` (already readable by all players in the game). They never need read access to another user's `users/.../cardDecks` node.

### 3c. Snapshot on the lobby (lightweight)

```
lobbies/{code}/cardDeckId:   "<uuid>"
lobbies/{code}/cardDeckName: "My Deck"
```

Just id + name for the lobby UI. The full deck is inlined at game start.

### 3d. Security rules — instructions for Ryan

The per-user rule in `Markdown/firebase-database-rules.json` already covers any new subpath under `users/{uid}`:

```json
"users": { "$uid": {
  ".read": "auth != null",
  ".write": "auth != null && auth.uid == $uid"
}}
```

**No rule changes are required for the new `cardDecks` path.** What to do manually in the Firebase console:
1. Open Firebase Console → Realtime Database → Rules.
2. Confirm the deployed rules match `Markdown/firebase-database-rules.json`. If yes, no edit.
3. (Optional) Add `".indexOn": ["updatedAt"]` under `users/{uid}/cardDecks` for faster list queries.

### 3e. Cloud functions — no change

`cloud_functions/functions/index.js` doesn't read the deck for stats. Adding `cardDeck` to settings is purely additive.

---

## 4. Default-deck seeding

Add to `UserManager`:

```swift
func seedDefaultCardDeckIfNeeded(uid: String) async throws
```

Called from:
- `AuthenticationManager.createUserProfileIfNeeded(...)` on first signup.
- `MainView.onAppear` for the current user (idempotent — single `getData()` on `users/{uid}/cardDecks/default`, create only if missing). This mirrors how `seedDefaultQuestionSet()` is already wired in `Views/MainView.swift:433-438`.

The seeded Default deck has id `"default"`, `isDefault: true`, and a starter set of ~12 cards:

| Entry | Type       | Fields                                                                                  | Multiplier |
|-------|------------|-----------------------------------------------------------------------------------------|------------|
| 1     | curse      | title: "Silent Step", desc: "Seekers can't see hiders' locations for 2 minutes", cost: "Reveal your region" | 2 |
| 2     | curse      | title: "Blind Radar", desc: "Next radar question must be answered with 'Maybe'", cost: "Send a photo"       | 2 |
| 3     | curse      | title: "Scenic Route", desc: "Seekers must travel in a straight line for 3 minutes", cost: "Skip next turn" | 1 |
| 4     | powerup    | title: "Skip Question", desc: "Discard one question without answering"                  | 3 |
| 5     | powerup    | title: "Double Reward", desc: "Your next question gives double cards"                   | 2 |
| 6     | powerup    | title: "Truth Serum", desc: "Ask one extra short-answer question immediately"           | 1 |
| 7     | powerup    | title: "Veto", desc: "Cancel a curse cast on you"                                       | 1 |
| 8     | timeBonus  | minutes: 2                                                                              | 4 |
| 9     | timeBonus  | minutes: 5                                                                              | 3 |
| 10    | timeBonus  | minutes: 10                                                                             | 1 |

Total of ~20 physical cards. The Default deck is **fully locked** (see §5 for UI rules):
- Cannot be renamed, edited, or deleted.
- Can be duplicated into a new editable deck.
- Editor opens read-only with a "Duplicate to edit" CTA banner.

---

## 5. New UI screens

### 5a. Home screen entry point — `Views/MainView.swift`

Replace the current 2x2 grid of secondary actions with a 2x2 that includes Card Decks, or add a new row. Proposed third row (below Quick Match / Question Sets):

```swift
ActionButton(
    title: "Card Decks",
    subtitle: "Design your own cards",
    icon: "rectangle.stack.fill",
    color: .indigo,
    isPrimary: false
) {
    showingCardDecks = true
}
```

Add `@State private var showingCardDecks = false` and `.sheet(isPresented: $showingCardDecks) { CardDecksListView() }`.

Also add `seedDefaultCardDeckIfNeeded(uid: uid)` inside the existing `seedDefaultQuestionSet()` helper (rename to `seedDefaults()`) so both seed together on launch.

### 5b. `Views/CardDecks/CardDecksListView.swift` (new)

Lives in a new folder `Views/CardDecks/`. Same visual style as `Views/QuestionSets/QuestionSetsListView.swift`. Each row shows:
- Deck name, "Default" badge if applicable.
- Total card count (e.g. "23 cards, 9 unique").
- Last edited (relative).

Swipe actions: Rename, Duplicate, Delete (Default cannot be deleted; can be duplicated). Tap row → `CardDeckEditorView`. Top-right "+" → "Create Blank Deck" and "Duplicate Default" options.

### 5c. `Views/CardDecks/CardDeckEditorView.swift` (new)

Sections:
1. **Name** field (disabled if Default).
2. **Cards** list (reorderable). Each row shows:
   - Type icon + color chip.
   - Title (or "Time Bonus — 5 min" for time bonuses).
   - Short subtitle (description preview or casting cost preview).
   - Multiplier badge ("x3").
   - Tap → `CardEditorView`.
   - Swipe to delete.
3. **+ Add Card** button → `CardEditorView` in "new" mode (default type `.powerup`, so the form shows powerup fields).
4. **Footer**: Save (writes to RTDB), Discard, Delete (hidden for Default).

When `isDefault == true`: lock the form (`.disabled(true)` on every editable control), hide Save/Discard/Delete, show a top banner "Default deck — duplicate to edit" with a "Duplicate" button that calls the view model and dismisses into the new deck's editor.

### 5d. `Views/CardDecks/CardEditorView.swift` (new)

A form that adapts to the selected card type:

```swift
Section("Card Type") {
    Picker("Type", selection: $type) {
        ForEach(CardType.allCases, id: \.self) { t in
            Label(t.displayName, systemImage: t.iconName).tag(t)
        }
    }
    .pickerStyle(.segmented)
}

// Curse fields
Section("Curse") {
    TextField("Title", text: $curseTitle)
    TextField("Description", text: $curseDescription, axis: .vertical).lineLimit(3...6)
    TextField("Casting Cost", text: $castingCost, axis: .vertical).lineLimit(2...4)
}
.hidden(type != .curse)

// Powerup fields
Section("Powerup") {
    TextField("Title", text: $powerupTitle)
    TextField("Description", text: $powerupDescription, axis: .vertical).lineLimit(3...6)
}
.hidden(type != .powerup)

// Time Bonus fields
Section("Time Bonus") {
    Stepper(value: $timeBonusMinutes, in: 1...120) {
        Text("\(timeBonusMinutes) minute\(timeBonusMinutes == 1 ? "" : "s")")
    }
}
.hidden(type != .timeBonus)

Section("Deck Count") {
    Stepper(value: $multiplier, in: 1...20) {
        Text("\(multiplier) cop\(multiplier == 1 ? "y" : "ies") in deck")
    }
}
```

`.hidden(...)` is implemented as a `@ViewBuilder` modifier that returns `EmptyView()` when the condition is true, so changing the type truly swaps the form without preserving stale input field focus. When switching types, **preserve** the previously typed per-type values in `@State` so that flipping back doesn't lose work; only the fields relevant to the current type are written to the model on Save.

### 5e. `Views/CardDecks/CardTypeBadge.swift` (new)

Small pill-shaped badge component — `Image(systemName: type.iconName)` + type name in `type.themeColor`. Used in list rows and `CardView`.

### 5f. ViewModel: `ViewModels/CardDecksViewModel.swift` (new)

Directly mirrors `QuestionSetsViewModel`:

```swift
@MainActor
final class CardDecksViewModel: ObservableObject {
    @Published private(set) var decks: [CardDeck] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var listenerHandle: DatabaseHandle?
    private var listenerRef: DatabaseReference?
    private var currentUid: String?

    func startListening(uid: String)
    func stopListening()

    func createDeck(name: String) async throws -> CardDeck
    func updateDeck(_ deck: CardDeck) async throws
    func deleteDeck(id: String) async throws
    func renameDeck(id: String, to newName: String) async throws
    func duplicateDeck(_ source: CardDeck, newName: String) async throws -> CardDeck
}
```

Copy the listener idiom from `ViewModels/QuestionSetsViewModel.swift` verbatim — the file is 146 lines and nearly identical logic. Replace types and the RTDB child path (`cardDecks` instead of `questionSets`).

---

## 6. Validation rules (enforced in editor and at game start)

A deck is **valid to use in a game** when:
- It has at least one entry.
- Total card count (`entries.reduce(0) { $0 + $1.multiplier }`) is ≥ 1.
- Every entry has `multiplier` in 1...20.
- Every entry's `CustomCard` has all required fields for its type populated (non-empty after trimming whitespace):
  - `.curse`: `curseTitle`, `curseDescription`, `castingCost` all present.
  - `.powerup`: `powerupTitle`, `powerupDescription` present.
  - `.timeBonus`: `timeBonusMinutes` in 1...120.

Validation lives in two places:
- **Editor (live)**: `CardEditorView` disables Save when the current card fails its type's required-fields check, and shows inline red-text errors beneath missing fields.
- **Game start (`GameManager.startGame`)**: re-validates the snapshot after fetching and throws `GameStartError.emptyDeck` or `GameStartError.invalidCard(entryId)` if bad. Surface the error in `LobbyView` the same way the question-set validation does.

---

## 7. Lobby integration

### 7a. `CreateLobbyView`

Mirrors the existing question-set picker (`Views/Lobby/CreateLobbyView.swift:25-33`). Add:

```swift
@State private var availableDecks: [CardDeck] = []
@State private var selectedCardDeckId: String = CardDeck.defaultId

private var selectedDeckName: String {
    availableDecks.first { $0.id == selectedCardDeckId }?.name ?? CardDeck.defaultName
}
```

New `Section("Cards")` with a `Picker` listing the host's decks (fetched once on appear). Pass `cardDeckId` + `cardDeckName` to `gameManager.createLobby(...)`.

### 7b. `GameManager.createLobby(...)`

Extend the signature with `cardDeckId: String?` and `cardDeckName: String?`; persist into the new `Lobby` fields. Keep the existing question-set params; both default to `nil`.

### 7c. `LobbyView`

Show the selected deck's name in `lobbySettingsSection`, read-only for non-hosts, tappable for host to open `LobbySettingsView`.

### 7d. `LobbySettingsView`

Same picker as create; on Save, `gameManager.updateLobbySettings(...)` writes the new id+name. Extend that function signature with optional params; they default to `nil` to leave unchanged.

### 7e. Fetching decks for pickers

The picker doesn't need a long-lived listener. Add `UserManager.getCardDecks(uid:) async throws -> [CardDeck]` — a single `.getData()` on `users/{uid}/cardDecks`. Used by `CreateLobbyView.onAppear` and `LobbySettingsView.onAppear`.

---

## 8. Game start integration — snapshot

In `GameManager.startGame(...)` (near `Logic/GameManager.swift:345-390` where the question-set snapshot and initial `DeckState` are built):

1. Read `lobby.cardDeckId`. If `nil`, fall back to `CardDeck.defaultId`.
2. Fetch the host's `users/{lobby.hostUID}/cardDecks/{id}` via `UserManager.getCardDeck(uid:id:)`.
3. Validate per §6. On failure, throw; surface in `LobbyView`.
4. Inline the full deck into `settings.cardDeck` and set `settings.cardDeckId`.
5. Build the initial `DeckState` via `DeckState.makeShuffled(from: snapshotDeck)` — replacing the current `DeckState(shouldPopulate: true)` at `Logic/GameManager.swift:386`.
6. Continue with the existing game-write (`gameRef.setValue(try game.toDictionary())`).

### Deck isolation

Because the snapshot is frozen into `games/{gameId}/info/settings/cardDeck` and the expanded `DeckState` is written to `games/{gameId}/deck`, mid-game edits to the source `users/{uid}/cardDecks/{id}` never affect a running game. Same guarantee as question sets.

---

## 9. Gameplay integration

### 9a. `Views/HandView.swift` and `CardView`

Today `CardView` draws suit/rank visuals (`Views/HandView.swift:386-472`). Replace with a type-aware card renderer that reads `card.definition`:

```swift
struct CardView: View {
    let card: Card
    let isSelected: Bool
    let isInteractive: Bool

    var body: some View {
        let def = card.definition
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemBackground))
            .overlay(
                VStack(alignment: .leading, spacing: 8) {
                    CardTypeBadge(type: def.type)
                    Text(titleText(for: def))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    Text(subtitleText(for: def))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    if def.type == .curse, let cost = def.castingCost {
                        Divider()
                        Label("Cost: \(cost)", systemImage: "creditcard.fill")
                            .font(.caption2)
                            .foregroundColor(def.type.themeColor)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                .padding(12)
            )
            .aspectRatio(0.7, contentMode: .fit)
            // selection overlay unchanged
    }

    private func titleText(for def: CustomCard) -> String {
        switch def.type {
        case .curse: return def.curseTitle ?? "Curse"
        case .powerup: return def.powerupTitle ?? "Powerup"
        case .timeBonus: return "+\(def.timeBonusMinutes ?? 0) min"
        }
    }

    private func subtitleText(for def: CustomCard) -> String {
        switch def.type {
        case .curse: return def.curseDescription ?? ""
        case .powerup: return def.powerupDescription ?? ""
        case .timeBonus: return "Time Bonus"
        }
    }
}
```

- `HandView.handHeader` and `drawModeHeader` are unchanged — they read `state.hand.count` / `state.deck.count`, which are still arrays of `Card`.
- `drawModeContent` iterates drawn cards and renders `CardView` — unchanged logic, new visuals.

### 9b. Card selection semantics

`selectedCards: Set<String>` is already keyed by `Card.id` (which is `instanceId` post-migration). No change needed — `toggleCardSelection` etc. work as-is.

### 9c. Draw-keep-discard flow

No changes to `confirmSelection` (`Views/HandView.swift:335-383`). It operates on `Card` instances, updates `state.deck`/`state.hand`/`state.discardPile`, and writes back via `gameManager.updateDeckState`. Works identically with the new `Card` shape.

### 9d. "Using" a card (future work — out of scope)

This plan is only about **creating, shuffling, drawing, and displaying** custom cards. Actual effects (applying a curse, consuming a powerup, adding time to the clock from a time bonus) are intentionally **not wired** in this plan — today even the existing poker cards have no gameplay effect beyond being held in a hand. Keeping parity means `HandView` shows the cards, and that's it. When we're ready to add effects, the hooks go in `GameManager` (e.g. `applyTimeBonus`, `castCurse`) and a new "Play Card" button on `CardView`. Tracked as a follow-up.

---

## 10. Concrete file change list

**New files:**
- `Models/CardDeck.swift` — types from §2a.
- `Extensions/CardDeck+Dictionary.swift` — RTDB conversion for `CardDeck`, `CardDeckEntry`, `CustomCard`.
- `ViewModels/CardDecksViewModel.swift` — listing + CRUD (copied structure from `QuestionSetsViewModel`).
- `Views/CardDecks/CardDecksListView.swift`
- `Views/CardDecks/CardDeckEditorView.swift`
- `Views/CardDecks/CardEditorView.swift`
- `Views/CardDecks/CardTypeBadge.swift`

**Edited files:**
- `Views/Card.swift` — replace `Card`/`Suit`/`Rank`; add `DeckState.makeShuffled(from:)`; remove `DeckState.init(shouldPopulate:)`.
- `Models/Game.swift` — `GameSettings` adds `cardDeckId`/`cardDeck`.
- `Models/Lobby.swift` — `Lobby` adds `cardDeckId`/`cardDeckName`; update `toDictionary`/`fromDictionary`.
- `Extensions/GameModels+Dictionary.swift` — encode/decode new `Card` shape; legacy fallback per §2f; encode/decode `cardDeck` snapshot in `GameSettings`.
- `Logic/UserManager.swift` — add `seedDefaultCardDeckIfNeeded`, `getCardDecks`, `getCardDeck(uid:id:)`, `saveCardDeck`, `deleteCardDeck`, `renameCardDeck`.
- `Logic/AuthenticationManager.swift` — call `seedDefaultCardDeckIfNeeded` alongside the existing question-set seed in `createUserProfileIfNeeded`.
- `Logic/GameManager.swift` — `createLobby` / `updateLobbySettings` accept `cardDeckId`+`cardDeckName`; `startGame` fetches the host's deck, validates, writes the snapshot to `info.settings.cardDeck`, builds `DeckState` via `makeShuffled(from:)`.
- `Views/MainView.swift` — add "Card Decks" entry point + seed call on launch.
- `Views/Lobby/CreateLobbyView.swift` — deck picker section.
- `Views/Lobby/LobbyView.swift` — show selected deck name.
- `Views/Lobby/LobbySettingsView.swift` — deck picker.
- `Views/HandView.swift` — `CardView` rewritten per §9a; header text unchanged.
- `HideAndCSeek50App.swift` — (optional) call `seedDefaultCardDeckIfNeeded` on launch for signed-in user; alternatively keep seeding in `MainView.onAppear` as today.

**Database/rules:**
- `Markdown/firebase-database-rules.json` — no required change. Optional `.indexOn` for `users/{uid}/cardDecks`.
- `Markdown/DATABASE_SCHEMA_JSON.md` and `DATABASE_SCHEMA_OVERVIEW.md` — document the new `cardDecks` path and the new `cardDeck` snapshot under `games/{gameId}/info/settings`.

---

## 11. Suggested build order

1. **Models + dictionary conversions + UserManager CRUD + Default seeding** (no UI yet). App still runs on the old 52-card poker deck; nothing is wired.
2. **`CardDecksViewModel` + `CardDecksListView`** (list-only, read). Entry point added to `MainView`.
3. **`CardDeckEditorView` + `CardEditorView`** — full editing. End-to-end test: create deck → add cards of all three types → save → reopen → content persists.
4. **Lobby pickers + `GameManager.createLobby` / `updateLobbySettings` plumbing**. Host can pick a deck; non-host sees its name. Deck isn't used in game yet.
5. **`GameManager.startGame` snapshot + `DeckState.makeShuffled(from:)` cutover**. Delete `DeckState(shouldPopulate: true)`. Games now start with the host's chosen deck.
6. **`Views/Card.swift` + `HandView.swift` CardView rewrite**. Visuals change from poker cards to typed custom cards. This is the breaking cutover for the wire format.
7. **Legacy `Card` decoder fallback in `GameModels+Dictionary.swift`** if in-progress games need to survive the deploy.
8. **End-to-end test**: create deck → create lobby → start game → ask question → answer → draw reward → select keeps → cards appear in hand with correct title/description/cost/minutes.

After step 1–4 the app compiles and runs but still uses the 52-card poker deck. Step 5 is when the game first pulls from a custom deck. Step 6 is the UI cutover.

---

## 12. Test checklist

- [ ] Fresh signup → `Default` card deck appears under the user's account with the seeded entries from §4.
- [ ] Existing user on app open → `Default` deck seeded if missing, untouched if present.
- [ ] Create / rename / delete custom deck; sign out + back in → deck persists.
- [ ] Cannot delete or edit `Default` (UI prevents it); **can** duplicate Default.
- [ ] Duplicate Default → new editable deck with identical content.
- [ ] Create a Curse card — all three fields (title, description, casting cost) required before Save enables.
- [ ] Create a Powerup card — title + description required; casting cost and minutes fields are NOT shown.
- [ ] Create a Time Bonus card — only a 1–120 minutes stepper is shown; switching to Curse then back to Time Bonus preserves the previously typed minutes.
- [ ] Multiplier stepper enforces 1–20 and the deck total updates live in the editor footer.
- [ ] Cannot save a deck with zero entries or any invalid entry (inline error shown).
- [ ] Lobby host picks a custom deck; non-host sees its name in `LobbyView`.
- [ ] Starting a game with the Default deck → `games/{gameId}/info/settings/cardDeck` snapshot written; `games/{gameId}/deck.deck` has the expected number of shuffled copies.
- [ ] Starting a game with a deck containing, say, 3x "Skip Question" → opening the hand after a Draw 3, Keep 1 pull can produce duplicate-titled cards (verifying multiplier expansion).
- [ ] Starting a game with an **empty** or **invalid** deck → `GameManager.startGame` throws; error surfaced in `LobbyView`; game does not start.
- [ ] Editing the source deck during a live game does NOT change the running game (snapshot isolation).
- [ ] In `HandView`, drawing cards via a question reward shows Curse/Powerup/Time Bonus visuals with correct type badge, title, description, and (for curse) casting cost.
- [ ] "Keep Selected Cards" flow still writes `hand`/`discardPile` correctly with the new `Card` shape; rejoining the game preserves the hand.
- [ ] Reshuffle-from-discard behavior: draw until deck is empty → next draw pulls from reshuffled discard pile. (Inject a small deck to make this fast to test.)
- [ ] Legacy decode: an in-progress game that started on the old 52-card build continues to load (cards render as placeholder Powerups with "Legacy card…").
- [ ] Cloud function `updateGameStatistics` still fires on game completion (deck changes are additive; nothing in that function reads the deck).

---

## 13. Debugging plan

Concrete things to add during implementation to keep issues findable:

### 13a. Structured logging
- `CardDecksViewModel.startListening` — `print("🃏 Listening to users/\(uid)/cardDecks")` on attach; log parse failures from `parse(snapshot:)` with the raw dictionary so malformed entries are visible.
- `UserManager.saveCardDeck` / `deleteCardDeck` — log the deck id, name, entry count; wrap Firebase errors and rethrow with context (`"saveCardDeck(\(id)): \(error)"`).
- `GameManager.startGame` — at the snapshot step, log: chosen `cardDeckId`, entry count, total card count, validation result. When building `DeckState`, log `deck.count` after shuffle.
- `HandView.confirmSelection` — log the `instanceId`s being kept vs. discarded so a mismatch between UI selection and RTDB write is obvious.
- All logs behind a single `CardDebug.enabled` flag in `CardDeck.swift` so they can be silenced for release.

### 13b. Parse-failure diagnostics
- `Card.fromDictionary` and `CustomCard.fromDictionary` should throw a `DatabaseError.invalidData("Card.fromDictionary: missing \(field) for type \(type)")` that names the offending field and the card id. RTDB writes are flat `[String: Any]`, and "silent drop" failures (where a malformed row just doesn't render) are the most painful class of bugs to track down.
- In the legacy decoder fallback, log `⚠️ Legacy card decoded (suit=..., rank=...)` once per unique legacy card; that way we know when the codebase can safely delete the legacy branch.

### 13c. Seeder idempotency
- `seedDefaultCardDeckIfNeeded` must do a single `getData()` check first and skip if present. Log the result (`"Default deck already present"` / `"Seeding default deck"`). Avoid `setValue` of the entire default deck on every launch — that would overwrite any user-side cache and cause unnecessary listener churn.

### 13d. Snapshot drift check
- Add a developer-only assertion in `GameManager.startGame` after writing the game: re-read `games/{gameId}/info/settings/cardDeck` and compare its `cardCount` to the expanded `DeckState.deck.count`. They should match exactly at game start. If not, log loudly — means the expander or the decoder is dropping cards.

### 13e. UI dev helpers
- Add a hidden debug row in `CardDeckEditorView` footer showing `"Deck id: <short>  •  Unique: N  •  Total: M  •  Updated: <date>"` gated on a `#if DEBUG` or a toggle in a Settings screen.
- Add a `"Print deck JSON"` button in the editor (debug builds only) that dumps the current `CardDeck.toDictionary()` to the Xcode console. Useful for diffing editor state vs. what got written.

### 13f. Reproducing draw/shuffle bugs
- `DeckState.makeShuffled(from:)` uses `Array.shuffled()`. For deterministic tests, add an overload `makeShuffled(from:using rng: inout RandomNumberGenerator)` that unit tests can seed. Production call-site uses the default `SystemRandomNumberGenerator`.
- Unit test: deck with known multipliers in `[1, 2, 3]` and a seeded RNG → the shuffled deck contains the expected instance ids, each the expected number of times, and in a stable order for that seed.

### 13g. Failure modes to explicitly test

| Failure                                                   | How it surfaces                                           | Recovery                                                 |
|-----------------------------------------------------------|-----------------------------------------------------------|----------------------------------------------------------|
| Host deletes their chosen deck while lobby is open        | `startGame` gets 404 from RTDB; falls back to `defaultId` | Log + fallback; non-host players see no change           |
| Host's custom deck exists but is empty                    | `startGame` validation fails                              | Surface error in `LobbyView`; game does not start        |
| Deck entry has zero multiplier                            | Ignored when expanding (`max(entry.multiplier, 0)`)       | No crash; entry is effectively absent from the live deck |
| RTDB write of full snapshot exceeds write limit (>256 MB) | Shouldn't happen in practice — cap total cards at 500     | Editor hard-limits total count; error toast              |
| Legacy `{suit, rank}` card encountered mid-game           | Legacy decoder produces placeholder Powerup               | Game continues; log once per unique legacy card          |
| Concurrent edit from two devices (rare)                   | `updateDeck` is a whole-object `setValue`; last write wins | Acceptable; no transactional merging needed for v1       |

### 13h. Performance

- 52 cards was the old cap. The editor hard-limits total card count to **500** so that a malformed multiplier (e.g. "5000 copies") can't blow up RTDB writes or the shuffled in-memory `[Card]`. Enforced both in `CardEditorView` (Save disabled if the resulting total would exceed 500) and in `GameManager.startGame` (validation rejects).
- `updateDeckState` writes the full `DeckState` on every draw today (`Logic/GameManager.swift:745`). With a 500-card deck that's still small; no change needed. If profiling shows RTDB write latency regressing, switch to per-list child updates (`deck`, `hand`, `discardPile`) as a follow-up.

---

## 14. Decisions (resolved)

1. **Card model shape** — one flat `CustomCard` struct with optional per-type fields + a `type` discriminant, not a Codable enum with associated values. RTDB round-trip simplicity wins. (See §2a.)
2. **Card instance identity** — `Card.instanceId = "<customCardId>#<copyIndex>"`. Stable across RTDB writes, unique per physical copy. (See §2b.)
3. **Embedded vs referenced definitions** — each `Card` embeds its `CustomCard` definition so `HandView` renders without the snapshot. Mirrors `QuestionData` embedding. (See §2b.)
4. **Default deck editability** — fully locked; duplicate-to-edit, same as Default question set. (See §4, §5c.)
5. **Empty/invalid deck at game start** — block start with an error. (See §6, §8.)
6. **Multiplier bounds** — 1–20 per entry; total deck size capped at 500. (See §5d, §13h.)
7. **Card effects (using a card in play)** — out of scope for this plan. Today's poker cards also have no gameplay effect. Tracked as follow-up. (See §9d.)

Ready to start at step 1 of §11 once #8 and #9 are answered (or skipped).
