# Firebase Realtime Database Schema
Comprehensive schema documentation for **Hide and CSeek50**, designed for real-time sync, efficient queries, and scalability.

---

## Top-Level Structure

```
hideandcseek50/
├── users/
│   └── {userUID}/
│       ├── profile/
│       ├── stats/
│       ├── gameHistory/
│       └── preferences/
│
├── games/
│   └── {gameID}/
│       ├── info/
│       ├── teams/
│       ├── locations/
│       ├── messages/
│       ├── questions/
│       └── events/
│
├── lobbies/
│   └── {lobbyCode}/
│
└── activeGames/
    └── {gameID}/
```

---

# USERS

```jsonc
users: {
  "userUID": {
    "profile": {
      "uid": "string",
      "displayName": "string",
      "email": "string",
      "isAnonymous": true,
      "createdAt": "timestamp",
      "lastActive": "timestamp",
      "avatarURL": "string"
    },

    "stats": {
      "totalGamesPlayed": 0,
      "totalGamesWon": 0,

      "hiderStats": {
        "gamesPlayed": 0,
        "gamesWon": 0,
        "averageHidingTime": 0,
        "bestHidingTime": 0,
        "timesFound": 0,
        "averageHideScore": 0
      },

      "seekerStats": {
        "gamesPlayed": 0,
        "gamesWon": 0,
        "averageFindTime": 0,
        "bestFindTime": 0,
        "totalHidersFound": 0,
        "averageSeekScore": 0
      },

      "achievements": {
        "quickSeeker": false,
        "masterHider": false,
        "teamPlayer": false,
        "veteran": false
      }
    },

    "gameHistory": {
      "gameID1": {
        "gameId": "string",
        "role": "hider|seeker",
        "result": "won|lost",
        "score": 0,
        "duration": 0,
        "datePlayed": "timestamp"
      }
    },

    "preferences": {
      "allowLocationSharing": true,
      "receiveNotifications": true,
      "defaultRole": "hider|seeker|any"
    }
  }
}
```

---

# GAMES

```jsonc
games: {
  "gameID": {
    "info": {
      "gameId": "string",
      "gameCode": "string",
      "name": "string",
      "hostUID": "string",
      "state": "waiting|starting|inProgress|paused|completed|cancelled",
      "gameMode": "classic|timed|challenge",
      "maxPlayers": 0,
      "currentPlayers": 0,
      "createdAt": "timestamp",
      "startedAt": "timestamp|null",
      "endedAt": "timestamp|null",
      "duration": 0,
      "winner": "hiders|seekers|null",

      "settings": {
        "timeLimit": 0,
        "hidingTime": 0,
        "boundaryRadius": 0,
        "centerLatitude": 0,
        "centerLongitude": 0,
        "allowPhotos": true,
        "allowVoiceChat": true,
        "questionCategories": ["string"],
        "bonusPoints": true
      }
    },
```

---

## Teams

```jsonc
"teams": {
  "hiders": {
    "members": {
      "userUID1": {
        "uid": "string",
        "displayName": "string",
        "isReady": true,
        "joinedAt": "timestamp",
        "isOnline": true,
        "score": 0,
        "isAlive": true
      }
    },
    "teamScore": 0,
    "membersFound": 0,
    "averageHidingTime": 0
  },

  "seekers": {
    "members": {
      "userUID2": {
        "uid": "string",
        "displayName": "string",
        "isReady": true,
        "joinedAt": "timestamp",
        "isOnline": true,
        "score": 0,
        "hidersFound": 0
      }
    },
    "teamScore": 0,
    "totalHidersFound": 0,
    "averageFindTime": 0
  }
}
```

---

## Locations

```jsonc
"locations": {
  "userUID1": {
    "latitude": 0,
    "longitude": 0,
    "accuracy": 0,
    "timestamp": "timestamp",
    "isVisible": true,

    "locationHistory": {
      "timestamp1": {
        "lat": 0,
        "lng": 0,
        "timestamp": "timestamp"
      }
    }
  }
}
```

---

## Messages

```jsonc
"messages": {
  "messageID1": {
    "id": "string",
    "senderUID": "string",
    "senderName": "string",
    "content": "string",
    "type": "text|photo|voice|system|question|answer",
    "timestamp": "timestamp",
    "team": "hiders|seekers|all",

    "attachments": {
      "photoURL": "string",
      "audioURL": "string",
      "duration": 0
    },

    "questionData": {
      "questionId": "string",
      "questionText": "string",
      "isAnswered": true,
      "correctAnswer": "string",
      "playerAnswer": "string"
    },

    "reactions": {
      "userUID": "emoji"
    }
  }
}
```

---

## Questions

```jsonc
"questions": {
  "questionID1": {
    "id": "string",
    "type": "location|photo|distance|landmark|direction",
    "question": "string",
    "askedBy": "string",
    "askedAt": "timestamp",
    "answeredBy": "string",
    "answeredAt": "timestamp",
    "answer": "string",
    "isCorrect": true,
    "pointsAwarded": 0,

    "attachments": {
      "photoURL": "string",
      "coordinates": {
        "lat": 0,
        "lng": 0
      }
    },

    "mapUpdate": {
      "eliminatedAreas": [
        { "centerLat": 0, "centerLng": 0, "radius": 0 }
      ],
      "revealedAreas": [
        { "centerLat": 0, "centerLng": 0, "radius": 0 }
      ]
    }
  }
}
```

---

## Events

```jsonc
"events": {
  "eventID1": {
    "type": "gameStarted|playerJoined|playerLeft|hiderFound|questionAsked|questionAnswered|gameEnded",
    "timestamp": "timestamp",
    "playerUID": "string",
    "details": "string",
    "data": {}
  }
}
```

---

# LOBBIES

```jsonc
lobbies: {
  "ABCD12": {
    "code": "string",
    "hostUID": "string",
    "gameId": "string",
    "createdAt": "timestamp",
    "expiresAt": "timestamp",
    "isActive": true
  }
}
```

---

# ACTIVE GAMES

```jsonc
activeGames: {
  "gameID": {
    "gameId": "string",
    "state": "string",
    "playerCount": 0,
    "lastActivity": "timestamp",
    "hostUID": "string"
  }
}
```

---

# INVITATIONS (Optional)

```jsonc
invitations: {
  "inviteID": {
    "fromUID": "string",
    "toUID": "string",
    "gameId": "string",
    "status": "pending|accepted|declined|expired",
    "sentAt": "timestamp",
    "respondedAt": "timestamp"
  }
}
```

---

# SECURITY RULES

```jsonc
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    },

    "games": {
      "$gameId": {
        ".read":
          "auth != null && (" +
            "root.child('games/' + $gameId + '/teams/hiders/members/' + auth.uid).exists() || " +
            "root.child('games/' + $gameId + '/teams/seekers/members/' + auth.uid).exists() || " +
            "root.child('games/' + $gameId + '/info/hostUID').val() == auth.uid" +
          ")",

        ".write":
          "auth != null && (" +
            "root.child('games/' + $gameId + '/teams/hiders/members/' + auth.uid).exists() || " +
            "root.child('games/' + $gameId + '/teams/seekers/members/' + auth.uid).exists() || " +
            "root.child('games/' + $gameId + '/info/hostUID').val() == auth.uid" +
          ")",

        "locations": {
          "$uid": {
            ".write": "$uid === auth.uid"
          }
        }
      }
    },

    "lobbies": {
      "$code": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    },

    "activeGames": {
      ".read": "auth != null",
      "$gameId": {
        ".write":
          "auth != null && root.child('games/' + $gameId + '/info/hostUID').val() == auth.uid"
      }
    }
  }
}
```

---

# INDEXES

```jsonc
{
  "rules": {
    "games": {
      ".indexOn": ["info/state", "info/createdAt", "info/hostUID"]
    },
    "activeGames": {
      ".indexOn": ["state", "lastActivity", "hostUID"]
    },
    "lobbies": {
      ".indexOn": ["isActive", "createdAt"]
    },
    "users": {
      "$uid": {
        "gameHistory": {
          ".indexOn": ["datePlayed", "result"]
        }
      }
    }
  }
}
```
