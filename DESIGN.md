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

We implemented Firebase Cloud Messaging (FCM) for real-time chat notifications, ensuring players receive updates even when the app is in the background or closed.

#### Architecture Components

1. **[`NotificationManager.swift`](ios/HideAndCSeek50/Logic/NotificationManager.swift)** - Client-side notification handler
   - Requests user permission for notifications
   - Manages FCM token lifecycle
   - Subscribes/unsubscribes from game-specific topics
   - Handles foreground and background notification presentation

2. **Cloud Function** - Server-side notification sender in [`functions/index.js`](cloud_functions/functions/index.js)
   - `sendChatNotification`: Triggered when new messages are added to `/games/{gameId}/messages`
   - `onPlayerJoinGame`: Automatically subscribes players to game topic
   - `onPlayerLeaveGame`: Unsubscribes players when they leave

3. **APNs Integration** - Apple Push Notification service bridges FCM to iOS devices

#### Notification Flow

**When a message is sent:**

1. **Client sends message** → [`ChatViewModel.swift`](ios/HideAndCSeek50/ViewModels/ChatViewModel.swift) writes message to `/games/{gameId}/messages/{messageId}` in Firebase Realtime Database

2. **Cloud Function triggers** → `sendChatNotification` function detects the new message via Firebase database listener

3. **Recipients identified** → Function fetches all players in the game (hiders + seekers), excludes the sender

4. **FCM tokens retrieved** → Function queries `/users/{uid}/fcmToken` for each recipient

5. **Notifications sent** → FCM sends multicast message to all recipient tokens with:
   - **Title**: Sender's name
   - **Body**: Message preview (truncated to 100 chars)
   - **Data payload**: `gameId`, `messageId`, `senderUID`, `timestamp`

6. **iOS delivers** → APNs delivers notification to devices. Depending on app state:
   - **Foreground**: Banner shown with sound (`UNNotificationPresentationOptions`)
   - **Background/Closed**: System notification appears in notification center
   - **Tapped**: App opens and navigates to game chat via `NotificationCenter.default.post`

#### FCM Token Management

FCM tokens are device-specific identifiers that change when:
- App is reinstalled
- User logs out and back in
- Token expires (60 days)

**Token lifecycle:**
```swift
// 1. Request permission on app launch
await notificationManager.requestPermission()

// 2. Register for remote notifications (APNS)
UIApplication.shared.registerForRemoteNotifications()

// 3. FCM generates token after APNS token is available
Messaging.messaging().delegate = self

// 4. Token saved to user profile
func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    // Save to /users/{uid}/fcmToken
    userRef.child("fcmToken").setValue(token)
}
```

**Automatic cleanup:** A scheduled Cloud Function (`cleanupInvalidTokens`) runs daily to remove tokens older than 60 days.

### Design Decision: Cloud Functions vs client-side FCM Topics

**Option A (Chosen)**: Cloud Functions listen to database changes and send notifications server-side.

**Option B (Rejected)**: Clients send notifications directly via FCM SDK.

**Why Cloud Functions?**:
- **Functioanlity**: If a client sent a notification to a group via an FCM topic, it would send themselves a notification too!
- **Security**: Clients can't spoof sender identity or send notifications on behalf of others
- **Reliability**: Server-side ensures delivery even if sender's app crashes mid-send
- **Scalability**: Handles batch notifications efficiently (e.g., notify 10 seekers with one function call)
- **Centralized logic**: Message preview formatting and notification rules live in one place

**Trade-off**: Added deployment complexity. Functions must be deployed separately via Firebase CLI (see deployment notes in [`functions/index.js`](cloud_functions/functions/index.js)).

---

## Reconnection and Persistence

### Handling App Termination

When a player closes the app mid-game, we need to allow rejoining. Implementation:

#### 1. Active Game Tracking

When a game starts, we assign the user to a game in the Firebase database. If they leave the game or decline to rejoin the game, they will be unassigned from said game.

#### 2. Rejoin Detection

On app launch, [`MainView.swift`](ios/HideAndCSeek50/Views/MainView.swift) checks `/activeGames` for the current user's UID. If found in the database and game is still `inProgress`, it shows a "Rejoin Game" button.

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

When rejoining, [`GameView.swift`](ios/HideAndCSeek50/Views/Gameplay/GameView.swift) fetches full game state from `/games/{gameId}` and resumes location tracking. Previous messages, locations, and map tools load automatically from the Firebase database.

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

## Security Considerations

### Firebase Security Rules

Our security model (detailed in [`firebase-database-rules.json`](ios/HideAndCSeek50/Markdown/firebase-database-rules.json)):

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