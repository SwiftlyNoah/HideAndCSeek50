# Firebase Cloud Functions Deployment Guide

## Overview
This guide will help you deploy Cloud Functions that send push notifications when new chat messages are posted in your game.

## Prerequisites
- Firebase CLI installed (`npm install -g firebase-tools`)
- Firebase project set up with Realtime Database
- Node.js 18+ installed

## Step-by-Step Deployment

### 1. Initialize Firebase Functions (if not already done)

```bash
# Login to Firebase
firebase login

# Initialize Firebase in your project directory
firebase init functions
```

When prompted:
- Choose your Firebase project
- Select **JavaScript** as the language
- Choose whether to use ESLint (recommended: Yes)
- Choose whether to install dependencies (recommended: Yes)

### 2. Copy the Functions Code

Copy the contents of `functions/index.js` to your `functions/index.js` file (it should already be there).

Copy the `functions/package.json` if you want to use the exact dependencies listed.

### 3. Install Dependencies

```bash
cd functions
npm install
```

### 4. Deploy the Functions

```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy specific function
firebase deploy --only functions:sendChatNotification
```

### 5. Enable Firebase Cloud Messaging (FCM) in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Project Settings** > **Cloud Messaging**
4. Make sure **Cloud Messaging API** is enabled
5. Note: You may need to enable **Firebase Cloud Messaging API** in Google Cloud Console

### 6. Configure Your iOS App for Push Notifications

#### 6.1. Enable Push Notifications in Xcode

1. Open your project in Xcode
2. Select your target
3. Go to **Signing & Capabilities**
4. Click **+ Capability**
5. Add **Push Notifications**
6. Add **Background Modes** and check:
   - Remote notifications
   - Background fetch

#### 6.2. Upload APNs Certificate/Key to Firebase

**Option A: APNs Authentication Key (Recommended)**
1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Go to **Keys** and create a new key
4. Enable **Apple Push Notifications service (APNs)**
5. Download the `.p8` file
6. In Firebase Console:
   - Go to **Project Settings** > **Cloud Messaging**
   - Under **Apple app configuration**, upload the `.p8` file
   - Enter your Key ID and Team ID

**Option B: APNs Certificate (Legacy)**
1. Create an APNs certificate in Apple Developer Portal
2. Download and install it in Keychain Access
3. Export as `.p12` file
4. Upload to Firebase Console

### 7. Test the Integration

#### 7.1. Check if FCM Token is Generated

Run your app and check the console for:
```
FCM Token: [your-token-here]
```

#### 7.2. Test with Firebase Console

1. Go to Firebase Console > **Engage** > **Messaging**
2. Click **Send your first message**
3. Enter a notification title and text
4. Click **Send test message**
5. Enter your FCM token
6. Send and check if you receive it

#### 7.3. Test with Actual Chat Message

1. Start a game with at least 2 players
2. Send a chat message from one device
3. The other device should receive a push notification

### 8. Monitor Functions

View logs in real-time:
```bash
firebase functions:log
```

Or view in Firebase Console:
- Go to **Functions** section
- Click on a function to see its logs and metrics

## Functions Overview

### `sendChatNotification`
- **Trigger**: When a new message is added to `/games/{gameId}/messages/{messageId}`
- **Action**: Sends push notifications to all players in the game except the sender
- **Topics**: Uses `game_{gameId}` topics for efficient delivery

### `onPlayerJoinGame`
- **Trigger**: When a player is added to a game team
- **Action**: Automatically subscribes the player to the game's notification topic

### `onPlayerLeaveGame`
- **Trigger**: When a player is removed from a game team
- **Action**: Automatically unsubscribes the player from the game's notification topic

### `cleanupInvalidTokens`
- **Trigger**: Runs every 24 hours
- **Action**: Removes FCM tokens older than 60 days from the database

## Troubleshooting

### Functions Not Deploying

If you get ESLint errors:
```bash
# Fix auto-fixable issues
cd functions
npm run lint -- --fix

# Or disable ESLint temporarily
firebase deploy --only functions --force
```

### Notifications Not Received

1. **Check FCM token is saved**
   - Verify in Firebase Console under Database > users > {uid} > fcmToken

2. **Check function logs**
   ```bash
   firebase functions:log
   ```

3. **Verify APNs certificate/key is uploaded**
   - Firebase Console > Project Settings > Cloud Messaging

4. **Check device permissions**
   - Settings > Your App > Notifications (should be enabled)

5. **Check if player is subscribed to game topic**
   - Look for log: "Subscribed player {uid} to topic game_{gameId}"

### Parse Error During Deployment

If you get "Unexpected token =>" error:
1. Make sure you're using Node.js 18 or higher
2. Check `functions/package.json` has `"engines": { "node": "18" }`
3. Update ESLint configuration in `.eslintrc.json` with `"ecmaVersion": 2018`
## Security Considerations

### Database Rules

Make sure your Firebase Realtime Database rules allow the functions to read user tokens:

```json
{
  "rules": {
    "users": {
      "$uid": {
        "fcmToken": {
          ".read": "auth != null",
          ".write": "auth.uid === $uid"
        }
      }
    },
    "games": {
      "$gameId": {
        ".read": "auth != null",
        "messages": {
          ".read": "auth != null",
          ".write": "auth != null"
        }
      }
    }
  }
}
```

## Cost Considerations

Firebase Cloud Functions pricing:
- **Free tier**: 2M invocations/month
- **Paid tier**: $0.40 per million invocations

For a typical game:
- 1 message = 1 function invocation
- 100 messages/game = 100 invocations
- Well within free tier for most apps

## Next Steps

1. ✅ Deploy the Cloud Functions
2. ✅ Configure APNs in Firebase Console
3. ✅ Test with real devices
4. 🔄 Monitor function logs
5. 🔄 Optimize notification content based on user feedback

## Resources

- [Firebase Cloud Functions Documentation](https://firebase.google.com/docs/functions)
- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- [APNs Configuration Guide](https://firebase.google.com/docs/cloud-messaging/ios/client)
