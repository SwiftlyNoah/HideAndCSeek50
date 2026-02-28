# Firebase Realtime Database Schema for Hide and CSeek50

This document outlines the comprehensive database architecture for the Hide and CSeek50 app, designed to support real-time multiplayer hide and seek gameplay.

## 🗄️ Database Structure Overview

```
hideandcseek50/
├── users/                    # User profiles and statistics
├── games/                    # Complete game data
├── lobbies/                  # Temporary lobby codes
└── activeGames/              # Currently running games index
```

## 📊 Core Collections

### 1. Users Collection (`/users/{userUID}`)

Stores complete user profiles, game statistics, and preferences:

**Key Features:**
- **Profile Management**: Display name, email, avatar, account type
- **Comprehensive Stats**: Win/loss records for both hider and seeker roles
- **Achievement System**: Unlockable badges and milestones
- **Game History**: Complete record of all games played
- **Privacy Preferences**: Location sharing and notification settings

**Statistics Tracked:**
- Total games played
- Hider-specific: Average hiding time, best hiding time
- Seeker-specific: Average find time, best find time

### 2. Games Collection (`/games/{gameID}`)

Complete game state with real-time updates:

**Game Information (`/games/{gameID}/info`):**
- Game metadata (ID, code, name, host)
- **State Management**: waiting → starting → inProgress → paused → completed
- **Timing**: Creation, start, and end timestamps
- **Settings**: Time limits, boundaries, game modes, feature toggles

**Team Management (`/games/{gameID}/teams`):**
- **Hiders Team**: Members, team score, survival status
- **Seekers Team**: Members, team score, find statistics
- **Ready States**: Track which players are ready to start
- **Live Statistics**: Real-time score updates and performance metrics

**Location Tracking (`/games/{gameID}/locations`):**
- **Real-time GPS**: Latitude, longitude, accuracy, timestamp
- **Visibility Control**: Whether location should be shown to other team
- **Location History**: Trail of movements for game analysis
- **Privacy Compliance**: Location sharing based on user preferences

**Communication System (`/games/{gameID}/messages`):**
- **Multi-format Messages**: Text, photos, voice, system notifications
- **Team-based Chat**: Separate channels for hiders, seekers, and all
- **Question Integration**: Questions stored as special message types with questionData
- **Answer Tracking**: Question messages updated with answers, separate answer messages sent
- **Reactions**: Emoji responses to messages
- **Real-time Delivery**: Instant message propagation

**Events System (`/games/{gameID}/events`):**
- **Game Events**: Player joined/left, game started/ended, state changes
- **Question Events**: Questions asked and answered (tracked in events for analytics)
- **Automated Logging**: System automatically records important game moments
- **Game Analysis**: Post-game review of key events

### 3. Lobbies Collection (`/lobbies/{gameCode}`)

Temporary game codes for easy joining:

**Features:**
- **6-Character Codes**: Easy to share and remember
- **Auto-expiration**: Automatic cleanup after 1 hour
- **Host Control**: Only host can manage lobby settings
- **Active Status**: Tracks whether lobby is still accepting players

### 4. Active Games Index (`/activeGames/{gameID}`)

Performance optimization for game discovery:

**Benefits:**
- **Fast Queries**: Quickly find active games
- **Load Balancing**: Distribute players across games
- **Cleanup**: Automatic removal of completed games
- **Monitoring**: Track game activity and player counts

## 🔧 Advanced Features

### Real-time Location Sharing
- **Selective Visibility**: Hiders see seeker locations, seekers see limited hider info
- **GPS Accuracy**: Track location precision for fair gameplay
- **Movement History**: Record player paths for post-game analysis
- **Boundary Enforcement**: Ensure players stay within game area

### Dynamic Map Updates
- **Area Elimination**: Questions can eliminate map regions
- **Progressive Revelation**: Map information revealed based on answers
- **Visual Feedback**: Clear indication of allowed/restricted areas
- **Strategic Gameplay**: Encourage thoughtful question asking

### Comprehensive Statistics
- **Role-based Analytics**: Separate tracking for hider/seeker performance
- **Win Rate Calculations**: Automatic computation of success rates
- **Achievement Unlocking**: Progressive rewards for milestones
- **Historical Trends**: Track improvement over time

### Message & Communication
- **Multi-modal Messaging**: Text, voice, and photo support
- **Team Channels**: Private communication within teams
- **System Notifications**: Automated game state updates
- **Question Integration**: Questions and answers seamlessly integrated as special message types
- **Question Tracking**: Questions have questionData with answer status, separate answer messages sent

## 🚀 Performance Optimizations

### Database Structure
- **Flat Architecture**: Minimize nested data for faster queries
- **Indexed Fields**: Strategic indexing on frequently queried fields
- **Reference Relationships**: Efficient linking between collections
- **Cleanup Automation**: Automatic removal of expired data

### Real-time Updates
- **Selective Listening**: Only subscribe to relevant data changes
- **Batch Operations**: Group related updates for efficiency
- **Connection Monitoring**: Handle offline/online state transitions
- **Memory Management**: Proper cleanup of database listeners

## 🔒 Security & Privacy

### Access Control
- **User Data Protection**: Users can only access their own profiles
- **Game Participation**: Only game members can read/write game data
- **Location Privacy**: Location sharing based on user consent
- **Host Privileges**: Special permissions for game creators

### Data Validation
- **Server-side Rules**: Validate all data modifications
- **Type Checking**: Ensure proper data formats
- **Boundary Enforcement**: Prevent unauthorized data access
- **Rate Limiting**: Protect against spam and abuse

### Privacy Compliance
- **Data Minimization**: Only collect necessary information
- **User Control**: Granular privacy settings
- **Automatic Cleanup**: Remove old data after game completion
- **Anonymous Support**: Full gameplay without personal information

## 📈 Scalability Considerations

### Database Design
- **Horizontal Scaling**: Structure supports multiple database shards
- **Efficient Queries**: Minimize database reads/writes
- **Caching Strategy**: Local caching for frequently accessed data
- **Background Processing**: Offload heavy operations to cloud functions

### Real-time Performance
- **Connection Pooling**: Efficiently manage database connections
- **Update Batching**: Group related changes for better performance
- **Selective Synchronization**: Only sync relevant data changes
- **Offline Support**: Local data storage for network interruptions

## 🎮 Game Flow Integration

### Lobby Creation → Game Start
1. Host creates lobby with unique code
2. Players join using code and select teams
3. Real-time ready status tracking
4. Automatic game start when conditions met

### Active Gameplay
1. Real-time location updates from all players
2. Question/answer system with map modifications
3. Team communication and coordination
4. Live score tracking and leaderboards

### Game Completion
1. Statistics updates for all players
2. Achievement unlocking
3. Game history recording
4. Cleanup of temporary data

This database schema provides a robust foundation for the Hide and CSeek50 app, supporting all planned features while maintaining excellent performance and scalability for future growth.
