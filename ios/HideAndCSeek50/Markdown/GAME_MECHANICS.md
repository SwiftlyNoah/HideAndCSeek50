# Game Mechanics

## Overview

Hide and CSeek50 is a real-time, location-based multiplayer game where players split into two teams - Hiders and Seekers - and compete in a digital version of hide-and-seek across a real city.

## Game Flow

### 1. Lobby Phase

#### Creating a Game
- Host creates a lobby with:
  - Custom game name
  - City selection (Boston, New York, etc.)
  - Hiding time duration (default: 30 minutes)
  - Maximum players per team
  - Additional settings (boundaries, features)

#### Joining a Game
- Players join via:
  - **6-Character Code**: Enter alphanumeric code (e.g., "ABC123")
  - **Quick Match**: Automatically join a public lobby
- Select team: Hiders or Seekers
- Mark ready when prepared to start

#### Lobby Settings
- **Hiding Time**: Duration hiders have to hide (5-60 minutes)
- **City**: Geographic area for the game
- **Time Limit**: Maximum game duration
- **Boundary Radius**: Playable area size
- **Allow Photos**: Enable/disable photo sharing
- **Question Categories**: Select which question types are available

#### Starting the Game
- All players must mark themselves as "Ready"
- Host initiates the start countdown
- Game transitions to Pre-Hiding phase

### 2. Pre-Hiding Phase

**Duration**: Brief countdown (e.g., 30 seconds)

**Purpose**: Give players time to prepare

**Actions**:
- Hiders: Review map and plan hiding location
- Seekers: Wait for hiding phase to complete
- All: Verify location permissions and app readiness

**Transitions to**: Hiding Phase (automatically)

### 3. Hiding Phase

**Duration**: Configured in lobby settings (default: 30 minutes)

**Hiders**:
- Move to their chosen hiding location
- Location is tracked but NOT visible to Seekers
- Can see Seeker positions on map
- Can communicate via team chat
- Can use map tools to plan strategy
- Should stay within game boundaries

**Seekers**:
- Location is visible to Hiders
- Wait at a designated starting location
- Can communicate via team chat
- Can plan strategy and questions
- Can review question categories
- CANNOT ask questions yet

**Timer**:
- Counts down from hiding time
- Visible to all players
- Can be paused by host if needed
- Can be skipped early by host

**Transitions to**: Pre-Seeking Phase (when timer expires or host skips)

### 4. Pre-Seeking Phase

**Duration**: Brief countdown (e.g., 10 seconds)

**Purpose**: Transition period between hiding and seeking

**Actions**:
- Final position adjustments
- Prepare for active seeking
- Review available questions

**Transitions to**: Seeking Phase (automatically)

### 5. Seeking Phase

**Duration**: Until game ends or time limit reached

**Seekers**:
- Ask questions to narrow down Hider locations
- View and use map tools
- Navigate to suspected Hider locations
- Coordinate strategy via team chat
- Try to physically find Hiders

**Hiders**:
- Answer questions honestly
- Monitor Seeker positions
- Adjust hiding location if needed
- Earn card rewards for answering questions
- Use cards for strategic advantages

**Game Continues**: Until host ends game or time limit reached

**Transitions to**: Game End (when host ends or time expires)

### 6. Game End

**Triggers**:
- Host manually ends the game
- Maximum time limit reached
- All Hiders found (if win conditions enabled)

**End Screen Shows**:
- Game duration
- Final positions of all players
- Questions asked and answered
- Individual performance stats
- Cards earned (for Hiders)

**Actions**:
- View game summary
- Return to lobby for new game
- Exit to main menu

## Question System

### Question Categories

#### 1. Matching Questions
**Format**: "Is your nearest [LOCATION TYPE] the same as mine?"

**Location Types**:
- Airport
- Transit Line
- Bakery
- Pharmacy
- Fire Station
- Police Station
- University
- Hospital
- Park
- Museum
- Grocery Store
- Gas Station

**How It Works**:
- Seeker selects a location type
- System finds nearest location of that type for both Seeker and Hider
- Hider answers "Yes" (same location) or "No" (different location)

**Strategy**:
- Helps eliminate large geographic areas
- Effective for initial location narrowing

**Reward**: Draw 3, Keep 1

#### 2. Measuring Questions
**Format**: "Are you closer or further from [LOCATION] than I am?"

**How It Works**:
- Seeker searches for a specific location on the map
- System calculates distances from that location to both players
- Hider answers "Closer" or "Further"

**Strategy**:
- Precise geographic elimination
- Effective when combined with other information

**Reward**: Draw 2, Keep 1

#### 3. Thermometer Questions
**Format**: "I've traveled [DISTANCE]. Are you hotter or colder?"

**How It Works**:
- Seeker states a distance they've traveled
- Hider answers "Hotter" (closer than that distance) or "Colder" (farther)

**Strategy**:
- Reveals relative proximity
- Good for closing in on Hider location

**Reward**: Draw 2, Keep 1

#### 4. Radar Questions
**Format**: "Are you within [DISTANCE] of me?"

**How It Works**:
- Seeker specifies a radius (e.g., "500 meters")
- Hider answers "Yes" or "No" based on current positions

**Strategy**:
- Direct proximity check
- Effective for final location confirmation

**Reward**: Draw 3, Keep 2

#### 5. Tentacles Questions
**Format**: "Which of these [NUMBER] locations is closest to you?"

**How It Works**:
- Seeker places 3-5 points on the map
- Hider identifies which one is closest to their position

**Strategy**:
- Multi-point elimination
- Narrows search to specific areas

**Reward**: Draw 4, Keep 2

#### 6. Photo Questions
**Format**: "Send a photo of [SUBJECT] within 10 minutes"

**Subjects**:
- Street sign
- Building entrance
- Public art
- Storefront
- Park feature
- Transit station

**How It Works**:
- Seeker requests a photo type
- Hider has 10 minutes to take and send photo
- Seeker analyzes photo for location clues

**Strategy**:
- Visual location identification
- Requires local knowledge
- Can reveal specific landmarks

**Reward**: Draw 5, Keep 3

### Question Mechanics

#### Asking Questions
1. Seeker opens Question View
2. Selects a category
3. Chooses specific question or customizes details
4. Question appears in chat for Hider

#### Category Lockout
- Cannot ask the same category twice in a row
- Must alternate between different question types
- Prevents repetitive questioning
- Encourages diverse strategy

#### Answering Questions
1. Hider sees question in chat
2. Views answer options
3. Submits answer
4. Answer appears in chat
5. Reward button appears for Hider

#### Reward Doubling
- If the EXACT same question has been asked before in this game
- Reward is doubled (e.g., "Draw 3, Keep 1" becomes "Draw 6, Keep 2")
- Visual indicator shows question was previously asked
- Encourages variety but allows strategic repetition

#### Answer Timing
- No strict time limit (except Photo Questions)
- Hiders should answer promptly for fair gameplay
- Host can intervene if answers are delayed

## Card Deck System

### Overview

Hiders earn cards by answering questions. Cards can provide strategic advantages or information.

### Deck Structure
- **Full Deck**: All available cards (shuffled)
- **Hand**: Cards currently held by Hider
- **Discard Pile**: Used or discarded cards

### Earning Cards

When a Hider answers a question:
1. Reward button appears showing "Draw X, Keep Y"
2. Hider claims reward
3. X cards are drawn from deck
4. Hider selects Y cards to keep
5. Remaining cards are discarded
6. Kept cards added to hand

### Card Actions

**Draw X, Keep Y**:
- Draw X cards from the top of the deck
- View all drawn cards
- Select Y cards to add to hand
- Discard remaining X-Y cards

**Example**: "Draw 3, Keep 1"
- Draw 3 cards from deck
- View all 3 cards
- Choose 1 to keep
- Discard 2 cards

### Deck Reshuffling

When deck is empty:
- Discard pile is automatically reshuffled
- Becomes new deck
- Drawing continues seamlessly

### Viewing Hand

- Tap "Hand" button to view cards
- See all currently held cards
- Review card effects
- Plan strategy

## Map Tools

### Circle Tool

**Purpose**: Mark circular areas of interest

**How to Use**:
1. Select Circle tool
2. Tap map to set center point
3. Adjust radius using slider
4. Choose fill opacity
5. Save circle to map

**Use Cases**:
- Mark search areas
- Eliminate regions
- Visualize proximity ranges

### Polygon Tool

**Purpose**: Mark irregular areas

**How to Use**:
1. Select Polygon tool
2. Tap map to place vertices (3+ points)
3. Close polygon or add more points
4. Adjust fill and stroke
5. Save polygon to map

**Use Cases**:
- Mark neighborhood boundaries
- Outline complex search areas
- Visualize eliminated zones

### Perpendicular Bisector Tool

**Purpose**: Find midpoint and perpendicular line between two points

**How to Use**:
1. Select Bisector tool
2. Place first reference point
3. Place second reference point
4. Bisector line automatically drawn
5. Save to map

**Use Cases**:
- Geometric elimination
- Find equidistant points
- Advanced location triangulation

### Distance Measurement Tool

**Purpose**: Measure distance between two points

**How to Use**:
1. Select Measure tool
2. Tap start point
3. Tap end point
4. Distance displayed
5. Save measurement to map

**Use Cases**:
- Verify question distances
- Plan movement routes
- Calculate proximity

### Point Marker Tool

**Purpose**: Mark specific locations of interest

**How to Use**:
1. Select Point tool
2. Tap map location
3. Optionally add label/note
4. Save marker to map

**Use Cases**:
- Mark landmarks
- Note important locations
- Track movement history

### Transit Lines (Boston)

**Purpose**: Display MBTA transit lines

**How to Use**:
1. Open Transit view
2. Toggle specific lines on/off
3. View on map

**Available Lines**:
- Red Line
- Orange Line
- Blue Line
- Green Line
- Silver Line

**Use Cases**:
- Eliminate areas by transit proximity
- Plan movement using public transit
- Answer Transit Line questions

### Municipality Boundaries (Boston)

**Purpose**: Show city/town boundaries

**How to Use**:
1. Open Municipalities view
2. Toggle boundaries on/off
3. View on map

**Use Cases**:
- Eliminate entire municipalities
- Understand city limits
- Geographic elimination strategy

### Map Tool Sync

**Purpose**: Share map tools with teammates

**How to Use**:
1. Create map tools locally
2. Tap "Export Tools"
3. Tools saved to Firebase
4. Teammates tap "Import Tools"
5. Tools appear on their maps

**Benefits**:
- Team coordination
- Shared elimination strategy
- Collaborative analysis

## Location Tracking

### GPS Tracking

**Frequency**: Continuous with 5-meter movement threshold

**Accuracy**: Best available (typically 5-10 meters)

**Permissions**: Requires "Always" location permission for background tracking

**Battery Management**: Optimized with movement threshold

### Location Visibility

**Hiders**:
- Can see ALL player locations (Hiders and Seekers)
- Know where Seekers are at all times
- Can plan movements accordingly

**Seekers**:
- Can see other Seeker locations
- CANNOT see Hider locations directly
- Must use questions to narrow down Hider positions

### Location Updates

- Automatic updates when player moves >5 meters
- Real-time sync to Firebase
- Visible to appropriate team members
- Persisted for game history

## Communication System

### Team Chat

**Channels**:
- **Hiders Only**: Private hider communication
- **Seekers Only**: Private seeker communication
- **All Players**: General game chat (if enabled)

**Message Types**:
- Text messages
- Photo messages
- Location shares
- System events

### Photo Sharing

**Sources**:
- Take photo with camera
- Select from photo library

**Process**:
1. Tap photo icon in chat
2. Choose source (Camera/Library)
3. Select or take photo
4. Photo compresses automatically (max 5MB)
5. Uploads to Firebase Storage
6. Appears in chat with thumbnail
7. Tap to view full size

**Requirements**:
- Camera permission (for taking photos)
- Photo Library permission (for selecting photos)

### Location Sharing

**How It Works**:
1. Tap location share in chat
2. Current position sent as message
3. Recipients see map pin in chat
4. Tap pin to view on map

**Use Cases**:
- Coordinate team meeting points
- Share discovered locations
- Report Hider sightings

### System Events

**Automatically Generated For**:
- Game started
- Player joined/left
- Game phase changed
- Questions asked/answered
- Game paused/resumed
- Game ended

**Display**:
- Centered in chat
- Gray text
- Timestamped
- No sender name

See [EVENT_MESSAGE_EXAMPLES.md](EVENT_MESSAGE_EXAMPLES.md) for examples.

## Game Settings & Controls

### Host Controls

**During Game**:
- Pause/Resume game timer
- Skip to next phase
- End game early
- Kick players (if needed)

**Settings Management**:
- Modify time limits
- Adjust boundaries
- Enable/disable features

### Player Controls

**All Players**:
- View game settings
- Leave game
- Mute notifications
- Toggle map layers

**Seekers**:
- Ask questions
- Use map tools
- Search locations

**Hiders**:
- Answer questions
- Claim rewards
- View hand
- Use cards

## Strategies & Tips

### For Hiders

**Location Selection**:
- Choose areas with good cellular coverage
- Consider transit accessibility
- Think about question categories
- Balance distance from Seekers

**Answering Questions**:
- Answer honestly (game rules)
- Answer promptly
- Track which questions asked
- Use card rewards strategically

**Using the Map**:
- Monitor Seeker positions constantly
- Use map tools for analysis
- Note Seeker movement patterns
- Identify safe vs. risky areas

**Card Management**:
- Claim all available rewards
- Build a diverse hand
- Save powerful cards for critical moments

### For Seekers

**Question Strategy**:
- Start broad, narrow down
- Use Matching questions for initial elimination
- Combine question types for cross-reference
- Track previous answers
- Consider asking same question for doubled reward info

**Map Tool Usage**:
- Mark eliminated areas with polygons
- Use circles for proximity ranges
- Measure distances for verification
- Share tools with teammates

**Team Coordination**:
- Divide search areas
- Share discoveries in chat
- Don't ask redundant questions
- Combine knowledge for triangulation

**Movement**:
- Spread out to cover more area
- Use transit for faster movement
- Position strategically before asking Radar questions

## Win Conditions

**Note**: This game focuses on the experience rather than strict win/loss conditions.

**Potential End Conditions**:
- Time limit reached
- Hiders found (if physical finding is goal)
- Seekers give up
- Host ends game

**Performance Tracking**:
- Hiding duration (Hiders)
- Time to find (Seekers)
- Questions asked/answered
- Distance traveled
- Cards earned

See [STATS_STRUCTURE_GUIDE.md](STATS_STRUCTURE_GUIDE.md) for detailed statistics.

## Special Features

### App Rejoin

**If App Closes During Game**:
1. Reopen app
2. "Rejoin Game?" prompt appears
3. Tap "Rejoin"
4. Return to game at current state
5. Continue playing seamlessly

**Rejoin Validity**:
- Game must still be active
- Player must still be in team
- Within 24 hours of last play

### Directions & Navigation

**Get Directions**:
1. Search for location on map
2. Select result
3. Tap "Directions"
4. Choose transport mode
5. View route and estimated time

**Transport Modes**:
- Walking
- Driving
- Transit
- Cycling

### Quick Actions

**Shortcuts**:
- Double-tap map to recenter on your position
- Swipe up on chat to open full screen
- Long-press map for quick point marker
- Tap timer to see phase details

## Advanced Mechanics

### Question Answer Validation

The app trusts players to answer honestly. The game is designed for cooperative-competitive play where honesty is expected.

**Hider Responsibilities**:
- Answer based on current GPS position
- Answer promptly
- Consider accuracy of GPS reading
- Re-check position if uncertain

**System Calculations**:
- Distances calculated server-side
- Based on GPS coordinates at question time
- Accuracy depends on GPS signal quality

### Boundary Enforcement

**Game Boundaries**:
- Defined by center point and radius
- Visualized on map
- Monitored but not strictly enforced

**Out of Bounds**:
- System may warn players
- Encouraged to return to boundary
- Not automatically removed from game

### Performance Considerations

**Battery Life**:
- Continuous GPS tracking is battery intensive
- Recommend:
  - Start with full charge
  - Use battery saver mode if needed
  - Reduce screen brightness

**Cellular Data**:
- Real-time sync requires data connection
- Offline mode not supported
- Switch to WiFi when possible

**GPS Accuracy**:
- Best outdoors with clear sky view
- Reduced accuracy indoors
- May drift in urban canyons
- 5-meter threshold helps reduce jitter

## Accessibility

**Supports**:
- Dynamic Type for text sizing
- VoiceOver for screen reading
- High contrast modes
- Reduce motion options

## Fair Play Guidelines

**Expected Behavior**:
- Answer questions honestly
- Respect game boundaries
- Don't interfere with other players physically
- Keep chat appropriate
- Follow host decisions

**Not Allowed**:
- Dishonest answers
- Harassment in chat
- Sharing Hider locations (Seekers)
- Cheating via external communication
- Unsafe physical behavior

---

For statistics and achievement details, see [STATS_STRUCTURE_GUIDE.md](STATS_STRUCTURE_GUIDE.md).

For database structure, see [DATABASE_SCHEMA_OVERVIEW.md](DATABASE_SCHEMA_OVERVIEW.md).

For technical architecture, see [ARCHITECTURE.md](ARCHITECTURE.md).
