# Custom Question Sets — Implementation Plan

This plan adds **user-authored question sets** to Hide and CSeek50: users can create, edit, rename, and delete their own sets; the existing six built-in categories become a read-only "Default" set seeded automatically; and lobby hosts can pick which set a game uses. Sets live under each user's account in Firebase Realtime Database, so they persist across log-out/log-in.

---

## 1. What we're changing (high level)

1. New data model: `QuestionSet` → `QuestionCategoryDef` → `CustomQuestion`. Replaces the hardcoded `QuestionCategory` enum + hardcoded `questionsForCategory(_:)` in `QuestionView.swift`.
2. New screens off the home screen:
   - **Question Sets** (list / management): rename, delete, duplicate, set-as-default-on-create.
   - **Edit Question Set**: edit categories (name, icon, reward) and questions (text, type, choices, time limit).
3. **Lobby**: `CreateLobbyView` and `LobbySettingsView` get a "Question Set" picker (host-only). The host's library is the source.
4. **Game start**: a *snapshot* of the chosen set is written onto `games/{gameId}/info/settings/questionSet` so all players (including non-host) can read it without needing access to another user's `users/.../questionSets` node and so mid-game edits to the source set don't change the running game.
5. **Gameplay**: `GameQuestionView` reads from the snapshot instead of the enum + hardcoded list. `QuestionAnswerView` and `QuestionTimerView` render based on the per-question `questionType` and `timeLimit`.
6. **Default set**: every user gets a `Default` set seeded on first launch / first profile create. It mirrors today's six categories exactly, so behavior is unchanged for users who never open the new screens.

Important constraints from the existing code:
- The "ask 2x in a row" lockout uses `QuestionCategory`; we'll switch it to category **id** equality on the snapshot.
- The "asked before → reward doubled" check in `QuestionView.sendQuestion` matches on full question text — keep that.
- The reward is sent into chat as the string `"Draw X, Keep Y"` and parsed by `QuestionData.parseDrawAction(from:)` in `HandView`. Keep that string format for the reward field.

---

## 2. New / changed Swift models

### 2a. `Models/QuestionSet.swift` (new file)

```swift
struct QuestionSet: Codable, Identifiable, Equatable {
    let id: String                 // UUID
    var name: String               // "Default", "My Boston Set", ...
    var isDefault: Bool            // true only for the seeded "Default" set
    var createdAt: Date
    var updatedAt: Date
    var categories: [QuestionCategoryDef]   // ordered
}

struct QuestionCategoryDef: Codable, Identifiable, Equatable {
    let id: String                 // UUID; for "Default", reuse existing rawValues ("matching", ...)
    var name: String               // "Matching"
    var iconName: String           // SF Symbol — picked from the curated list in §5d
    var drawCount: Int             // reward "Draw X"
    var keepCount: Int             // reward "Keep Y"
    var timeLimitSeconds: Int      // how long the hider has to answer ANY question in this category
    var questions: [CustomQuestion]
}

struct CustomQuestion: Codable, Identifiable, Equatable {
    let id: String                 // UUID
    var text: String               // full question text shown to the hider
    var questionType: QuestionType
    var choices: [String]          // used only when questionType == .multipleChoice
}

enum QuestionType: String, Codable, CaseIterable {
    case multipleChoice
    case shortAnswer
    case photo

    var displayName: String { ... }
    var iconName: String { ... }
}
```

Add `toDictionary()` / `fromDictionary(_:)` on each — follow the pattern in `Extensions/GameModels+Dictionary.swift` (Firebase RTDB needs `[String: Any]`, no `Date` direct). Use `Date.toFirebaseTimestamp()` for `createdAt`/`updatedAt`.

### 2b. Update `Models/Game.swift`

`GameSettings` already has `var questionCategories: [String] = []` — replace it with the snapshot:

```swift
struct GameSettings: Codable {
    var hidingTime: Int
    var city: GameCity
    // ...
    var questionSetId: String?           // id of the source set on the host's account
    var questionSet: QuestionSet?        // full snapshot, used by all players in the game
    // remove or stop using `questionCategories`
}
```

Update `GameModels+Dictionary.swift` `GameSettings.fromDictionary` to decode `questionSet` (nil-tolerant, see "Backward compatibility" below).

### 2c. Update `Models/Lobby.swift`

```swift
struct Lobby: ... {
    // ...
    var questionSetId: String?
    var questionSetName: String?         // shown in the lobby UI to non-hosts
}
```

Update `Lobby.toDictionary` / `fromDictionary` to read/write these (default `nil` so old lobbies still parse).

### 2d. Keep `Models/QuestionCategory.swift` for now

The `QuestionCategory` enum is referenced widely (`QuestionData.questionCategory`, `QuestionAnswerView` switch, `QuestionTimerView`, `restrictedCategories`). Two options:

- **(Preferred) Remove it.** Replace `QuestionData.questionCategory` with `categoryId: String` and `questionType: QuestionType`. Restricted-category check uses `categoryId`. Answer UI switches on `questionType`. Cleaner.
- **(Fallback) Keep it as legacy.** Only used to decode old in-progress games. New games never write it.

This plan assumes the **preferred** option. See §10 for migration of in-progress games (none expected if we just deploy new builds; otherwise add a one-time legacy decoder).

---

## 3. Firebase Realtime Database changes

### 3a. New path

```
users/{uid}/questionSets/{questionSetId}/
  id, name, isDefault, createdAt, updatedAt
  categories/
    {categoryId}/
      id, name, iconName, drawCount, keepCount, timeLimitSeconds, orderIndex
      questions/
        {questionId}/
          id, text, questionType, choices/[...], orderIndex
```

Notes:
- Use UUIDs for ids. For the seeded Default set, use `"default"` as `questionSetId` and the existing enum rawValues as category ids ("matching", "measuring", "thermometer", "radar", "tentacles", "photos"). This makes the seed idempotent and migration-friendly.
- Store `orderIndex` on category and question to preserve user-defined ordering (RTDB doesn't preserve dictionary order). Sort by it on read.

### 3b. Snapshot on the game

```
games/{gameId}/info/settings/questionSetId: "<uuid>"
games/{gameId}/info/settings/questionSet: { ...full QuestionSet snapshot... }
```

Players read the snapshot directly from `games/{gameId}` (which they already have read access to). They never need to read another user's `users/.../questionSets` node.

### 3c. Snapshot on the lobby (lightweight)

```
lobbies/{code}/questionSetId: "<uuid>"
lobbies/{code}/questionSetName: "My Set"
```

Just the id+name; the full snapshot only happens at game-start time. Non-host players see the name in the lobby; the host can change it from `LobbySettingsView`.

### 3d. Security rules — instructions for you

The current rules in `Markdown/firebase-database-rules.json` are deliberately permissive for `lobbies` and `games`, and per-user under `users/{uid}`. The per-user rule already covers `questionSets`:

```json
"users": {
  "$uid": {
    ".read": "auth != null",
    ".write": "auth != null && auth.uid == $uid"
  }
}
```

This means a user can only read/write their own sets — exactly what we want. **No rule changes are required for the new path.** The full set is mirrored onto `games/{gameId}/...` at game start, so non-host players read it from there (already permitted by the games rule).

What you (Ryan) need to do manually in the Firebase console:
1. Open Firebase Console → Realtime Database → Rules tab.
2. Confirm the deployed rules match `Markdown/firebase-database-rules.json`. If yes, no edit needed.
3. (Optional) Add an index for ordering question sets by `updatedAt`:

```json
"users": {
  "$uid": {
    "questionSets": {
      ".indexOn": ["updatedAt"]
    }
  }
}
```

If you want me to apply the index for you, say so and I'll edit `firebase-database-rules.json` and you can paste it into the console.

### 3e. No cloud function changes required

`cloud_functions/functions/index.js` reads `games/{gameId}/info/settings.city` for stats, never `questionCategories`. Adding `questionSet` to settings doesn't break it. Stats and notifications continue to work.

---

## 4. Default-set seeding

Add to `UserManager`:

```swift
func seedDefaultQuestionSetIfNeeded(uid: String) async throws
```

Called from `AuthenticationManager.createUserProfileIfNeeded(...)` *and* idempotently on app launch for the signed-in user (cheap: a single `getData()` on `users/{uid}/questionSets/default`; create only if missing).

The seed builds a `QuestionSet` with id `"default"`, name `"Default"`, `isDefault: true`, and the six existing categories with their existing reward (`drawCount`/`keepCount`) and the existing question lists from `QuestionView.questionsForCategory(_:)`. Per-category mapping (time limit is per category, applies to every question in it):

| Category    | iconName                              | questionType    | choices                | timeLimitSeconds |
|-------------|---------------------------------------|-----------------|------------------------|------------------|
| matching    | questionmark.circle.fill              | multipleChoice  | ["Yes", "No"]          | 300              |
| measuring   | ruler.fill                            | multipleChoice  | ["Closer", "Further"]  | 300              |
| thermometer | thermometer.medium                    | multipleChoice  | ["Hotter", "Colder"]   | 300              |
| radar       | dot.radiowaves.left.and.right         | multipleChoice  | ["Yes", "No"]          | 300              |
| tentacles   | figure.walk                           | shortAnswer     | []                     | 300              |
| photos      | camera.fill                           | photo           | []                     | 600              |

Pre-fill question texts by running each existing prompt through `QuestionCategory.writeQuestion(arg:)` so the seeded text matches what users see today.

The default set is **fully locked**: cannot be renamed, edited (categories or questions), or deleted. The editor opens in read-only mode with a "Duplicate to edit" CTA. The list view hides Rename/Delete swipe actions for it (Duplicate is still allowed).

---

## 5. New UI screens

### 5a. Home screen entry point — `Views/MainView.swift`

Add a third secondary action button next to "Quick Match":

```swift
ActionButton(title: "Question Sets", subtitle: "Create your own questions",
             icon: "list.bullet.rectangle.fill", color: .purple, isPrimary: false) {
    showingQuestionSets = true
}
```

Add `@State private var showingQuestionSets = false` and a `.sheet(isPresented: $showingQuestionSets) { QuestionSetsListView() }`.

### 5b. `Views/QuestionSets/QuestionSetsListView.swift` (new)

Lists the user's sets (live from `users/{uid}/questionSets`):
- Each row: name, "Default" badge if applicable, question count, last edited.
- Swipe actions: Rename, Duplicate, Delete (Default cannot be deleted; can be duplicated).
- Tap a row → `QuestionSetEditorView`.
- Top-right "+" → create blank set (or "Duplicate Default" prompt).

### 5c. `Views/QuestionSets/QuestionSetEditorView.swift` (new)

The editor for a single set. Sections:
1. **Name** field.
2. **Categories** list (reorderable). Each row shows name, icon, reward, time limit, question count. Tap → `CategoryEditorView`. Swipe to delete. "+ Add Category" at the bottom.
3. Footer: "Save" (writes to RTDB), "Discard".

When `isDefault == true`: lock the form (`.disabled(true)` on every editable control), hide Save/Discard, and show a top banner "Default set — duplicate to edit" with a "Duplicate" button that calls the view model and dismisses into the new set's editor.

### 5d. `Views/QuestionSets/CategoryEditorView.swift` (new)

- Name (TextField).
- Icon picker (curated SF Symbol list, see below) — render as a `LazyVGrid` of buttons; tapping selects.
- Reward: two steppers — `drawCount` (1–10), `keepCount` (1–drawCount). Live preview "Draw 3, Keep 1".
- **Time limit (per category)**: slider + numeric field, in seconds (display as "Xm Ys"); range 30s–1800s. Default 300s. Applies to every question in this category.
- Questions list (reorderable). Swipe to delete. Tap → `QuestionEditorView`. "+ Add Question".

#### Curated SF Symbol list for the icon picker

Define this once in `Views/QuestionSets/CategoryIcon.swift` (new) as a static `[String]`. Includes icons that map well to the existing six categories plus a broad set so users can pick something fitting:

```swift
enum CategoryIcon {
    static let all: [String] = [
        // Defaults — used by the seeded "Default" set
        "questionmark.circle.fill",     // matching
        "ruler.fill",                   // measuring
        "thermometer.medium",           // thermometer
        "dot.radiowaves.left.and.right",// radar
        "figure.walk",                  // tentacles
        "camera.fill",                  // photos
        // Search / location / vision
        "magnifyingglass",
        "eye.fill",
        "binoculars.fill",
        "scope",
        "location.fill",
        "map.fill",
        "compass.drawing",
        "flag.fill",
        // Places
        "house.fill",
        "building.2.fill",
        "tree.fill",
        "leaf.fill",
        // People / motion
        "person.fill",
        "person.2.fill",
        "figure.run",
        // Transit
        "car.fill",
        "tram.fill",
        "bicycle",
        // Lifestyle / things
        "fork.knife",
        "cup.and.saucer.fill",
        "music.note",
        "book.fill",
        "paintbrush.fill",
        "graduationcap.fill",
        // Indicators / vibes
        "star.fill",
        "heart.fill",
        "bolt.fill",
        "flame.fill",
        "drop.fill",
        "snowflake",
        "sun.max.fill",
        "moon.fill",
        "clock.fill",
        "timer",
        "exclamationmark.triangle.fill",
    ]
}
```

The picker UI shows them in a 6-wide grid with the selected one highlighted. No free-text symbol entry — keeps things visually consistent and avoids broken-icon bugs from typos.

### 5e. `Views/QuestionSets/QuestionEditorView.swift` (new)

- Question text (multiline TextField).
- Question type picker (`Picker` with .segmented or .menu): Multiple Choice / Short Answer / Photo.
- If Multiple Choice: dynamic list of answer choices (TextField + delete button per row, "+ Add Choice", min 2). Validation: at least two non-empty choices.

Note: time limit lives on the **category**, not the question (see §5d). The editor shows the inherited limit as a footnote ("Hiders have Xm Ys to answer — set on the category").

All of the above are simple SwiftUI Forms following the visual style of `CreateLobbyView` / `LobbySettingsView`.

### 5f. ViewModel: `ViewModels/QuestionSetsViewModel.swift` (new)

Owns the live list of the current user's sets and CRUD operations:

```swift
@MainActor
final class QuestionSetsViewModel: ObservableObject {
    @Published private(set) var sets: [QuestionSet] = []
    func startListening(uid: String)
    func stopListening()
    func createSet(_ set: QuestionSet) async throws
    func updateSet(_ set: QuestionSet) async throws
    func deleteSet(id: String) async throws
    func renameSet(id: String, to: String) async throws
    func duplicateSet(_ set: QuestionSet, newName: String) async throws
}
```

Backed by RTDB observers on `users/{uid}/questionSets`.

---

## 6. Lobby integration

### 6a. `CreateLobbyView`

- Add `@State private var selectedQuestionSetId: String? = "default"`.
- Add a `Picker` in a new "Questions" section listing the user's sets (loaded once on appear via `QuestionSetsViewModel.fetchOnce` or a small async call to `UserManager`).
- Pass `questionSetId` and `questionSetName` to `gameManager.createLobby(...)`.

### 6b. `GameManager.createLobby(...)`

Add parameters `questionSetId: String?` and `questionSetName: String?`; persist them into the new `Lobby` fields.

### 6c. `LobbyView`

Show the selected set's name in `lobbySettingsSection` (read-only for non-hosts).

### 6d. `LobbySettingsView`

Same picker as create; on Save, `gameManager.updateLobbySettings(...)` writes the new id+name. Extend the existing function signature (back-compat: optional params default to `nil` to leave unchanged).

---

## 7. Game start integration — snapshot

In `GameManager.startGame()`:

1. Read the lobby's `questionSetId`. If `nil`, fall back to `"default"`.
2. Fetch the host's `users/{lobby.hostUID}/questionSets/{id}` (host is starting the game, so they have read access to their own).
3. Validate: at least one category, each category at least one question.
4. Inline the full set into `info.settings.questionSet` and write `info.settings.questionSetId`.
5. Continue with the existing game-write.

If validation fails (empty set), surface an error — don't start the game.

---

## 8. Gameplay integration

### 8a. `Views/Gameplay/Components/QuestionView.swift` — `GameQuestionView`

Replace:
- `QuestionCategory.allCases` → `currentGame.info.settings.questionSet?.categories ?? []` (sorted by `orderIndex`).
- `questionsForCategory(_:)` → look up by category id on the snapshot.
- `selectedCategory: QuestionCategory` → `selectedCategoryId: String`.
- Reward computation: take `drawCount`/`keepCount` from the chosen category (and double if `checkIfQuestionAskedBefore`). Build the same `"Draw X, Keep Y"` string so `HandView` parsing is unchanged.
- Restricted-category lookup uses the last question's `categoryId`.
- Sending writes `categoryId`, `questionType`, `choices`, and the **category's** `timeLimitSeconds` into `QuestionData`. The timer is per-category but inlined onto each `QuestionData` so the chat UI doesn't need to look back at the snapshot.

### 8b. `Models/Game.swift` — `QuestionData`

```swift
struct QuestionData: Codable, Equatable {
    let questionId: String
    let questionText: String
    var isAnswered: Bool = false
    var playerAnswer: String?
    var categoryId: String          // was questionCategory: QuestionCategory
    var categoryName: String        // for display in chat
    var questionType: QuestionType  // drives answer UI
    var choices: [String]           // for multipleChoice
    var timeLimitSeconds: Int       // drives timer; copied from the category at send time
    var reward: String              // unchanged "Draw X, Keep Y"
    var isRewarded: Bool = false
}
```

Update `GameMessage.toDictionary` / `fromDictionary` (in `Extensions/GameModels+Dictionary.swift`) accordingly.

### 8c. `QuestionAnswerView` (in `GameChatView.swift`)

Switch on `questionData.questionType`:
- `.multipleChoice` → render one button per `questionData.choices` entry. On tap → `submitAnswer(answer: choice)`.
- `.shortAnswer` → existing text field + Submit button.
- `.photo` → existing photo picker.

Drop the per-category hardcoded blocks (`yesNoButtons`, `closerFurtherButtons`, `hotterColderButtons`).

### 8d. `QuestionTimerView` (in `GameChatView.swift`)

Take `timeLimitSeconds: Int` instead of computing from category. Pass through from `QuestionData`.

### 8e. Restricted category lockout

In `GameQuestionView`:
```swift
private var restrictedCategoryIds: Set<String> {
    if let lastId = lastQuestionMessage?.questionData?.categoryId {
        return [lastId]
    }
    return []
}
```

---

## 9. Reward flow (unchanged)

The reward chat-message format is `"Draw X, Keep Y"` and `HandView`/`QuestionData.parseDrawAction(from:)` parse it. We keep that string as-is so `HandView` requires no changes — custom rewards just produce a different `X`/`Y`.

---

## 10. Backward compatibility

**For in-progress games at deploy time:** `QuestionData.fromDictionary` should fall back gracefully:
- If `categoryId` is missing but `questionCategory` exists, derive `categoryId = questionCategory.rawValue`, `categoryName = questionCategory.displayName`, `questionType` and `choices` from the table in §4, `timeLimitSeconds` from `category == .photos ? 600 : 300` (matches the per-category limits in §4).

This single decoder branch lets games started under the old build continue without crashing. Once the legacy games drain out, the branch can be deleted.

If you'd rather not deal with this at all (acceptable if you can finish all in-progress games before deploying), skip the legacy branch and crash-loud on parse failure during testing.

---

## 11. Concrete file change list

**New files:**
- `Models/QuestionSet.swift` — types from §2a.
- `Extensions/QuestionSet+Dictionary.swift` — RTDB conversion.
- `ViewModels/QuestionSetsViewModel.swift` — listing + CRUD.
- `Views/QuestionSets/QuestionSetsListView.swift`
- `Views/QuestionSets/QuestionSetEditorView.swift`
- `Views/QuestionSets/CategoryEditorView.swift`
- `Views/QuestionSets/CategoryIcon.swift` — curated SF Symbol list (§5d).
- `Views/QuestionSets/QuestionEditorView.swift`

**Edited files:**
- `Models/Game.swift` — `GameSettings` adds `questionSetId`/`questionSet`; `QuestionData` switches to `categoryId`/`questionType`/`choices`/`timeLimitSeconds`.
- `Models/Lobby.swift` — `Lobby` adds `questionSetId`/`questionSetName`; update `toDictionary`/`fromDictionary`.
- `Extensions/GameModels+Dictionary.swift` — encode/decode the new `QuestionData` fields and the `questionSet` snapshot in `GameSettings`; legacy fallback per §10.
- `Logic/UserManager.swift` — add `seedDefaultQuestionSetIfNeeded`, `getQuestionSets`, `getQuestionSet(id:)`, `saveQuestionSet`, `deleteQuestionSet`, `renameQuestionSet`.
- `Logic/AuthenticationManager.swift` — call `seedDefaultQuestionSetIfNeeded` in `createUserProfileIfNeeded`.
- `Logic/GameManager.swift` — `createLobby`/`updateLobbySettings` accept the new `questionSetId`+`questionSetName`; `startGame` fetches the host's set and writes the snapshot to `info.settings.questionSet`.
- `Views/MainView.swift` — add "Question Sets" entry point.
- `Views/Lobby/CreateLobbyView.swift` — picker.
- `Views/Lobby/LobbyView.swift` — show selected set name.
- `Views/Lobby/LobbySettingsView.swift` — picker.
- `Views/Gameplay/Components/QuestionView.swift` — read from snapshot, drop hardcoded categories.
- `Views/Gameplay/Components/GameChatView.swift` — `QuestionAnswerView` switches on `questionType`; `QuestionTimerView` uses `timeLimitSeconds`.
- `HideAndCSeek50App.swift` — call `seedDefaultQuestionSetIfNeeded` on launch for the signed-in user (idempotent).

**Optionally removed once stable:**
- `Models/QuestionCategory.swift` (after legacy fallback is no longer needed).

**Database/rules:**
- `Markdown/firebase-database-rules.json` — no required change. Optional: add `.indexOn` for `users/{uid}/questionSets` (see §3d).
- `Markdown/DATABASE_SCHEMA_JSON.md` and `DATABASE_SCHEMA_OVERVIEW.md` — document the new path.

---

## 12. Suggested build order

1. Models + dictionary conversions + `UserManager` CRUD + Default seeding (no UI yet).
2. `QuestionSetsViewModel` + `QuestionSetsListView` (list-only, read).
3. `QuestionSetEditorView` + `CategoryEditorView` + `QuestionEditorView` (full editing).
4. Wire entry point on `MainView`.
5. Lobby pickers + `GameManager.createLobby` / `updateLobbySettings` plumbing.
6. `GameManager.startGame` snapshot.
7. Refactor `GameQuestionView` to use the snapshot.
8. Refactor `QuestionAnswerView` and `QuestionTimerView`.
9. Legacy decoder fallback in `QuestionData` (if needed).
10. End-to-end test: create set → create lobby → start game → ask question → answer → reward.

After step 1 the app still runs (Default set seeded but unused). After step 6 the app runs with the snapshot but still uses the old enum-driven gameplay. Step 7–8 is the cutover.

---

## 13. Test checklist

- [ ] Fresh user signup → `Default` set appears under their account.
- [ ] Existing user on app open → `Default` set seeded if missing, untouched if present.
- [ ] Create / rename / delete custom set; sign out + back in → set persists.
- [ ] Cannot delete or edit `Default` (UI prevents it).
- [ ] Duplicate `Default` → new editable set with same content.
- [ ] Lobby host picks a custom set; non-host sees its name in the lobby.
- [ ] Game starts → snapshot written; non-host can ask/answer questions.
- [ ] Multiple choice question → correct buttons render for hider; answer flows through chat.
- [ ] Short answer → text field + Submit works.
- [ ] Photo question → time limit honored; photo upload flow works.
- [ ] Reward shows custom `Draw X, Keep Y`; HandView draws correct count.
- [ ] Asking the same question twice doubles reward (existing behavior preserved).
- [ ] Cannot ask the same category twice in a row (preserved, now by category id).
- [ ] Editing the source set during a live game does NOT change the running game (snapshot isolation).
- [ ] Cloud function `updateGameStatistics` still fires on game completion.

---

## 14. Decisions (resolved)

1. **Time limit scope** — *per-category.* Lives on `QuestionCategoryDef.timeLimitSeconds`; copied onto each `QuestionData` at send time so the chat UI doesn't have to re-look-up the snapshot. (See §2a, §3a, §5d, §8a, §8b.)
2. **Icon picker** — *curated SF Symbol list.* Defined once in `Views/QuestionSets/CategoryIcon.swift`; rendered as a 6-wide grid in `CategoryEditorView`. No free-text entry. (See §5d.)
3. **Default-set editability** — *fully locked.* Cannot rename, edit, or delete; can duplicate. Editor opens read-only with a "Duplicate to edit" CTA. (See §4, §5b, §5c.)
4. **Empty-set behavior at game start** — *block start with an error.* `GameManager.startGame()` validates the snapshot has at least one category and each category has at least one question; otherwise throws and surfaces the error in `LobbyView`. (See §7.)

### Still open
5. **Database rules index** — do you want me to add the `.indexOn updatedAt` to `firebase-database-rules.json` and have you paste it into the Firebase console? (No code change needed if you say no — the index just makes list queries slightly faster.)

Ready to start at step 1 of §12 once you answer #5 (or say "skip the index").
