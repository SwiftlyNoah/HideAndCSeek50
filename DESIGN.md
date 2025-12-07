# DESIGN.md

## Hide and CSeek50: Design Document

### Project Overview

Our project seeks to unify the apps and tools needed to play [Jet Lag: The Game](https://store.nebula.tv/products/hideandseek?srsltid=AfmBOoqbGJjHeLowiRxnPiLQtFlGZslfS36k4aODukUM5LNVTO-UcwJW) into a single app including location sharing, question asking, game timers, map tools, game chat, and more!

---

## Architecture Decisions

### Primary UI's Designed with SwiftUI

We chose **SwiftUI** as our primary UI framework due to its ease of collaborations, recommendation as the newest UI language from Apple, and simplicity of syntax compared to other options.

---

## Firebase Backend

### Why Firebase (Realtime) Databases

It was a free, easy to use platform that some of our developers had experience using on past projects. It is faster and recommended by Google for games (our exact use case).

---

## Location Tracking Architecture

### LocationManager Implementation

`LocationManager.swift` is implemented as a singleton with `CLLocationManager` for GPS access. - help

#### 1. Update Frequency Strategy

We update location after every 5 meters of movement using the Apple Location Manager libraries. We chose this distance because we felt it wouldn't cause too many location uploads and downloads saving battery and database interactions.

**Alternative Considered**: Time-based updates (every 10 seconds) would be simpler but waste battery when stationary and miss rapid movements.

#### 2. Always-On Tracking

We use `requestAlwaysAuthorization()` because having accurate locations for players is crucial in game. Not tracking when player's screens are off will signficantly affect gameplay.

#### 3. Publisher Pattern for Updates - help

`LocationManager` publishes location updates via Combine's `@Published` property:

```swift
@Published var currentLocation: CLLocationCoordinate2D?
```

This allows `GameView.swift` to reactively upload locations to Firebase whenever they change, without manual observation patterns.

---

## Chat System Design

### Multi-Format Messaging

Our chat system (primarily in `ChatViewModel.swift` and `GameChatView.swift`) supports text, photos, and system events. Key design choices:

#### 1. Unified Message Model

We use a single `Message` model with a `type` enum to simplify processing (sending, recieving, storing in database):

```swift
enum MessageType: String, Codable {
    case text
    case photo
    case event
    case question
}
```

#### 2. Photo Upload Strategy - help

Photos are uploaded to Firebase Storage at `/games/{gameId}/photos/{messageId}.jpg`, then the download URL is saved in the message document. This separation:
- **Keeps Database Light**: URLs are ~200 bytes vs multi-MB images
- **Enables CDN Caching**: Firebase Storage has global CDN for fast image delivery
- **Simplifies Security**: Storage rules (in `storage.rules`) validate uploads separately

**Compression**: We compress images to max 5MB before upload (in `UIImage+Compression.swift`) to balance quality and upload time. Original implementation had no limit and caused slow uploads on cellular.

#### 3. Team-Based Channels - help

Messages have a `team` field (`"hiders"`, `"seekers"`, or `"all"`). We filter messages client-side rather than using separate Firebase paths because:
- **Flexibility**: Easy to add future features like "switch team visibility"
- **Simplicity**: One listener instead of three (one per channel)
- **Atomic Writes**: Cross-team messages don't require multi-path writes

**Trade-off**: We download all messages and filter locally, which wastes bandwidth. For future scale, we'd migrate to separate paths or Firestore's `where()` queries.

---

## User Log-In Strategy

### Multiple Sign In Methods

To increase functionality and ease of use for users, we added multiple sign in methods (Google, Apple ID, Email/Password, and Guest). Guest was added to allow for very quick testing without creating an account. We do not recommend this as it makes users show up as "Anonymous" in game.

#### Implementation Details - help

We use a singleton pattern for `AuthenticationManager` to maintain global auth state:

```swift
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    @Published var currentUser: User?
}
```

This singleton is injected as `@EnvironmentObject` in `HideAndCSeek50App.swift`, making it accessible throughout the view hierarchy without prop drilling.

**Alternative Considered**: Passing auth state explicitly through view parameters. Rejected because it creates verbose code and makes refactoring harder.

---

## Map Integration

### Team Specific Map Views

The map shown is different for hiders and seekers and is implemented in `GameMapView.swift`:

#### 1. Hider View
- Sees seeker locations in real time
- Can use map tools to draw geographic answers based on answered questions (circles, measurements, polygons)

#### 2. Seeker View
- Cannot see hider locations (obviously)
- Same map tools as hiders

This asymmetry is the core gameplay mechanic. Implementation-wise:

```swift
// Simplified logic in GameMapView.swift
if playerTeam == .hiders {
    // Show all opponent locations
    ForEach(seekerLocations) { location in RedMarker(location)}
    ForEach(hiderLocations) {location in BlueMarker(location)}
} else {
    // Can only see seekers
    ForEach(seekerLocations) {location in RedMarker(location)
}
```

---

## Map Tools System

### Complex Overlay Management

The map tools (circles, bisectors, measurements, polygons) in `MapToolsSheet.swift` and `MapToolsViewModel.swift` required storage, map references & integration, and geographic math:

#### 1. Long Term Tool Storage

Each tool (circle, bisector, etc.) is stored as a Codable struct (e.g., `CircleOverlayItem` in the `MapToolItems/` directory). We save these to Firebase at `/games/{gameId}/mapTools` when uploaded so teammates can import and see the same drawings.

#### 2. Crosshair Coordinate System

Many tools need a "reference point". We use a crosshair overlay in the map center:

```swift
@State private var crosshairCoordinate: CLLocationCoordinate2D
```

The crosshair follows the map center as users pan. This design allows users to see exactly where they are adding their map tool reference and avoids the slight inaccuracies with tapping on the map. This is slightly less convenient than tapping on the map but is more precise and clear.

#### 3. Polygon Creation with Variable Points - jack look at

The implemented polygon tool takes a set of points (more than 3) and draws a polygon. We store them as `[CLLocationCoordinate2D]` and render with `MKPolygon`. One challenge was managing point addition/removal:

```swift
struct PolygonToolState {
    var points: [CLLocationCoordinate2D] = []
    var isComplete: Bool = false
}
```

Users tap "Add Point" repeatedly, then "Complete Polygon". We debounce rapid taps to prevent accidental double-adds (using a 500ms cooldown).

---

## Game State Management

### Game States for Timers

Games progress through states: `preHiding → hiding → preSeeking → seeking → completed`. This is stored at `/games/{gameId}/info/state` and determines timer UI as the game occurs.

#### Game State Transitions - help

Only the **host** can transition states (enforced in Firebase rules). This prevents race conditions where multiple players try to start/end the game simultaneously.

```json
// In Firebase rules
"state": {
  ".write": "data.parent().child('hostUID').val() == auth.uid"
}
```

Client-side, we optimistically update local state but revert if Firebase rejects the write (handled in `DatabaseManager.swift`).

---

## Timer System - noah review

### Client-Side Timer with Server Validation

Game timers (e.g., 30-minute hiding phase) are rendered client-side but sync against server timestamps. Implementation in `GameView.swift`:

```swift
@State private var timeRemaining: TimeInterval = 0

// On game start, fetch server timestamp
let serverStartTime = gameInfo.startedAt
let duration = gameInfo.settings.hidingTime * 60

Timer.publish(every: 1, on: .main, in: .common)
    .autoconnect()
    .sink { _ in
        let elapsed = Date().timeIntervalSince(serverStartTime)
        timeRemaining = max(0, duration - elapsed)
    }
```

---

## Photo Sharing Implementation - help

### Bridging UIKit and SwiftUI

SwiftUI doesn't provide native camera access, so we created `ImagePicker.swift` using `UIViewControllerRepresentable`:

```swift
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate {
        // Handle image selection
    }
}
```

#### Image Processing Pipeline

1. **Capture**: User selects photo from camera/library
2. **Orientation Fix**: Apply `fixOrientation()` (in `UIImage+Compression.swift`) to handle EXIF rotation metadata
3. **Compression**: Compress to max 5MB JPEG using `compressedJPEGData()`
4. **Upload**: Send to Firebase Storage with metadata
5. **URL Retrieval**: Get download URL and save to message document

**Why Compression?**: Original photos (12MP+) can be 10-20MB. On cellular, uploads took 30+ seconds. Compression to 5MB reduced this to ~5 seconds with minimal quality loss.

#### Storage Security Rules

We set custom metadata during upload:

```swift
let metadata = StorageMetadata()
metadata.contentType = "image/jpeg"
metadata.customMetadata = ["uploadedBy": currentUser.uid]
```

Firebase Storage rules validate this:

```
allow write: if request.auth != null 
  && request.resource.metadata.uploadedBy == request.auth.uid;
```

This prevents users from uploading photos on behalf of others.

---

## Notification System - help

### Push Notification Architecture

We implemented Firebase Cloud Messaging for chat notifications. Key components:

1. **NotificationManager.swift**: Requests permission, stores FCM tokens
2. **Cloud Function**: `sendChatNotification` in `functions/index.js`
3. **APNs Integration**: Apple Push Notification service for iOS delivery

#### Design Decision: Cloud Functions vs Direct FCM

**Option A (Chosen)**: Cloud Functions listen to `/games/{gameId}/messages` and send notifications server-side.

**Option B (Rejected)**: Clients send notifications directly via FCM SDK.

**Why Cloud Functions?**:
- **Security**: Clients can't spoof sender identity
- **Reliability**: Server-side ensures delivery even if sender's app crashes
- **Scalability**: Handles batch notifications (e.g., notify 10 seekers) efficiently

**Trade-off**: Added complexity and deployment step (see `FIREBASE_FUNCTIONS_DEPLOYMENT.md`).

---

## Reconnection and Persistence

### Handling App Termination

When a player closes the app mid-game, we need to allow rejoining. Implementation:

#### 1. Active Game Tracking

When a game starts, we assign the user to a game in the Firebase database. If they leave the game or decline to rejoin the game, they will be unassigned from said game.

#### 2. Rejoin Detection

On app launch, `MainView.swift` checks `/activeGames` for the current user's UID. If found in the database and game is still `inProgress`, it shows a "Rejoin Game" button.

```swift
.onAppear {
    databaseManager.checkForActiveGame(uid: user.uid) { gameId in
        if let gameId = gameId {
            self.rejoinGameId = gameId
        }
    }
}
```

#### 3. State Restoration

When rejoining, `GameView.swift` fetches full game state from `/games/{gameId}` and resumes location tracking. Previous messages, locations, and map tools load automatically from the Firebase database.

---

## Lobby System

### Unique Code Generation

Lobby codes are 6-character alphanumeric strings (e.g., "ABCD12"). Generated in `DatabaseManager.swift`:

```swift
func generateLobbyCode() -> String {
    let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<6).map { _ in characters.randomElement()! })
}
```

We check for duplicates of games by attempting to create at `/lobbies/{code}` with `setValue()`. Firebase throws an error if a game with the same code already exists, and we retry with a new code.

### Lobby Joining Via Quick Match/Code Join - help, further explanation needed for lobby code matching w/ joining

If the lobby is marked as public in the game settings, when other users click the quick match button, it will query the database for public games and display those games. If it is not public, the game will not show up.

---

## Security Considerations - help, no idea about this

### Firebase Security Rules

Our security model (detailed in `firebase-database-rules.json`):

1. **User Data**: Users can only read/write their own `/users/{uid}`
2. **Game Access**: Only game participants can access `/games/{gameId}`
3. **Host Privileges**: Only the host can modify game settings
4. **Message Validation**: `senderUID` must match authenticated user

Example rule:

```json
"messages": {
  "$messageId": {
    ".write": "auth != null && newData.child('senderUID').val() == auth.uid"
  }
}
```

This prevents:
- Users reading other players' private data
- Message spoofing (claiming to be someone else)
- Non-participants interfering with games

**Trade-off**: Strict rules make development harder (must test authenticated scenarios). We maintain separate test/production Firebase projects to avoid breaking production data during development.

---

## Repository Organization

### Directory Structure

```
HideAndCSeek50/
├── Logic/              # Business logic, managers, utilities
│   ├── Extensions/     # Swift extensions for models and maps
│   ├── Markdown/       # Project documentation
│   └── Models/         # Data models and Codable structs (map tools, etc.)
├── Views/              # SwiftUI views, organized by feature
│   ├── Components/     # Reusable UI components
│   ├── Gameplay/       # Active game views (map, chat, etc.)
│   ├── Lobby/          # Pre-game lobby views
│   └── Login/          # Authentication views
├── ViewModels/         # View models for complex views
└── Resources/          # Assets, Info.plist, Firebase config
```

---
