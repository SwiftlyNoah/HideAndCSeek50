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
      "maxPlayers": 0,
      "currentPlayers": 0,
      "createdAt": "timestamp",
      "startedAt": "timestamp|null",
      "endedAt": "timestamp|null",
      "duration": 0,
      "winner": "hiders|seekers|null",

      "settings": {
        "hidingTime": 30,
        "city": "boston|newYork",
        "timeLimit": 0,
        "boundaryRadius": 1000,
        "centerLatitude": 0,
        "centerLongitude": 0,
        "allowPhotos": true,
        "allowVoiceChat": true,
        "questionCategories": ["string"],
        "bonusPoints": false
      }
    },
```

---

## Teams

```jsonc
"teams": {
  "hiders": {
    "userUID1": {
      "uid": "string",
      "displayName": "string",
      "isReady": true,
      "location": {
        "latitude": 0,
        "longitude": 0,
        "timestamp": "timestamp"
      }
    }
  },

  "seekers": {
    "userUID2": {
      "uid": "string", 
      "displayName": "string",
      "isReady": true,
      "location": {
        "latitude": 0,
        "longitude": 0,
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
    "name": "string",
    "isPublic": true,
    "maxHiders": 2,
    "maxSeekers": 2,
    "hidingTime": 30,
    "city": "boston|newYork",
    "createdAt": "timestamp",
    "expiresAt": "timestamp",
    "isActive": true,
    
    "players": {
      "userUID1": {
        "uid": "string",
        "displayName": "string",
        "team": "hiders|seekers",
        "isReady": false,
        "joinedAt": "timestamp",
        "isOnline": true
      }
    }
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
    // User data - users can only read/write their own data
    "users": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    },

    // Game data - only game participants can access
    "games": {
      "$gameId": {
        ".read": "auth != null && (data.child('teams/hiders/' + auth.uid).exists() || data.child('teams/seekers/' + auth.uid).exists() || data.child('info/hostUID').val() == auth.uid)",
        
        // Game info can be modified by host or participants (for ready status, etc.)
        "info": {
          ".write": "auth != null && (root.child('games/' + $gameId + '/info/hostUID').val() == auth.uid || root.child('games/' + $gameId + '/teams/hiders/' + auth.uid).exists() || root.child('games/' + $gameId + '/teams/seekers/' + auth.uid).exists())"
        },

        // Teams - players can update their own status and location
        "teams": {
          "hiders": {
            "$uid": {
              ".write": "$uid === auth.uid || root.child('games/' + $gameId + '/info/hostUID').val() == auth.uid"
            }
          },
          "seekers": {
            "$uid": {
              ".write": "$uid === auth.uid || root.child('games/' + $gameId + '/info/hostUID').val() == auth.uid"
            }
          }
        },

        // Messages - game participants can send messages
        "messages": {
          "$messageId": {
            ".write": "auth != null && newData.child('senderUID').val() == auth.uid && (root.child('games/' + $gameId + '/teams/hiders/' + auth.uid).exists() || root.child('games/' + $gameId + '/teams/seekers/' + auth.uid).exists())",
            ".read": "auth != null && (root.child('games/' + $gameId + '/teams/hiders/' + auth.uid).exists() || root.child('games/' + $gameId + '/teams/seekers/' + auth.uid).exists())"
          }
        },

        // Questions - seekers can ask, hiders can answer
        "questions": {
          "$questionId": {
            ".write": "auth != null && ((newData.child('askedBy').val() == auth.uid && root.child('games/' + $gameId + '/teams/seekers/' + auth.uid).exists()) || (newData.child('answeredBy').val() == auth.uid && root.child('games/' + $gameId + '/teams/hiders/' + auth.uid).exists()))",
            ".read": "auth != null && (root.child('games/' + $gameId + '/teams/hiders/' + auth.uid).exists() || root.child('games/' + $gameId + '/teams/seekers/' + auth.uid).exists())"
          }
        },

        // Events - read-only for participants, write access for system/host
        "events": {
          ".read": "auth != null && (root.child('games/' + $gameId + '/teams/hiders/' + auth.uid).exists() || root.child('games/' + $gameId + '/teams/seekers/' + auth.uid).exists())",
          "$eventId": {
            ".write": "auth != null && root.child('games/' + $gameId + '/info/hostUID').val() == auth.uid"
          }
        }
      }
    },

    // Lobbies - authenticated users can read, participants can write
    "lobbies": {
      "$code": {
        ".read": "auth != null",
        ".write": "auth != null && (newData.child('hostUID').val() == auth.uid || data.child('hostUID').val() == auth.uid || data.child('players/' + auth.uid).exists())",
        
        // Players can update their own status in lobby
        "players": {
          "$uid": {
            ".write": "$uid === auth.uid || data.parent().child('hostUID').val() == auth.uid"
          }
        }
      }
    },

    // Active games - readable by authenticated users, writable by hosts
    "activeGames": {
      ".read": "auth != null",
      "$gameId": {
        ".write": "auth != null && (root.child('games/' + $gameId + '/info/hostUID').val() == auth.uid || newData.child('hostUID').val() == auth.uid)"
      }
    },

    // Invitations - users can read their own invitations
    "invitations": {
      "$inviteId": {
        ".read": "auth != null && (data.child('fromUID').val() == auth.uid || data.child('toUID').val() == auth.uid)",
        ".write": "auth != null && (data.child('fromUID').val() == auth.uid || data.child('toUID').val() == auth.uid || newData.child('fromUID').val() == auth.uid)"
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
      ".indexOn": ["info/state", "info/createdAt", "info/hostUID", "info/settings/city"]
    },
    "activeGames": {
      ".indexOn": ["state", "lastActivity", "hostUID"]
    },
    "lobbies": {
      ".indexOn": ["isActive", "createdAt", "isPublic", "city", "hostUID"]
    },
    "users": {
      "$uid": {
        "gameHistory": {
          ".indexOn": ["datePlayed", "result", "role"]
        },
        "stats": {
          ".indexOn": ["totalGamesPlayed", "totalGamesWon"]
        }
      }
    }
  }
}
```
