# Architecture Documentation

## Overview

Hide and CSeek50 follows a layered MVVM (Model-View-ViewModel) architecture with reactive programming patterns using Swift Combine. The app is organized into feature-based modules with clear separation of concerns.

## Architecture Layers

```
┌─────────────────────────────────────────┐
│           Views (SwiftUI)               │
│  - User Interface Components            │
│  - Declarative UI                       │
└─────────────┬───────────────────────────┘
              │ Binding
┌─────────────▼───────────────────────────┐
│         ViewModels                      │
│  - State Management                     │
│  - @Published Properties                │
│  - Business Logic Coordination          │
└─────────────┬───────────────────────────┘
              │ Calls
┌─────────────▼───────────────────────────┐
│      Logic (Managers)                   │
│  - AuthenticationManager                │
│  - GameManager                          │
│  - LocationManager                      │
│  - NotificationManager                  │
│  - UserManager                          │
└─────────────┬───────────────────────────┘
              │ Uses
┌─────────────▼───────────────────────────┐
│          Models                         │
│  - Data Structures                      │
│  - Codable Conformance                  │
│  - Firebase Serialization               │
└─────────────┬───────────────────────────┘
              │ Persists to
┌─────────────▼───────────────────────────┐
│    Firebase Backend                     │
│  - Realtime Database                    │
│  - Authentication                       │
│  - Storage                              │
│  - Cloud Functions                      │
└─────────────────────────────────────────┘
```

## Directory Structure

### `/Logic` - Business Logic Layer

Contains singleton managers that handle core business logic:

#### AuthenticationManager
- **Responsibility**: User authentication and account management
- **Pattern**: Singleton with `@Published` auth state
- **Features**:
  - Apple Sign In with CryptoKit nonce generation
  - Google Sign In integration
  - Email/Password authentication
  - Anonymous (Guest) authentication
  - Account linking capabilities
- **Key APIs**:
  ```swift
  func signInWithApple() async throws
  func signInWithGoogle() async throws
  func signInWithEmail(email: String, password: String) async throws
  func signInAnonymously() async throws
  ```

#### GameManager
- **Responsibility**: Game lifecycle and operations (35 KB - largest file)
- **Pattern**: Singleton with Firebase listeners
- **Features**:
  - Game creation and joining
  - Real-time game state synchronization
  - Player management (add/remove/update)
  - Game state transitions
  - Message sending and receiving
  - Card deck management integration
- **Key APIs**:
  ```swift
  func createGame(lobby: Lobby) async throws -> String
  func joinGame(code: String, player: LobbyPlayer) async throws -> String
  func leaveGame(gameId: String, playerId: String) async throws
  func updateGameState(gameId: String, newState: GameState) async throws
  func startListeningToGame(gameId: String)
  ```

#### LocationManager
- **Responsibility**: GPS tracking and location updates
- **Pattern**: Singleton with Core Location integration
- **Features**:
  - Real-time location tracking with 5-meter threshold
  - Always-on location permission handling
  - Location update publishing via Combine
  - Automatic Firebase sync
- **Key APIs**:
  ```swift
  func requestLocationPermission()
  func startTracking()
  func stopTracking()
  // Published property: @Published var currentLocation: CLLocation?
  ```

#### NotificationManager
- **Responsibility**: Push notifications and FCM token management
- **Pattern**: Singleton with Firebase Cloud Messaging
- **Features**:
  - FCM token registration and storage
  - Game topic subscription/unsubscription
  - Notification permission handling
  - Deep linking to game views
- **Key APIs**:
  ```swift
  func requestNotificationPermission()
  func saveFCMTokenToUserProfile()
  func subscribeToGame(gameId: String)
  func unsubscribeFromGame(gameId: String)
  ```

#### UserManager
- **Responsibility**: User profile and preferences
- **Pattern**: Singleton with Firebase Database integration
- **Features**:
  - Profile creation and updates
  - Preference management
  - Stats tracking
  - Game history recording
- **Key APIs**:
  ```swift
  func createUserProfile(uid: String, displayName: String, email: String?)
  func updateDisplayName(uid: String, newName: String)
  func saveGameHistory(uid: String, entry: GameHistoryEntry)
  ```

### `/Models` - Data Layer

Contains all data structures and model definitions:

#### Core Game Models (Game.swift)
```swift
struct Game: Codable {
    let info: GameInfo
    var teams: GameTeams
    var messages: [String: GameMessage]
    var deck: DeckState?
}

struct GameInfo: Codable {
    let gameId: String
    let gameCode: String
    let name: String
    let hostUID: String
    var state: GameState
    let settings: GameSettings
    // ... timestamps, player counts
}

struct GameTeams: Codable {
    var hiders: [String: Player]
    var seekers: [String: Player]
}

struct Player: Codable {
    let uid: String
    let displayName: String
    var isReady: Bool
    var location: PlayerLocation?
}

struct GameMessage: Codable {
    let id: String
    let senderUID: String
    let senderName: String
    let content: String
    let type: MessageType
    let timestamp: TimeInterval
    let team: MessageTeam
    var questionData: QuestionData?
}
```

#### Map Tool Models
- **CircleOverlayItem**: Circle with center point and radius
- **PolygonOverlayItem**: Multi-point polygon overlay
- **BisectorOverlayItem**: Perpendicular bisector between two points
- **DistanceOverlayItem**: Distance measurement tool
- **PointOverlayItem**: Single point marker with optional label

#### Map Annotation Models
- **PlayerAnnotation**: Player position on map
- **SearchResultAnnotation**: Search result markers
- **BisectorPointAnnotation**: Bisector endpoint markers
- **PolygonVertexAnnotation**: Polygon vertex markers
- **MeasurePointAnnotation**: Distance measurement points

#### Supporting Models
- **Lobby**: Pre-game lobby state
- **Stats+History**: User statistics and game history
- **QuestionCategory**: Question types and definitions
- **CityRegions**: Geographic boundary definitions
- **TransportType**: Transportation mode enums

### `/ViewModels` - State Management Layer

ViewModels manage state and coordinate between Views and Logic:

#### ChatViewModel
- **Responsibility**: Chat state and message operations
- **State**: Message composition, photo selection
- **Operations**:
  - Send text messages
  - Upload and send photos (with compression to 5MB)
  - Handle photo orientation
  - Create system event messages

#### MapToolsViewModel
- **Responsibility**: Map tools state management
- **State**: Active tool selection, overlay items
- **Operations**:
  - Create/modify map overlays
  - Manage tool selection state
  - Export/import map tools to/from Firebase
  - Coordinate crosshair reference system

#### MapSearchViewModel
- **Responsibility**: Map search and directions
- **State**: Search results, selected location
- **Operations**:
  - Search for places/POIs
  - Get directions and routes
  - Calculate travel time
  - Handle search result selection

### `/Views` - Presentation Layer

SwiftUI views organized by feature:

#### Main Navigation
- **MainView**: App entry point with game rejoin logic
- **AuthenticationView**: Login/signup interface
- **ProfileView**: User profile management

#### Lobby Views
```
Lobby/
├── LobbyView.swift           # Main lobby container
├── CreateLobbyView.swift     # Game creation
├── JoinLobbyView.swift       # Join via code
├── QuickMatchView.swift      # Quick match public games
└── LobbySettingsView.swift   # Pre-game settings
```

#### Gameplay Views
```
Gameplay/
├── GameView.swift           # Main game container
├── GameMapView.swift        # MapKit integration
├── GameEndView.swift        # Post-game summary
├── GameSettingsView.swift   # In-game settings
└── Components/
    ├── GameChatView.swift
    ├── QuestionView.swift
    ├── MapToolsSheet.swift
    ├── SearchResultsSheet.swift
    ├── DirectionsSheet.swift
    ├── TransportSelectionSheet.swift
    ├── TimerActionsView.swift
    └── Map Tools Subviews/
        ├── RadiusToolView.swift
        ├── PolygonToolView.swift
        ├── PerpendicularBisectorToolView.swift
        ├── MeasureToolView.swift
        ├── PointToolView.swift
        ├── MunicipalitiesView.swift
        ├── TrainLinesView.swift
        └── SyncMapToolsSheet.swift
```

#### Reusable Components
- **ActionButton**: Styled button component
- **ImagePicker**: UIKit → SwiftUI bridge for camera/photo library
- **Card**: Card view container
- **HandView**: Card hand display for deck system

### `/Extensions` - Utility Layer

Type extensions and helper functions:

#### GameModels+Dictionary
```swift
extension Game {
    func toDictionary() -> [String: Any]
    static func fromDictionary(_ dict: [String: Any]) -> Game?
}
```
Enables Firebase serialization/deserialization.

#### UIImage+Compression
```swift
extension UIImage {
    func compressedJPEGData(maxSizeInMB: Double, compressionQuality: CGFloat) -> Data?
    func fixOrientation() -> UIImage
}
```
Handles photo compression and EXIF orientation.

#### Other Extensions
- **MKCoordinateRegion+Equality**: Map region comparison
- **MKMapItem+Address**: Address formatting
- **Date+FirebaseTimestamp**: Firebase timestamp conversion

## Design Patterns

### Singleton Pattern

Used for managers that maintain global state:

```swift
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()

    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false

    private init() {
        // Setup auth state listener
    }
}
```

**Benefits**:
- Single source of truth
- Consistent state across app
- Easy dependency injection via `@EnvironmentObject`

### Observer Pattern (via Combine)

Reactive data flow using `@Published` properties:

```swift
class GameManager: ObservableObject {
    @Published var currentGame: Game?
    @Published var messages: [GameMessage] = []

    func startListeningToGame(gameId: String) {
        ref.child("games/\(gameId)").observe(.value) { snapshot in
            if let game = Game.fromSnapshot(snapshot) {
                self.currentGame = game // Automatically notifies observers
            }
        }
    }
}
```

Views automatically update when published properties change.

### Repository Pattern (via Managers)

Managers abstract Firebase database operations:

```swift
// Instead of:
Database.database().reference().child("games").child(gameId).updateChildValues(...)

// Use:
await gameManager.updateGameState(gameId: gameId, newState: .inProgress)
```

**Benefits**:
- Centralized data access logic
- Easier testing and mocking
- Consistent error handling
- Business logic encapsulation

### Coordinator Pattern (for Navigation)

UIViewControllerRepresentable bridges UIKit components:

```swift
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var sourceType: UIImagePickerController.SourceType

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate {
        // Handle UIKit delegate callbacks
    }
}
```

## Data Flow

### Typical User Action Flow

```
User taps button in View
    ↓
View calls ViewModel method
    ↓
ViewModel calls Manager method
    ↓
Manager updates Firebase
    ↓
Firebase triggers listener
    ↓
Manager updates @Published property
    ↓
View automatically re-renders
```

### Example: Sending a Chat Message

```swift
// 1. User types message in GameChatView
GameChatView.sendMessage() {
    // 2. Calls ChatViewModel
    chatViewModel.sendMessage(content, gameId, user) {
        // 3. Calls GameManager
        gameManager.sendMessage(gameId, message) {
            // 4. Writes to Firebase
            Database.reference().child("games/\(gameId)/messages").childByAutoId().setValue(...)

            // 5. Firebase listener receives update
            // 6. Updates currentGame.messages (Published property)
            // 7. View automatically shows new message
        }
    }
}
```

## Firebase Integration

### Realtime Database Structure

```
hideandcseek50/
├── users/{userUID}/
├── games/{gameID}/
│   ├── info/
│   ├── teams/
│   ├── messages/
│   └── deck/
├── lobbies/{lobbyCode}/
└── activeGames/{gameID}/
```

See [DATABASE_SCHEMA_JSON.md](DATABASE_SCHEMA_JSON.md) for complete schema.

### Firebase Listeners

Managers set up real-time listeners for automatic sync:

```swift
func startListeningToGame(gameId: String) {
    let ref = Database.database().reference().child("games").child(gameId)

    gameListener = ref.observe(.value) { snapshot in
        guard let dict = snapshot.value as? [String: Any],
              let game = Game.fromDictionary(dict) else { return }

        DispatchQueue.main.async {
            self.currentGame = game
        }
    }
}
```

### Cloud Functions

Server-side logic in Node.js:

- **sendChatNotification**: Sends push notifications when messages are sent
- **onPlayerJoinGame**: Auto-subscribes players to game topics
- **onPlayerLeaveGame**: Auto-unsubscribes players
- **updateGameStatistics**: Calculates end-game stats and achievements
- **cleanupInvalidTokens**: Daily cleanup of expired FCM tokens

## Security Considerations

### Firebase Security Rules

- Users can only read/write their own profile data
- Game participants can read/write game data
- Host has additional privileges for game management
- Messages validated for required fields

See `firebase-database-rules.json` for complete rules.

### Data Validation

- Input validation before Firebase operations
- Error handling for all network operations
- Safe unwrapping of optional values
- Type checking with Codable conformance

### Privacy

- Location sharing based on user preferences
- Photo uploads with user-based access rules
- FCM tokens stored securely
- Anonymous authentication support for privacy

## Performance Optimizations

### Photo Compression

```swift
image.compressedJPEGData(maxSizeInMB: 5.0, compressionQuality: 0.8)
```

Reduces upload time and storage costs.

### Location Threshold

```swift
locationManager.distanceFilter = 5.0 // meters
```

Reduces unnecessary location updates and database writes.

### Efficient Queries

- Indexed fields for common queries
- Flat database structure to minimize nesting
- Selective listening (only subscribe to active game data)

### Local Caching

- UserDefaults for game rejoin data
- Memory caching of current game state
- Lazy loading of views and data

## Testing Strategy

### Unit Testing
- Test managers with mocked Firebase
- Test model serialization/deserialization
- Test utility functions and extensions

### Integration Testing
- Test view-viewmodel-manager flow
- Test Firebase operations with test database
- Test authentication flows

### UI Testing
- Test navigation flows
- Test user interactions
- Test error states

### Manual Testing Required
- GPS tracking (real device)
- Camera access (real device)
- Push notifications (real device)
- Multi-player scenarios (multiple devices)

## Future Architecture Considerations

### Potential Improvements

1. **Dependency Injection Container**
   - Replace singletons with proper DI
   - Easier testing and mocking

2. **Repository Layer**
   - Abstract Firebase behind repository protocol
   - Easier to switch backends

3. **Use Cases/Interactors**
   - Extract complex business logic from ViewModels
   - Better separation of concerns

4. **Modularization**
   - Split into Swift packages (Core, UI, Firebase, etc.)
   - Better build times and code organization

5. **Error Handling Protocol**
   - Standardize error types
   - Consistent error presentation

## Code Quality Standards

### Swift Style
- Follow Swift API Design Guidelines
- Use meaningful variable names
- Prefer `guard` for early returns
- Use `async/await` for asynchronous operations
- Avoid force unwrapping (`!`)

### Comments
- Document complex algorithms
- Explain non-obvious business logic
- Use `// MARK:` for section organization
- Keep comments up to date

### File Organization
- Group related code with `// MARK:`
- Keep files under 500 lines when possible
- One public type per file (generally)

## Development Workflow

1. **Feature Branch**: Create branch from `main`
2. **Implementation**: Follow MVVM pattern
3. **Testing**: Test on simulator and real device
4. **Code Review**: Review changes before merge
5. **Merge**: Merge to `main` after approval
6. **Deploy**: Update Firebase if needed

## Resources

- **SwiftUI**: [https://developer.apple.com/documentation/swiftui](https://developer.apple.com/documentation/swiftui)
- **Combine**: [https://developer.apple.com/documentation/combine](https://developer.apple.com/documentation/combine)
- **Firebase iOS**: [https://firebase.google.com/docs/ios/setup](https://firebase.google.com/docs/ios/setup)
- **Swift API Guidelines**: [https://www.swift.org/documentation/api-design-guidelines/](https://www.swift.org/documentation/api-design-guidelines/)
