# Push Notification Setup Checklist

## ✅ What's Already Done (Swift/iOS Side)

1. ✅ **AppDelegate.swift** - Configured with FCM and APNs handling
2. ✅ **NotificationManager.swift** - Manages FCM tokens, subscriptions, and notifications
3. ✅ **GameView.swift** - Automatically subscribes/unsubscribes when entering/leaving games
4. ✅ **Firebase Cloud Functions** - Code written for `sendChatNotification` and helper functions

## 🔧 What You Need to Do

### Step 1: Delete Duplicate AppDelegate.swift File

❌ **Action Required**: Delete the standalone `AppDelegate.swift` file from your project
- The `AppDelegate` class is already defined in `HideAndCSeek50App.swift`
- Right-click on `AppDelegate.swift` → Delete → Move to Trash
- This will fix the "Invalid redeclaration" error

### Step 2: Enable Push Notifications in Xcode

1. Open your project in Xcode
2. Select your target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Push Notifications**
6. Add **Background Modes** and enable:
   - ☑️ Remote notifications
   - ☑️ Background fetch

### Step 3: Create APNs Authentication Key

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/authkeys/list)
2. Click **+** to create a new key
3. Name it "Push Notifications Key" (or similar)
4. Enable **Apple Push Notifications service (APNs)**
5. Click **Continue** → **Register** → **Download**
6. Save the `.p8` file securely
7. Note your **Key ID** and **Team ID**

### Step 4: Upload APNs Key to Firebase

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Project Settings** (gear icon) → **Cloud Messaging** tab
4. Scroll to **Apple app configuration**
5. Click **Upload** under APNs Authentication Key
6. Upload your `.p8` file
7. Enter your **Key ID** and **Team ID**
8. Click **Upload**

### Step 5: Enable Firebase Cloud Messaging API

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your Firebase project
3. Go to **APIs & Services** → **Library**
4. Search for "Firebase Cloud Messaging API"
5. Click **Enable**

### Step 6: Deploy Firebase Cloud Functions

Open Terminal and navigate to your project directory:

```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Functions (if not already done)
firebase init functions
# - Select your Firebase project
# - Choose JavaScript
# - Use ESLint: Yes
# - Install dependencies: Yes

# Navigate to functions directory
cd functions

# Install dependencies
npm install

# Deploy the functions
firebase deploy --only functions
```

### Step 7: Test Notifications

#### Test 1: Request Permission

1. Run your app on a real device (notifications don't work on simulator)
2. When prompted, tap **Allow** for notifications
3. Check console for "FCM Token: ..." message

#### Test 2: Verify Token Storage

1. Go to Firebase Console → Realtime Database
2. Navigate to `/users/{your-uid}/fcmToken`
3. Verify your FCM token is saved

#### Test 3: Send Test Notification

1. Firebase Console → **Engage** → **Messaging**
2. Click **New notification**
3. Enter title and text
4. Click **Send test message**
5. Paste your FCM token
6. Click **Test** button
7. Check if notification appears on your device

#### Test 4: Test Chat Notifications

1. Start a game with 2+ players (use real devices)
2. Send a chat message from Device A
3. Device B should receive a push notification
4. Tap notification → should open the game

### Step 8: Monitor and Debug

#### View Cloud Function Logs

```bash
# Real-time logs
firebase functions:log --only sendChatNotification

# Or view in Firebase Console
# Functions → sendChatNotification → Logs tab
```

#### Common Issues

**No FCM token generated?**
- Check that Push Notifications capability is enabled
- Verify APNs key is uploaded to Firebase
- Check app bundle ID matches Firebase project

**Notification not received?**
- Check user granted notification permission
- Verify FCM token is saved to database
- Check Cloud Function logs for errors
- Verify player is subscribed to game topic

**"Invalid redeclaration of AppDelegate" error?**
- Delete the standalone `AppDelegate.swift` file
- Keep only the one in `HideAndCSeek50App.swift`

**Parse error when deploying functions?**
- Use Node.js 18 or higher: `node --version`
- Check `.eslintrc.json` has `"ecmaVersion": 2018`

## 📱 How It Works

### Flow Diagram

```
Player A sends message
    ↓
Message saved to `/games/{gameId}/messages/{messageId}`
    ↓
Cloud Function `sendChatNotification` triggered
    ↓
Function reads all players in game
    ↓
Sends notification to topic `game_{gameId}`
    ↓
All players subscribed to topic receive notification
    ↓
Player B's device shows notification
    ↓
Player B taps notification → Opens game chat
```

### Subscription Management

**When player starts a game:**
```swift
// GameView.swift - .onAppear
NotificationManager.shared.subscribeToGame(gameId: gameId)
```

**When player leaves a game:**
```swift
// GameView.swift - .onDisappear  
NotificationManager.shared.unsubscribeFromGame(gameId: gameId)
```

**Automatic subscription (Cloud Function):**
- When player joins game → `onPlayerJoinGame` subscribes them
- When player leaves game → `onPlayerLeaveGame` unsubscribes them

## 🎯 Testing Checklist

- [ ] APNs key uploaded to Firebase
- [ ] Push Notifications capability enabled in Xcode
- [ ] Background Modes enabled (Remote notifications)
- [ ] Cloud Functions deployed successfully
- [ ] FCM token appears in app console
- [ ] FCM token saved to database (`/users/{uid}/fcmToken`)
- [ ] Test notification received from Firebase Console
- [ ] Chat message triggers notification
- [ ] Tapping notification opens the game
- [ ] Notifications work when app is in background
- [ ] Notifications work when app is closed
- [ ] No notifications when app is in foreground (or banner shows)

## 📚 Additional Resources

- [Firebase Cloud Messaging for iOS](https://firebase.google.com/docs/cloud-messaging/ios/client)
- [Firebase Cloud Functions](https://firebase.google.com/docs/functions)
- [APNs Configuration](https://firebase.google.com/docs/cloud-messaging/ios/certs)
- [Notification Topics](https://firebase.google.com/docs/cloud-messaging/ios/topic-messaging)

## 🆘 Need Help?

If you encounter issues:

1. Check function logs: `firebase functions:log`
2. Check Xcode console for FCM token
3. Verify database structure matches expected format
4. Test on real device (not simulator)
5. Ensure you're using the correct Firebase project

## 💡 Pro Tips

- **Test on real devices only** - Push notifications don't work on iOS Simulator
- **Use topics** - More efficient than individual tokens for game-wide messages
- **Monitor costs** - Check Firebase usage regularly
- **Set up retention** - Function logs are retained for 30 days by default
- **Handle failures gracefully** - Functions have automatic retry logic
