# Hide and CSeek50

A real-time, location-based multiplayer hide-and-seek iOS game inspired by *Jet Lag: The Game*. This app consolidates multiple tools - location tracking, messaging, map drawing, game timers, and question systems - into a unified gaming experience.

## Overview

Hide and CSeek50 transforms the classic game of hide-and-seek into a digital, city-wide adventure. Players split into teams (Hiders and Seekers), use real-time GPS tracking, strategic map tools, and a unique question system to outsmart their opponents.

## Key Features

### Core Gameplay
- **Real-Time Location Tracking**: GPS-based player tracking with 5-meter movement threshold
- **Team-Based Play**: Split into Hiders and Seekers with distinct objectives
- **Timed Phases**: Separate hiding and seeking phases with customizable durations
- **Question System**: 6 question categories for seekers to narrow down hider locations
- **Card Deck Rewards**: Answer questions to earn strategic advantage cards

### Map Tools
- **Circle Overlays**: Draw circles with custom radius and shading
- **Polygon Creation**: Create arbitrary polygons with multiple points
- **Perpendicular Bisectors**: Visualize geometric relationships
- **Distance Measurement**: Measure distances between two points
- **Point Markers**: Place custom markers with notes
- **Transit Overlays**: View MBTA lines (Boston) and transit routes
- **Municipality Shading**: Visualize city boundaries

### Communication
- **Team Chat**: Text messaging with team-specific channels
- **Photo Sharing**: Send photos from camera or photo library
- **Location Sharing**: Share specific locations as map pins
- **System Events**: Automatic game state notifications

### Game Management
- **Lobby System**: Create or join games using 6-character codes
- **Quick Match**: Join public games instantly
- **Flexible Settings**: Customize hiding time, city boundaries, and more
- **App Rejoin**: Automatically recover if app is closed mid-game

### Statistics & Achievements
- **Performance Tracking**: Time-based stats for both roles
- **Achievement System**: Unlock badges for milestones
- **Game History**: Complete record of all games played

## Technology Stack

### iOS Frontend
- **Swift 5.9+** with SwiftUI for modern declarative UI
- **MapKit** for native mapping and location visualization
- **Core Location** for GPS tracking
- **Combine** for reactive programming
- **AVFoundation** for camera and photo access

### Firebase Backend
- **Realtime Database** for real-time game data synchronization
- **Authentication** supporting Apple, Google, Email, and Anonymous sign-in
- **Storage** for photo uploads with CDN caching
- **Cloud Messaging** for push notifications via APNs
- **Cloud Functions** for server-side logic (notifications, stats)

## Project Structure

```
HideAndCSeek50/
├── ios/HideAndCSeek50/
│   ├── Logic/              # Business logic managers
│   ├── Models/             # Data structures and models
│   ├── ViewModels/         # State management
│   ├── Views/              # SwiftUI views
│   ├── Extensions/         # Type extensions
│   └── Markdown/           # Documentation (you are here)
├── cloud_functions/
│   └── functions/          # Firebase Cloud Functions
└── README.md
```

## Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Technical architecture and code organization
- **[GAME_MECHANICS.md](GAME_MECHANICS.md)** - Detailed game rules and features
- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Development environment setup
- **[DATABASE_SCHEMA_OVERVIEW.md](DATABASE_SCHEMA_OVERVIEW.md)** - Database structure overview
- **[DATABASE_SCHEMA_JSON.md](DATABASE_SCHEMA_JSON.md)** - Complete database schema reference
- **[STATS_STRUCTURE_GUIDE.md](STATS_STRUCTURE_GUIDE.md)** - Statistics and achievements system
- **[EVENT_MESSAGE_EXAMPLES.md](EVENT_MESSAGE_EXAMPLES.md)** - Event messaging reference

## Quick Start

### Prerequisites
- macOS with Xcode 14+
- iOS 15.0+ device or simulator
- Firebase account
- Apple Developer account (for device testing)

### Basic Setup
1. Clone the repository
2. Open `ios/HideAndCSeek50.xcodeproj` in Xcode
3. Configure Firebase (see [SETUP_GUIDE.md](SETUP_GUIDE.md))
4. Build and run on your device

For detailed setup instructions, see [SETUP_GUIDE.md](SETUP_GUIDE.md).

## Development

### Architecture Pattern
This app follows **MVVM (Model-View-ViewModel)** architecture with reactive programming using Combine:
- **Models**: Data structures conforming to `Codable` for Firebase
- **ViewModels**: State management with `@Published` properties
- **Views**: SwiftUI views binding to ViewModels
- **Logic**: Singleton managers for business logic

### Key Managers
- **AuthenticationManager**: Handles all authentication methods
- **GameManager**: Manages game lifecycle and operations
- **LocationManager**: GPS tracking and location updates
- **NotificationManager**: Push notification handling
- **UserManager**: User profile and preferences

### Code Conventions
- Feature-based file organization
- Reactive data flow with Combine publishers
- Comprehensive error handling
- Extension-based code organization
- Firebase Codable conversion patterns

## Contributing

1. Follow the existing code style and conventions
2. Use meaningful commit messages
3. Test on real devices for location and camera features
4. Update documentation for significant changes
5. Follow MVVM architecture patterns

## Testing

### On Simulator (Limited)
- UI and navigation flows
- Chat messaging (text only)
- Map tools and drawing
- Photo library access

### On Real Device (Full Experience)
- GPS location tracking
- Camera access
- Push notifications
- Complete game flow
- Multi-player testing

## Deployment

### TestFlight Beta
1. Archive the app in Xcode
2. Upload to App Store Connect
3. Configure TestFlight settings
4. Invite testers

### Production
1. Ensure all features tested
2. Update Firebase to production mode
3. Configure production database rules
4. Submit for App Store review

## Support & Resources

- **Firebase Console**: [https://console.firebase.google.com](https://console.firebase.google.com)
- **Apple Developer**: [https://developer.apple.com](https://developer.apple.com)
- **Firebase Documentation**: [https://firebase.google.com/docs](https://firebase.google.com/docs)
- **SwiftUI Documentation**: [https://developer.apple.com/documentation/swiftui](https://developer.apple.com/documentation/swiftui)

## License

[Specify your license here]

## Version History

- **Current**: Major refactor with enhanced map tools and card deck system
- See git commit history for detailed changelog

---

**Note**: This is an active development project. Features and documentation are subject to change.
