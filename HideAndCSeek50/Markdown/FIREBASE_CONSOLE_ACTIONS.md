# Firebase Console Quick Actions

## 🔧 Actions You Need to Take in Firebase Console

### 1. Upload APNs Authentication Key

**Path**: Firebase Console → Project Settings → Cloud Messaging → Apple app configuration

**What to upload**:
- APNs Authentication Key (`.p8` file from Apple Developer Portal)
- Key ID (found in Apple Developer Portal)
- Team ID (found in Apple Developer Portal or Xcode)

**How to get these**:
1. Visit [Apple Developer Portal](https://developer.apple.com/account/resources/authkeys/list)
2. Click **+** to create new key
3. Name it (e.g., "HideAndCSeek Push Key")
4. Enable **Apple Push Notifications service (APNs)**
5. Click Continue → Register
6. **Download the .p8 file** (can only download once!)
7. Note the **Key ID** shown on screen
8. Find your **Team ID** in Membership section or in Xcode (top of project settings)

---

### 2. Enable Firebase Cloud Messaging API

**Path**: Google Cloud Console → APIs & Services → Library

**Steps**:
1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Select your Firebase project from dropdown
3. Click hamburger menu → **APIs & Services** → **Library**
4. Search for "Firebase Cloud Messaging API"
5. Click on it
6. Click **Enable** button

---

### 3. Verify Realtime Database Rules

**Path**: Firebase Console → Realtime Database → Rules

**Ensure you have these rules** (or similar):

```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "auth != null",
        ".write": "auth.uid == $uid",
        "fcmToken": {
          ".read": "auth != null",
          ".write": "auth.uid == $uid"
        }
      }
    },
    "games": {
      "$gameId": {
        ".read": "auth != null",
        ".write": "auth != null",
        "messages": {
          ".read": "auth != null",
          ".write": "auth != null",
          "$messageId": {
            ".validate": "newData.hasChildren(['senderUID', 'senderName', 'content', 'type', 'timestamp'])"
          }
        },
        "teams": {
          ".read": "auth != null",
          ".write": "auth != null"
        }
      }
    },
    "lobbies": {
      "$lobbyCode": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    }
  }
}
```

**Why**: Allows Cloud Functions to read FCM tokens and Cloud Functions run with admin privileges by default.

---

### 4. Monitor Cloud Functions (After Deployment)

**Path**: Firebase Console → Functions

**What to check**:
- ✅ Functions deployed successfully
- ✅ No errors in Recent invocations
- ✅ Health status is "Healthy"

**Functions you should see**:
1. `sendChatNotification` - Triggered when new message added
2. `onPlayerJoinGame` - Triggered when player joins
3. `onPlayerLeaveGame` - Triggered when player leaves
4. `cleanupInvalidTokens` - Scheduled to run daily

**How to view logs**:
1. Click on a function name
2. Go to **Logs** tab
3. See real-time execution logs

---

### 5. Test Messaging (Optional but Recommended)

**Path**: Firebase Console → Engage → Messaging

**Steps**:
1. Click **New notification**
2. Fill in:
   - Notification title: "Test"
   - Notification text: "Testing push notifications"
3. Click **Send test message**
4. Paste your FCM token (from Xcode console)
5. Click **Test**
6. Check your device for notification

---

## 🎯 Summary of Firebase Console Tasks

| Task | Location | Required |
|------|----------|----------|
| Upload APNs Key | Project Settings → Cloud Messaging | ✅ Required |
| Enable FCM API | Google Cloud Console → APIs | ✅ Required |
| Deploy Functions | Terminal: `firebase deploy --only functions` | ✅ Required |
| Verify Database Rules | Realtime Database → Rules | ✅ Required |
| Test Notification | Engage → Messaging | ⚠️ Recommended |
| Monitor Functions | Functions → Logs | ⚠️ Recommended |

---

## 🔐 Important Security Notes

1. **Never commit your .p8 file to git** - Keep it secure and private
2. **Never share your APNs Key ID or Team ID publicly**
3. **Database rules** should restrict write access appropriately
4. **Cloud Functions** run with admin privileges - be careful with validation

---

## 📊 Monitoring After Setup

### Check if it's working:

1. **User Token Saved?**
   - Firebase Console → Database → `/users/{uid}/fcmToken`
   - Should see a long token string

2. **Function Executing?**
   - Firebase Console → Functions → sendChatNotification → Logs
   - Should see logs when messages sent

3. **Topics Created?**
   - Not visible in console, but check function logs for:
   - "Subscribed player {uid} to topic game_{gameId}"

4. **Notifications Delivered?**
   - Test by sending message in game
   - Check other player's device

---

## 🚨 Troubleshooting

### Issue: "Invalid APNs credentials"

**Solution**:
1. Re-check Key ID and Team ID are correct
2. Ensure .p8 file is the right one
3. Try revoking and creating a new key

### Issue: "Function failed to deploy"

**Solution**:
```bash
# Check Node.js version
node --version  # Should be 18+

# Clear node_modules and reinstall
cd functions
rm -rf node_modules
npm install

# Try deploying again
firebase deploy --only functions
```

### Issue: "No FCM token in database"

**Solution**:
1. Check app requested notification permission
2. Check device is logged in
3. Check `NotificationManager.saveFCMTokenToUserProfile()` is called
4. Look for errors in Xcode console

### Issue: "Notifications not received"

**Solution**:
1. Test with Firebase Console → Messaging first
2. Check Cloud Function logs for errors
3. Verify player is subscribed to game topic
4. Ensure notification permission granted
5. Test on real device (not simulator)

---

## 📞 Quick Links

- [Firebase Console](https://console.firebase.google.com)
- [Google Cloud Console](https://console.cloud.google.com)
- [Apple Developer Portal](https://developer.apple.com/account)
- [Firebase CLI Setup](https://firebase.google.com/docs/cli)

---

## ✅ Final Checklist

Before considering setup complete:

- [ ] APNs .p8 key uploaded to Firebase
- [ ] FCM API enabled in Google Cloud
- [ ] Cloud Functions deployed (4 functions visible)
- [ ] Database rules allow token access
- [ ] Test notification sent and received
- [ ] Real chat message triggers notification
- [ ] Functions show successful invocations
- [ ] No errors in function logs
- [ ] Tested on real iOS device
- [ ] Multiple players tested in same game
