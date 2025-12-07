# Hide and CSeek50

A digital hide and seek iOS app inspired by Jet Lag: The Game's Home Game format. Players compete in teams with real-world location tracking and map-based gameplay. The hiders choose some geographic location to hide and seekers find them by asking a series of geographic and photo based questions.

## Our Project Overview

Hide and CSeek50 is a tool to condense the various apps/tools needed to properly play this game. Instead of using some location sharing app, a messaging app, and a map to draw on, everything is packaged into our single interface.

---

## 📋 Table of Contents

1. [Installation & Setup](#installation--setup)
2. [How to Run the App](#how-to-run-the-app)
3. [Testing the App](#testing-the-app)
4. [Core Features](#core-features)
5. [Technical Architecture](#technical-architecture)

---

## Installation & Setup

### Prerequisites

**Required:**
- macOS (for Xcode)
- Xcode 15.0 or later
- iOS device running iOS 26.0 or later (simulator has limited functionality)
- Apple ID Developer Account (necessary for notifications and a successful build)

**Already Configured:**
- Google Firebase project (hideandcseek50)
- All necessary API keys and configuration files
- Push notification certificates

### Step-by-Step Installation

1. **Open the Project**
   - Pull the Github repository onto your compatible mac
   - Open the 'HideAndCSeek50' folder and run the xed . command

2. **Wait for Dependencies to Load**
   - Xcode will automatically download Swift Package Manager dependencies
   - This includes Firebase SDK, GoogleSignIn, and BottomSheet
   - Wait for "Package Resolution" to complete (bottom-right of Xcode window)

3. **Select Your Development Team**
   - In Xcode, select the project in the navigator
   - Go to "Signing & Capabilities" tab
   - Under "Team", select your Apple Developer Team (via Apple ID)
   - Xcode will automatically handle provisioning profiles

4. **Connect Your iOS Device**
   - Plug in your iPhone/iPad via USB
   - Trust the computer on your device if prompted
   - In Xcode's toolbar, select your device from the scheme dropdown
   - Try to load the app onto your device
   - Enable developer mode if prompted

5. **Build and Run**
   - Press `Cmd + R` or click the Play button
   - First build may take 2-3 minutes
   - If prompted, trust the developer on your device (Settings → General → VPN & Device Management)

### Important Notes

- **Simulator Limitations**: The simulator cannot access GPS or camera. You must test on a physical device.
- **Location Permissions**: The app will request location permissions on first launch. You must manually allow "Always" location sharing in settings for full functionality.
- **Notification Permissions**: The app will request notification permissions on first launch. You must allow them for full functionality.
- **Firebase Configuration**: The [`GoogleService-Info.plist`](HideAndCSeek50/Resources/GoogleService-Info.plist) file is already included and configured for the production Firebase project.

---

## How to Run the App

### First Launch

1. **Sign In**
   - You have four options:
     - **Continue as Guest** (fastest, no account needed)
     - **Sign in with Apple** (requires Apple ID)
     - **Sign in with Google** (requires Google account)
     - **Sign in with Email** (create new account or use existing)

2. **Create or Join a Game**
   - **To create a game:**
     - Tap "Create Lobby"
     - Enter a game name
     - Select city (Boston or New York)
     - Set hiding time (default: 30 minutes)
     - Tap "Create"
     - Share the 6-digit code with other players
   
   - **To join a game:**
     - Tap "Join Lobby"
     - Enter the 6-digit code
     - Tap "Join"
    
   - At least two players or simulators must join the game in order to start the game and use game features

## Testing the App

#### 1. Lobby System
- Create lobby with custom name and settings
- Join lobby using 6-digit code
- Join lobby using quick-join option
- Switch between Hiders and Seekers teams
- Apply ready status
- Edit game settings (hiding time, city, number of hiders/seekers) w/ the settings button
- Pame start when all players ready

#### 2. Location Tracking
- Blue dot shows your current location on map
- Location updates as you move (requires ~5 meters of movement)
- Other players' locations visible (hiders see seekers, seekers can't see hiders)

#### 3. Map Features
- Map centers on your location
- Zoom in/out with pinch gestures
- Pan around the map
- Search for points of interest in app
- Different map views for hiders vs seekers
- Transit lines overlay is toggleable
- (Boston Only) Color in/turn off certain municipalities
- Draw a circle on the map with custom shading color, radius, center, and masking
- Measure distances from one point to another
- Draw in a perpendicular bisector between two arbitrary points w/ one side shaded
- Create a custom polygon with an arbitrary number of points, custom shading and masking
- Add points to the map
- Automatically use points of interests as circle centers, perpendicular bisector points, measuring anchors, or custom polygons
- Export to database/sync from database all of these drawn tools to a database so tools save if you close out of the app or if your teammates want to see what you've drawn

#### 4. Chat System
- Send text messages
- Send photos (tap camera icon → Camera or Photo Library)
- Send current location (with automatic pin addition option for all chat members)
- View message history
- System event messages (player joined, game started, etc.)

#### 5. Question Asking/Answering
- Automatically display question categories within a question asking UI
- Automatically send chosen questions in chat to the other team w/ preset question answers/formats
- A timer will automatically start indicating the amount of time hiders have left to answer a question
- Integrated photo sending for photo questions
- Automatic question category lock outs for the most recently asked question category (cannot ask two questions from same category in a row)

#### 6. Game Timers
- Live running timers for hiding and seeking displayed at the top of the UI
- Buttons for pausing, skipping, and ending timers

#### 7. Notifications
- Database sent notifications for chat messages and questions

#### 8. Miscellaneous
- Game rejoining prompts when the app is force quit

### Known Limitations

1. **Simulator**: Camera and GPS don't work. Must use physical device.
2. **Network Required**: App requires internet connection for real-time features.
3. **GPS Accuracy**: Indoor location may be inaccurate or unavailable.

## Technical Architecture

### Backend Infrastructure

**Firebase Services:**
- **Realtime Database**: Stores game data, player locations, chat messages
  - Structure: `/users`, `/games`, `/lobbies`, `/activeGames`
  - Real-time listeners for instant updates
  - See [`DATABASE_SCHEMA_JSON.md`](HideAndCSeek50/Markdown/DATABASE_SCHEMA_JSON.md) for full schema

- **Authentication**: Manages user accounts and sessions
  - Supports Apple, Google, Email, and Anonymous sign-in
  - See [`AUTHENTICATION.md`](HideAndCSeek50/Markdown/AUTHENTICATION.md)

- **Storage**: Hosts uploaded photos
  - Path: `/games/{gameId}/photos/{messageId}.jpg`
  - Security rules validate authenticated uploads
  - See [`storage.rules`](HideAndCSeek50/Markdown/storage.rules)

- **Cloud Functions**: Server-side notifications (optional, deployed separately)
  - Sends push notifications for chat messages
  - See [`FIREBASE_FUNCTIONS_DEPLOYMENT.md`](HideAndCSeek50/Markdown/FIREBASE_FUNCTIONS_DEPLOYMENT.md)

### iOS Implementation

**Key Classes:**

- [`AuthenticationManager.swift`](HideAndCSeek50/Logic/AuthenticationManager.swift): Handles user sign-in/sign-out
- [`DatabaseManager.swift`](HideAndCSeek50/Logic/DatabaseManager.swift): Firebase database operations
- [`LocationManager.swift`](HideAndCSeek50/Logic/LocationManager.swift): GPS tracking and location updates
- [`NotificationManager.swift`](HideAndCSeek50/Logic/NotificationManager.swift): Push notification handling

**Key Views:**

- [`MainView.swift`](HideAndCSeek50/Views/MainView.swift): Home screen and navigation
- [`CreateLobbyView.swift`](HideAndCSeek50/Views/Lobby/CreateLobbyView.swift): Lobby creation interface
- [`LobbyView.swift`](HideAndCSeek50/Views/Lobby/LobbyView.swift): Waiting room before game starts
- [`GameView.swift`](HideAndCSeek50/Views/Gameplay/GameView.swift): Main gameplay screen
- [`GameMapView.swift`](HideAndCSeek50/Views/Gameplay/GameMapView.swift): Map display and location tracking
- [`ChatView.swift`](HideAndCSeek50/Views/Gameplay/ChatView.swift): Team communication

**Frameworks Used:**

- **SwiftUI**: Modern declarative UI framework
- **MapKit**: Apple's native mapping framework
- **Core Location**: GPS and location services
- **Firebase iOS SDK**: Backend services integration
- **Combine**: Reactive programming for real-time updates

### Data Flow

1. **Location Updates**:
   - [`LocationManager`](HideAndCSeek50/Logic/LocationManager.swift) receives GPS updates from iOS
   - [`GameView`](HideAndCSeek50/Views/Gameplay/GameView.swift) listens for location changes
   - Location uploaded to Firebase: `/games/{gameId}/teams/{team}/{playerUID}/location`
   - Other players' apps receive update via Firebase listeners
   - [`GameMapView`](HideAndCSeek50/Views/Gameplay/GameMapView.swift) displays updated positions

2. **Chat Messages**:
   - User types message in [`ChatView`](HideAndCSeek50/Views/Gameplay/ChatView.swift)
   - Message uploaded to: `/games/{gameId}/messages/{messageId}`
   - All players receive instant update via Firebase listener
   - Photos uploaded to Firebase Storage, URL saved in message

3. **Game State**:
   - Host creates game → Data saved to `/lobbies/{code}` and `/games/{gameId}`
   - Players join → Added to `/games/{gameId}/teams/{team}/{playerUID}`
   - Ready status tracked → When all ready, game state changes to "inProgress"
   - [`GameView`](HideAndCSeek50/Views/Gameplay/GameView.swift) observes state and updates UI

---
