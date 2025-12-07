# Hide and CSeek50: Design Document

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

## Table of Contents

### Infrastructure & Setup
- [Repository Organization](#repository-organization)
- [Security Considerations](#security-considerations)

### Pre-Game Systems
- [User Log-In Strategy](#user-log-in-strategy)
- [Lobby System](#lobby-system)

### Core Gameplay Features
- [Location Tracking Architecture](#location-tracking-architecture)
- [Map Integration](#map-integration)
- [Map Tools System](#map-tools-system)
- [Game State Management](#game-state-management)
- [Timer System](#timer-system)

### Communication Systems
- [Chat System Design](#chat-system-design)
- [Photo Sharing Implementation](#photo-sharing-implementation)
- [Notification System](#notification-system)

### Bonus Useful Feature!
- [Reconnection and Persistence](#reconnection-and-persistence)

---

## Repository Organization

### Directory Structure

The codebase follows a feature-based organization pattern, grouping related functionality together for maintainability:

```
HideAndCSeek50/
├── ios/                                    # iOS application code
│   ├── HideAndCSeek50/                     # Main app source code
│   │   │
│   │   ├── HideAndCSeek50App.swift         # App entry point, environment setup
│   │   │
│   │   ├── Logic/                          # Core business logic and managers
│   │   │   ├── AuthenticationManager.swift # Handles Apple/Google/Email sign-in
│   │   │   ├── DatabaseManager.swift       # Firebase Realtime Database operations
│   │   │   ├── LocationManager.swift       # GPS tracking and location updates
│   │   │   └── NotificationManager.swift   # FCM push notifications
│   │   │
│   │   ├── Models/                         # Data models and structures
│   │   │   ├── Game.swift                  # Game, GameInfo, GameTeams, Player models
│   │   │   │                               # GameMessage, MessageType enum
│   │   │   ├── Lobby.swift                 # Lobby and LobbyPlayer models
│   │   │   ├── Stats+History.swift         # Game statistics and history
│   │   │   ├── QuestionCategory.swift      # Question system data models
│   │   │   ├── CityRegions.swift           # City boundary and region data
│   │   │   ├── TransportType.swift         # Transportation mode definitions
│   │   │   ├── MapToolsData.swift          # Map tools collection model
│   │   │   │
│   │   │   ├── Map Tool Items/             # Codable structs for map overlays
│   │   │   │   ├── CircleOverlayItem.swift        # Circle drawing tool data
│   │   │   │   ├── PolygonOverlayItem.swift       # Polygon drawing tool data
│   │   │   │   ├── BisectorOverlayItem.swift      # Perpendicular bisector data
│   │   │   │   ├── DistanceOverlayItem.swift      # Distance measurement data
│   │   │   │   └── PointOverlayItem.swift         # Point marker data
│   │   │   │
│   │   │   └── Map Annotations/            # MapKit annotation classes
│   │   │       ├── PlayerAnnotation.swift         # Player location pins
│   │   │       ├── SearchResultAnnotation.swift   # POI search results
│   │   │       ├── BisectorPointAnnotation.swift  # Bisector reference points
│   │   │       ├── MeasurePointAnnotation.swift   # Distance measurement points
│   │   │       └── PolygonVertexAnnotation.swift  # Polygon corner markers
│   │   │
│   │   ├── ViewModels/                     # View models for complex views
│   │   │   ├── ChatViewModel.swift         # Chat message sending/receiving
│   │   │   ├── MapSearchViewModel.swift    # Map search and directions
│   │   │   └── MapToolsViewModel.swift     # Map tool state management
│   │   │
│   │   ├── Views/                          # SwiftUI views organized by feature
│   │   │   │
│   │   │   ├── MainView.swift              # Main navigation and game rejoining
│   │   │   │
│   │   │   ├── Components/                 # Reusable UI components
│   │   │   │   ├── ActionButton.swift      # Custom styled button
│   │   │   │   └── ImagePicker.swift       # UIKit camera/photo library bridge
│   │   │   │
│   │   │   ├── Login/                      # Authentication screens
│   │   │   │   ├── AuthenticationView.swift    # Sign-in options
│   │   │   │   ├── EmailSignInView.swift       # Email/password sign-in
│   │   │   │   └── ProfileView.swift           # User profile management
│   │   │   │
│   │   │   ├── Lobby/                      # Pre-game lobby system
│   │   │   │   ├── LobbyView.swift             # Lobby waiting room
│   │   │   │   ├── CreateLobbyView.swift       # Lobby creation form
│   │   │   │   ├── JoinLobbyView.swift         # Join via code
│   │   │   │   ├── QuickMatchView.swift        # Browse public lobbies
│   │   │   │   └── LobbySettingsView.swift     # Lobby configuration
│   │   │   │
│   │   │   └── Gameplay/                   # Active game screens
│   │   │       ├── GameView.swift              # Main game container
│   │   │       ├── GameMapView.swift           # MapKit integration (UIViewRepresentable)
│   │   │       ├── GameEndView.swift           # Post-game summary
│   │   │       ├── GameSettingsView.swift      # In-game settings
│   │   │       │
│   │   │       └── Components/             # Game-specific subviews
│   │   │           ├── GameChatView.swift          # Chat interface
│   │   │           ├── QuestionView.swift          # Question asking UI
│   │   │           ├── MapToolsSheet.swift         # Map tools bottom sheet
│   │   │           ├── SearchResultsSheet.swift    # Search results display
│   │   │           ├── DirectionsSheet.swift       # Route directions
│   │   │           ├── TransportSelectionSheet.swift # Transport mode picker
│   │   │           ├── TimerActionsView.swift      # Timer control buttons
│   │   │           │
│   │   │           └── Map Tools Subviews/ # Individual map tool interfaces
│   │   │               ├── RadiusToolView.swift            # Circle creation
│   │   │               ├── PolygonToolView.swift           # Polygon drawing
│   │   │               ├── PerpendicularBisectorToolView.swift  # Bisector tool
│   │   │               ├── MeasureToolView.swift           # Distance measurement
│   │   │               ├── PointToolView.swift             # Point markers
│   │   │               ├── MunicipalitiesView.swift        # Region shading
│   │   │               ├── TrainLinesView.swift            # Transit overlay
│   │   │               ├── Export+SyncSection.swift        # Tool export UI
│   │   │               └── SyncMapToolsSheet.swift         # Tool sync interface
│   │   │
│   │   ├── Extensions/                     # Swift type extensions
│   │   │   ├── GameModels+Dictionary.swift      # Codable Firebase conversion
│   │   │   ├── UIImage+Compression.swift        # Image compression utilities
│   │   │   ├── MKCoordinateRegion+Equality.swift # Map region comparison
│   │   │   └── MKMapItem+Address.swift          # Address formatting helpers
│   │   │
│   │   ├── Resources/                      # Assets and configuration
│   │   │   ├── GoogleService-Info.plist    # Firebase configuration
│   │   │   ├── Info.plist                  # App permissions and settings
│   │   │   ├── ma.json                     # MBTA transit data
│   │   │   └── Assets.xcassets/            # App icons and images
│   │   │       ├── AppIcon.appiconset/
│   │   │       ├── AccentColor.colorset/
│   │   │       └── HideAndSeekIcon.imageset/
│   │   │
│   │   └── Markdown/                       # Project documentation
│   │       ├── firebase-database-rules.json    # Firebase security rules
│   │       ├── storage.rules                   # Firebase Storage rules
│   │       ├── AUTHENTICATION.md               # Auth system docs
│   │       └── DATABASE_SCHEMA_JSON.md         # Database structure
│   │
│   └── HideAndCSeek50.xcodeproj            # Xcode project file
│
├── cloud_functions/                        # Firebase Cloud Functions (Node.js)
│   ├── functions/
│   │   ├── index.js                        # Notification cloud functions
│   │   │                                   # - sendChatNotification
│   │   │                                   # - onPlayerJoinGame
│   │   │                                   # - onPlayerLeaveGame
│   │   │                                   # - cleanupInvalidTokens
│   │   ├── package.json                    # Node dependencies
│   │   └── node_modules/                   # Installed dependencies
│   ├── firebase.json                       # Firebase project config
│   └── .firebaserc                         # Firebase project ID
│
├── README.md                               # Project overview and setup
└── DESIGN.md                               # This file - architecture documentation
```

---

## Security Considerations

### Firebase Realtime Database Security Rules

Our security model (defined in [`firebase-database-rules.json`](ios/HideAndCSeek50/Markdown/firebase-database-rules.json)) follows a **trust-based approach** where authentication is the primary gate. Here's an example of how we protect user data:

```json
"users": {
  "$uid": {
    ".read": "auth != null",
    ".write": "auth != null && auth.uid == $uid"
  }
}
```

**Line-by-line explanation:**
- `"users"` - Defines rules for the `/users` path in the database
- `"$uid"` - Wildcard variable capturing the user ID in the path (e.g., `/users/abc123`)
- `".read": "auth != null"` - Any authenticated user can read any user profile (needed for displaying player names in games)
- `".write": "auth != null && auth.uid == $uid"` - Users can only write to their own profile; the authenticated user's ID must match the path's user ID

This pattern is repeated for `/lobbies`, `/games`, and `/activeGames`. Game-specific rules (e.g., seekers can't see hider locations) are enforced at the application level rather than in database rules.

---

## User Log-In Strategy

### Multiple Sign In Methods

To increase functionality and ease of use for users, we added multiple sign in methods (Google, Apple ID, Email/Password, and Guest). Guest was added to allow for very quick testing without creating an account. We do not recommend this as it makes users show up as "Anonymous" in game.

#### Implementation Details

We use a singleton pattern for [`AuthenticationManager`](ios/HideAndCSeek50/Logic/AuthenticationManager.swift) to maintain global auth state:

```swift
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    @Published var currentUser: User?
}
```

This singleton is injected as `@EnvironmentObject` in [`HideAndCSeek50App.swift`](ios/HideAndCSeek50/HideAndCSeek50App.swift), making it accessible throughout the view hierarchy.

---

## Lobby System

### Unique Code Generation

Lobby codes are 6-character alphanumeric strings (e.g., "ABCD12"). Generated in [`DatabaseManager.swift`](ios/HideAndCSeek50/Logic/DatabaseManager.swift):

```swift
private func generateGameCode() -> String {
    let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<6).map { _ in chars.randomElement()! })
}
```

We check for duplicates of games by attempting to create at `/lobbies/{code}` with `setValue()`. Firebase throws an error if a game with the same code already exists, and we retry with a new code.

### Lobby Joining Via Quick Match/Code Join

If the lobby is marked as public in the game settings, when other users click the quick match button, it will query the database for public games and display those games. If it is not public, the game will not show up.

---

## Location Tracking Architecture

### LocationManager Implementation

[`LocationManager.swift`](ios/HideAndCSeek50/Logic/LocationManager.swift) is implemented with `CLLocationManager` for GPS access.

#### 1. Update Frequency Strategy

We update location after every 5 meters of movement using the Apple Location Manager libraries. We chose this distance because we felt it wouldn't cause too many location uploads and downloads saving battery and database interactions.

**Alternative Considered**: Time-based updates (every 10 seconds) would be simpler but waste battery when stationary and miss rapid movements.

#### 2. Always-On Tracking

We use `requestAlwaysAuthorization()` because having accurate locations for players is crucial in game. Not tracking when player's screens are off will signficantly affect gameplay.

#### 3. Publisher Pattern for Updates

`LocationManager` publishes location updates via Combine's `@Published` property:

```swift
@Published var location: CLLocation?
```

This allows [`GameView.swift`](ios/HideAndCSeek50/Views/Gameplay/GameView.swift) to reactively upload locations to Firebase whenever they change, without manual observation patterns.

---

## Map Integration

### Team Specific Map Views

The map shown is different for hiders and seekers and is implemented in [`GameMapView.swift`](ios/HideAndCSeek50/Views/Gameplay/GameMapView.swift):

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
    ForEach(seekerLocations) { location in
        RedMarker(location)
    }
    ForEach(hiderLocations) { location in
        RedMarker(location)
    }
}
else {
    // Can only see seekers
    ForEach(seekerLocations) { location in
        RedMarker(location)
    }
}
```

---

## Map Tools System

### Complex Overlay Management

The map tools (circles, bisectors, measurements, polygons) in [`MapToolsSheet.swift`](ios/HideAndCSeek50/Views/Gameplay/MapToolsSheet.swift) and [`MapToolsViewModel.swift`](ios/HideAndCSeek50/ViewModels/MapToolsViewModel.swift) required storage, map references & integration, and geographic math:

#### 1. Long Term Tool Storage

Each tool (circle, bisector, etc.) is stored as a Codable struct (e.g., [`CircleOverlayItem`](ios/HideAndCSeek50/Models/MapToolItems/CircleOverlayItem.swift) in the [`MapToolItems/`](ios/HideAndCSeek50/Models/MapToolItems) directory). We save these to Firebase at `/games/{gameId}/mapTools` when uploaded so teammates can import and see the same drawings.

#### 2. Crosshair Coordinate System

Many tools need a "reference point". We use a crosshair overlay in the map center:

```swift
@State private var crosshairCoordinate: CLLocationCoordinate2D
```

The crosshair follows the map center as users pan. This design allows users to see exactly where they are adding their map tool reference and avoids the slight inaccuracies with tapping on the map. This is slightly less convenient than tapping on the map but is more precise and clear.

#### 3. Polygon Creation with Variable Points

The implemented polygon tool takes a set of points (more than 3) and draws a polygon. We store them as `[CLLocationCoordinate2D]` in [`PolygonOverlayItem`](ios/HideAndCSeek50/Models/MapToolItems/PolygonOverlayItem.swift) and render with `MKPolygon`.

```swift
struct PolygonOverlayItem: Identifiable, Equatable, Codable {
    let id: UUID
    let vertices: [CLLocationCoordinate2D]
    let colorIndex: Int
    let shadeOutside: Bool
    let polygon: MKPolygon
}
```

---

## Game State Management

### Game States for Timers

Games progress through states: `preHiding → hiding → preSeeking → seeking → completed`. This is stored at `/games/{gameId}/info/state` and determines timer UI as the game occurs.

#### Game State Transitions

Only the **host** can transition states (enforced in Firebase rules). This prevents race conditions where multiple players try to start/end the game simultaneously.

---

## Timer System

### Client-Side Timer with Server Validation

Game timers (e.g., 30-minute hiding phase) are rendered client-side but sync against server timestamps. Implementation in [`GameView.swift`](ios/HideAndCSeek50/Views/Gameplay/GameView.swift):

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

## Chat System Design

### Multi-Format Messaging

Our chat system (primarily in [`ChatViewModel.swift`](ios/HideAndCSeek50/ViewModels/ChatViewModel.swift) and [`GameChatView.swift`](ios/HideAndCSeek50/Views/Gameplay/GameChatView.swift)) supports text, photos, locations, and system events. Key design choices:

#### 1. Unified Message Model

We use a single `GameMessage` model with a `type` enum to simplify processing (sending, receiving, storing in database):

```swift
enum MessageType: String, Codable {
    case text = "text"
    case photo = "photo"
    case question = "question"
    case event = "event"
    case location = "location"
}
```

#### 2. Photo Upload Strategy

Photos are uploaded to Firebase Storage at `/games/{gameId}/photos/{messageId}.jpg`, then the download URL is saved in the message document. This separation:
- **Keeps Database Light**: URLs are ~200 bytes vs multi-MB images
- **Enables CDN Caching**: Firebase Storage has global CDN for fast image delivery
- **Simplifies Security**: Storage rules (in [`storage.rules`](ios/HideAndCSeek50/Markdown/storage.rules)) validate uploads separately

**Compression**: We compress images to max 5MB before upload (in [`UIImage+Compression.swift`](ios/HideAndCSeek50/ViewModels/UIImage+Compression.swift)) to balance quality and upload time. Original implementation had no limit and caused slow uploads on cellular.

#### 3. Team-Based Channels

Messages have a `team` field (`"hiders"`, `"seekers"`, or `"all"`). We filter messages client-side rather than using separate Firebase paths because:
- **Flexibility**: Easy to add future features like "switch team visibility"
- **Simplicity**: One listener instead of three (one per channel)
- **Atomic Writes**: Cross-team messages don't require multi-path writes

**Trade-off**: We download all messages and filter locally, which wastes bandwidth. For future scale, we'd migrate to separate paths or Firestore's `where()` queries.

---

## Photo Sharing Implementation

### Bridging UIKit and SwiftUI

SwiftUI doesn't provide native camera access, so we created [`ImagePicker.swift`](ios/HideAndCSeek50/Views/Components/ImagePicker.swift) using `UIViewControllerRepresentable`:

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
2. **Orientation Fix**: Apply `fixOrientation()` (in [`UIImage+Compression.swift`](ios/HideAndCSeek50/ViewModels/UIImage+Compression.swift)) to handle EXIF rotation metadata
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

## Notification System

### Push Notification Architecture

We implemented Firebase Cloud Messaging (FCM) for real-time chat notifications.

#### Components

1. **[`NotificationManager.swift`](ios/HideAndCSeek50/Logic/NotificationManager.swift)** - Manages permissions, FCM tokens, and notification presentation
2. **Cloud Functions** in [`functions/index.js`](cloud_functions/functions/index.js) - `sendChatNotification`, `onPlayerJoinGame`, `onPlayerLeaveGame`
3. **APNs Integration** - Apple Push Notification service for iOS delivery

#### How It Works

When a message is sent, a Cloud Function triggers on `/games/{gameId}/messages/{messageId}`, fetches all player FCM tokens (except sender), and sends multicast notifications with the sender's name and message preview. Notifications appear as banners in foreground or system notifications when backgrounded. Tapping opens the game chat.

**FCM Token Management:** Device-specific tokens are saved to `/users/{uid}/fcmToken` and automatically cleaned up after 60 days by a scheduled Cloud Function.

**Why Cloud Functions?** Server-side sending prevents senders from notifying themselves, ensures security (can't spoof identity), guarantees delivery even if sender's app crashes, and centralizes notification logic.

---

## Reconnection and Persistence

### Handling App Termination

When a player closes the app mid-game, they can rejoin on relaunch using **UserDefaults** persistence with server-side validation.

#### Implementation

[`DatabaseManager.swift`](ios/HideAndCSeek50/Logic/DatabaseManager.swift) saves game data locally when entering a game: `gameId`, `lobbyCode`, `playerTeam`, and `timestamp`.

On app launch, [`MainView.swift`](ios/HideAndCSeek50/Views/MainView.swift) calls `databaseManager.rejoinGame()` which:
1. Loads saved game data from UserDefaults
2. Validates the game was saved within 24 hours (auto-expires old games)
3. Fetches the game from Firebase to verify it exists and isn't completed/cancelled
4. Confirms the player is still in the game's teams

If valid, a confirmation dialog shows the player's team and game state. Choosing "Rejoin" restores the full game state from Firebase (chat history, locations, map tools, timers). Choosing "No thanks" clears the local data.

**Why UserDefaults?** Faster than network requests, works offline for initial detection, and auto-clears when the app is deleted. Trade-off: rejoin data is device-specific.
