# Stats Structure - Time-Based Performance Tracking

## Visual Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        USER STATS                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Total Games Played: 45                                      │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│                      HIDER STATS                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Games as Hider: 22                                          │
│  Average Hiding Time: 18m 32s                                │
│  Best Hiding Time: 45m 12s ⭐                               │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│                      SEEKER STATS                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Games as Seeker: 23                                         │
│  Average Find Time: 12m 45s                                  │
│  Best Find Time: 3m 22s ⭐                                  │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│                      ACHIEVEMENTS                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  🏃 Quick Seeker - Found hider in under 5 minutes          │
│  🎯 Master Hider - Hidden for over 30 minutes              │
│  🏆 Veteran - Played 100+ games                             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Example Game History Entry

```swift
GameHistoryEntry(
    gameId: "game-12345",
    team: .hiders,
    hidingTime: 1832.0,    // 30m 32s
    seekingTime: 0.0,       // Wasn't seeking
    duration: 2400.0,       // 40m total game
    datePlayed: Date()
)
```

## Stats Calculation Examples

### Hider Performance

```swift
// After a game where user hid for 25 minutes
let hidingTime: TimeInterval = 1500 // 25 minutes in seconds

// Update average
stats.hiderStats.averageHidingTime = 
    (oldAverage * (gamesPlayed - 1) + hidingTime) / gamesPlayed

// Check for best time
if hidingTime > stats.hiderStats.bestHidingTime {
    stats.hiderStats.bestHidingTime = hidingTime
}

// Check for Master Hider achievement
if hidingTime >= 1800 { // 30 minutes
    stats.achievements.masterHider = true
}
```

### Seeker Performance

```swift
// After a game where user found hider in 4 minutes
let seekingTime: TimeInterval = 240 // 4 minutes in seconds

// Update average
stats.seekerStats.averageFindTime = 
    (oldAverage * (gamesPlayed - 1) + seekingTime) / gamesPlayed

// Check for best time (lower is better for seekers)
if seekingTime < stats.seekerStats.bestFindTime || 
   stats.seekerStats.bestFindTime == 0 {
    stats.seekerStats.bestFindTime = seekingTime
}

// Check for Quick Seeker achievement
if seekingTime <= 300 { // 5 minutes
    stats.achievements.quickSeeker = true
}
```

## Achievement System

### Quick Seeker 🏃
**Criteria**: Found a hider in under 5 minutes  
**Tracks**: Seeker efficiency and speed  
**Unlocked by**: Fast finding during any game

### Master Hider 🎯
**Criteria**: Hidden for over 30 minutes  
**Tracks**: Hiding skill and endurance  
**Unlocked by**: Long hiding duration in any game

### Veteran 🏆
**Criteria**: Played 100+ games  
**Tracks**: Experience and dedication  
**Unlocked by**: Total games played (any role)

### Team Player 🤝
**Criteria**: Won 10 team games  
**Tracks**: Cooperative gameplay  
**Status**: Can be added in future if team dynamics are tracked

## UI Display Examples

### Profile Stats Card
```
┌─────────────────────────────┐
│     Player Performance      │
├─────────────────────────────┤
│ 45 Games Played             │
│                             │
│ As Hider:                   │
│ • 22 games                  │
│ • 18m 32s avg hide time     │
│ • 45m 12s best              │
│                             │
│ As Seeker:                  │
│ • 23 games                  │
│ • 12m 45s avg find time     │
│ • 3m 22s best               │
│                             │
│ 🏃 🎯 🏆 Achievements       │
└─────────────────────────────┘
```

### Game Summary Card
```
┌─────────────────────────────┐
│     Game Completed!         │
├─────────────────────────────┤
│ Role: Hider                 │
│ Hiding Time: 28m 15s        │
│                             │
│ Personal Stats Updated:     │
│ • Average: 18m 32s → 19m 05s│
│ • Games Played: 21 → 22     │
└─────────────────────────────┘
```

### Leaderboard Options (Future)

Since there's no winner concept, leaderboards can focus on:
- **Longest Hide Times** - Top hiders by best time
- **Quickest Finds** - Top seekers by best time
- **Most Experienced** - Players by total games
- **Achievement Hunters** - Players with all achievements

## Data Flow

```
Game Ends
    ↓
Calculate hiding/seeking times from game state
    ↓
Update player stats
    ↓
Check achievement criteria
    ↓
Save to database
    ↓
Display updated stats to player
```

## Time Formatting Helpers

```swift
extension TimeInterval {
    var formattedTime: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%dm %02ds", minutes, seconds)
    }
    
    var formattedLongTime: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm %02ds", minutes, seconds)
        }
    }
}

// Usage:
let hidingTime: TimeInterval = 1832 // seconds
print(hidingTime.formattedTime) // "30m 32s"
```

## Benefits of Time-Based Stats

1. **Clear Progression** - Players can see their improvement over time
2. **Personal Goals** - Beat your own best times
3. **No Pressure** - Focus on performance, not winning
4. **Fair Comparison** - Times are objective measures
5. **Replay Value** - Always trying to improve times
6. **Skill Tracking** - See which role you excel at
7. **Achievement Hunting** - Clear goals to work toward

## Future Enhancements

Possible additions while maintaining no-winner philosophy:
- **Consistency Badge** - Played games regularly
- **Explorer** - Played in multiple cities
- **Social Star** - Played with many different players
- **Hide Streak** - Consecutive games without being found
- **Find Streak** - Consecutive games finding hiders quickly
- **Time Trials** - Special game modes focused on speed
