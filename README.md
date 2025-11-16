# Hide and CSeek50

A digital hide and seek iOS app inspired by Jet Lag: The Game's Home Game format. Players compete in teams with real-world location tracking and map-based gameplay.

## Overview

Hide and CSeek50 transforms the classic game of hide and seek into a high-tech, location-based experience. Hider teams get strategic advantages while Seeker teams use deductive reasoning and geographical questions to narrow down search areas on a dynamic map interface.

## Core Features

### 🎮 Game Lobby System
- **Lobby Creation**: Generate unique game codes for easy joining
- **Team Assignment**: Automatic or manual assignment to Hider/Seeker teams
- **Player Management**: Real-time player list with ready status
- **Game Configuration**: Customizable settings for game duration, question difficulty, and special rules
- **Spectator Mode**: Allow non-playing users to observe games in progress

### 🗺️ Advanced Map Integration
- **Dual Map Views**: 
  - Hiders see full map with seeker locations in real-time
  - Seekers start with limited/blank map that reveals information progressively
- **Location Sharing**: Continuous GPS tracking with privacy controls
- **Dynamic Area Elimination**: Map zones automatically blackout based on question answers
- **Custom Boundaries**: Set game area limits and safe zones
- **Terrain Integration**: Leverage MapKit's detailed geographical features

### 💬 Question & Communication System
- **Pre-coded Question Bank**: Curated geographical and location-based questions
- **Photo Messaging**: Share images as part of questions and answers
- **Team Chat**: Separate communication channels for each team
- **Real-time Notifications**: Instant alerts for new questions, answers, and game events
- **Question Categories**: Different types of clues (distance, direction, landmarks, terrain)

### ⏱️ Timer & Scoring System
- **Game Countdown**: Configurable game duration with visual timer
- **Time Bonuses**: Reward quick responses and strategic play
- **Seeker Challenges**: Special timed challenges that provide map advantages
- **Score Tracking**: Points system based on time, accuracy, and teamwork
- **Game History**: Track wins, losses, and performance statistics

### 🔧 Game Management Features
- **Game States**: Waiting room, active play, paused, completed
- **Emergency Controls**: Pause, resume, or end games as needed
- **Reconnection Handling**: Seamless rejoin for disconnected players
- **Cheat Prevention**: Location validation and anti-spoofing measures
- **Privacy Controls**: Granular location sharing permissions

## Technical Architecture

### Backend Infrastructure
- **Firebase Realtime Database**: Live data synchronization across all clients
- **Cloud Functions**: Server-side game logic and validation
- **Authentication**: Secure user accounts and game access
- **Push Notifications**: Cross-platform game event alerts

### iOS Implementation
- **SwiftUI Interface**: Modern, responsive user interface design
- **MapKit Integration**: Native Apple maps with custom annotations and overlays
- **Core Location**: Precise GPS tracking with battery optimization
- **Combine Framework**: Reactive data flow for real-time updates
- **Local Storage**: Offline capability and game caching

### Key Frameworks & APIs
- **MapKit**: Core mapping functionality
- **Core Location**: GPS and location services
- **Firebase SDK**: Backend services integration
- **UserNotifications**: Push notification handling
- **SwiftUI**: User interface development
- **Combine**: Reactive programming patterns

## Game Flow

### 1. Pre-Game Setup
1. Host creates lobby with game code
2. Players join using code and select teams
3. Configure game settings (duration, boundaries, rules)
4. All players confirm ready status
5. Location permissions granted and verified

### 2. Active Gameplay
1. Game timer starts, locations begin tracking
2. Hiders see seeker positions, plan movements
3. Seekers receive initial limited map view
4. Question system activates with first clues
5. Teams communicate and strategize
6. Map dynamically updates based on answers
7. Special challenges and bonuses trigger

### 3. Game Completion
1. Timer expires or seekers find all hiders
2. Final scores calculated
3. Game summary and statistics displayed
4. Option to play again or create new lobby

## Development Team & Responsibilities

### Noah Brauner
- **Backend Infrastructure**: Firebase setup, database design, real-time synchronization
- **Authentication System**: User accounts, security, and permissions
- **iOS Development Lead**: Project coordination and app store deployment

### Jack Ploof  
- **Non-Map Features**: Messaging system, lobby management, game timers
- **User Interface**: SwiftUI views, navigation, and user experience design
- **Communication Systems**: Chat functionality and notification handling

### Ryan Eto
- **Map Integration**: Location services, MapKit implementation, GPS tracking
- **Question System**: Geographical questions, answer validation, map updates
- **Game Logic**: Area elimination algorithms and scoring systems

## Minimum Viable Product (Good Outcome)
- ✅ Real-time location sharing between players  
- ✅ Basic timer functionality for game duration
- ✅ Simple lobby creation and team assignment
- ✅ Core map display with different views for each team

## Enhanced Features (Better Outcome)
- ✅ Complete messaging framework with photo sharing
- ✅ Question and answer system with real-time updates  
- ✅ Team communication channels
- ✅ Basic game management and scoring

## Advanced Features (Best Outcome)
- ✅ Intelligent area elimination based on geographical answers
- ✅ Advanced map editing and custom boundaries
- ✅ Seeker challenges and time bonuses
- ✅ Comprehensive game statistics and history
- ✅ Anti-cheat measures and location validation

## Installation & Setup

### Prerequisites
- iOS 15.0 or later
- Xcode 13.0 or later for development
- Apple Developer Account for distribution
- Firebase project configuration

### Development Setup
1. Clone the repository
2. Install Firebase SDK via Swift Package Manager
3. Configure Firebase project and add `GoogleService-Info.plist`
4. Set up location permissions in `Info.plist`
5. Configure Apple Developer signing
6. Build and run on device (location services require physical device)

### Firebase Configuration
1. Create new Firebase project
2. Enable Realtime Database with appropriate security rules
3. Set up Authentication (Anonymous or Sign-in providers)
4. Configure Cloud Functions for server-side validation
5. Enable Push Notifications via Firebase Cloud Messaging

## Privacy & Permissions

### Required Permissions
- **Location Services**: Always or When In Use for GPS tracking
- **Camera**: Photo capture for question responses
- **Notifications**: Game event alerts and updates
- **Network**: Firebase communication and real-time updates

### Privacy Considerations
- Location data only shared during active games
- Automatic data deletion after game completion
- Granular privacy controls for each player
- No permanent location history storage

## Future Enhancements

### Potential Features
- **AR Integration**: Augmented reality clues and waypoints
- **Apple Watch Support**: Quick game status and notifications
- **Multiple Game Modes**: Variants of hide and seek gameplay
- **Tournament System**: Organized competitions and leaderboards  
- **Custom Question Creation**: User-generated content and challenges
- **Offline Mode**: Limited functionality without internet connection

### Platform Expansion
- **iPad Support**: Enhanced map interface for larger screens
- **Mac Catalyst**: Desktop version for game management
- **Apple TV**: Spectator mode for watching games
- **Cross-Platform**: Android compatibility considerations

## Contributing

This project is part of Harvard CS50's final project. Development is currently limited to the core team members listed above.

---

**Note**: This app requires location permissions and is designed for outdoor gameplay in appropriate areas. Always follow local laws and safety guidelines when playing location-based games.
