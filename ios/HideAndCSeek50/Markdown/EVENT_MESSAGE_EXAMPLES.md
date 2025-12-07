# Event Message Examples

This document shows examples of how event messages will appear in the chat interface.

## Example Game Flow

```
┌─────────────────────────────────────────┐
│                                         │
│      Game has started                   │
│      Nov 15, 2025 at 2:30 PM           │
│                                         │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  John joined as Hider                   │
│  2:30 PM                                │
└─────────────────────────────────────────┘

┌──────────────────────────────────┐      
│ Sarah: Ready to hide! 👋         │      
│ 2:31 PM                         │      
└──────────────────────────────────┘      

┌─────────────────────────────────────────┐
│      Hiding phase has started           │
│      Nov 15, 2025 at 2:32 PM           │
│                                         │
└─────────────────────────────────────────┘

┌──────────────────────────────────┐      
│ Mike: Where could they be? 🤔    │      
│ 2:45 PM                         │      
└──────────────────────────────────┘      

┌─────────────────────────────────────────┐
│      Seeking phase has started          │
│      Nov 15, 2025 at 3:02 PM           │
│                                         │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│      Game has been paused               │
│      Nov 15, 2025 at 3:15 PM           │
│                                         │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│      Game has been resumed              │
│      Nov 15, 2025 at 3:16 PM           │
│                                         │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│      Seekers won the game!              │
│      Nov 15, 2025 at 3:30 PM           │
│                                         │
└─────────────────────────────────────────┘
```

## Data Structure Example

### Event Message in Firebase
```json
{
  "messages": {
    "msg-12345": {
      "id": "msg-12345",
      "senderUID": "system",
      "senderName": "System",
      "content": "Hiding phase has started",
      "type": "event",
      "timestamp": 1700061120,
      "team": "hiders",
      "eventType": "hidingStarted"
    }
  }
}
```

### Regular Message for Comparison
```json
{
  "messages": {
    "msg-67890": {
      "id": "msg-67890",
      "senderUID": "user123",
      "senderName": "John",
      "content": "Great hiding spot!",
      "type": "text",
      "timestamp": 1700061125,
      "team": "hiders"
    }
  }
}
```

## SwiftUI Rendering

### EventMessageView Implementation
```swift
struct EventMessageView: View {
    let message: GameMessage
    
    var body: some View {
        VStack(spacing: 4) {
            Text(message.content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
```

## Event Types and Messages

| Event Type | Message Content Example |
|------------|------------------------|
| `gameStarted` | "Game has started" |
| `playerJoined` | "John joined as Hider" |
| `playerLeft` | "A player left the game" |
| `hidingStarted` | "Hiding phase has started" |
| `seekingStarted` | "Seeking phase has started" |
| `gamePaused` | "Game has been paused" |
| `gameResumed` | "Game has been resumed" |
| `gameEnded` | "Seekers won the game!" |
| `hiderFound` | "Sarah was found!" |
| `questionAsked` | "Mike asked a question" |
| `questionAnswered` | "Question was answered" |

## Visual Hierarchy

Events are visually distinct from regular messages:
- **Events**: Centered, gray text, full-width
- **Regular Messages**: Left/right aligned, colored bubbles
- **Questions**: Red background for questions, blue for answers
- **Photos**: Image thumbnails with captions

This creates a clear visual separation between:
1. **System events** (game state changes)
2. **Team communication** (messages)
3. **Game mechanics** (questions/answers)
