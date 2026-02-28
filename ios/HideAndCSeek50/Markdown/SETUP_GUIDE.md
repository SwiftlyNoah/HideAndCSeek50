# Development Setup Guide

This guide will help you set up your development environment for Hide and CSeek50.

## Prerequisites

### Required Software

- **macOS** 12.0 (Monterey) or later
- **Xcode** 14.0 or later
- **Xcode Command Line Tools**
- **Node.js** 18+ (for Firebase Cloud Functions)
- **CocoaPods** or **Swift Package Manager** (SPM recommended)
- **Git** for version control

### Required Accounts

- **Apple Developer Account** (for device testing and deployment)
- **Firebase Account** (free tier is sufficient for development)
- **Google Cloud Account** (automatically created with Firebase)

## Initial Project Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd HideAndCSeek50
```

### 2. Open Project in Xcode

```bash
open ios/HideAndCSeek50.xcodeproj
```

### 3. Configure Development Team

1. Select the project in Xcode navigator
2. Select target "HideAndCSeek50"
3. Go to "Signing & Capabilities" tab
4. Select your development team
5. Xcode will automatically manage provisioning profiles

## Firebase Setup

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Add project" or use existing project
3. Enter project name (e.g., "hideandcseek50-dev")
4. Accept terms and click "Continue"
5. Disable Google Analytics (optional for development)
6. Click "Create project"

### 2. Add iOS App to Firebase

1. In Firebase Console, click iOS icon to add iOS app
2. Enter iOS bundle identifier (matches Xcode project)
   - Found in Xcode: Target → General → Bundle Identifier
3. Enter app nickname (optional): "HideAndCSeek50"
4. Leave App Store ID blank (for development)
5. Click "Register app"

### 3. Download Configuration File

1. Download `GoogleService-Info.plist`
2. In Xcode, right-click on `HideAndCSeek50` folder
3. Select "Add Files to HideAndCSeek50"
4. Select downloaded `GoogleService-Info.plist`
5. Ensure "Copy items if needed" is checked
6. Ensure target "HideAndCSeek50" is selected
7. Click "Add"

**Important**: Do not commit `GoogleService-Info.plist` to public repositories (add to `.gitignore`)

### 4. Install Firebase SDK

#### Option A: Swift Package Manager (Recommended)

Already configured in this project. If starting fresh:

1. Xcode → File → Add Packages
2. Enter URL: `https://github.com/firebase/firebase-ios-sdk`
3. Select version: 10.0.0 or later
4. Add these products to target:
   - FirebaseAuth
   - FirebaseDatabase
   - FirebaseStorage
   - FirebaseMessaging

#### Option B: CocoaPods

If using CocoaPods instead:

```bash
cd ios
pod init
```

Edit `Podfile`:
```ruby
platform :ios, '15.0'

target 'HideAndCSeek50' do
  use_frameworks!

  pod 'Firebase/Auth'
  pod 'Firebase/Database'
  pod 'Firebase/Storage'
  pod 'Firebase/Messaging'
  pod 'GoogleSignIn'
end
```

Install pods:
```bash
pod install
```

Open `.xcworkspace` instead of `.xcodeproj` going forward.

### 5. Enable Firebase Services

#### Enable Realtime Database

1. Firebase Console → Realtime Database
2. Click "Create Database"
3. Select location (us-central1 recommended)
4. Start in **Test Mode** for development
5. Click "Enable"

#### Set Database Rules

1. Go to Database → Rules tab
2. Copy content from `firebase-database-rules.json`
3. Paste into Rules editor
4. Click "Publish"

#### Enable Authentication

1. Firebase Console → Authentication
2. Click "Get started"
3. Go to "Sign-in method" tab
4. Enable the following providers:

**Email/Password**:
- Click "Email/Password"
- Enable toggle
- Save

**Anonymous**:
- Click "Anonymous"
- Enable toggle
- Save

**Apple Sign In**:
- Click "Apple"
- Enable toggle
- You'll configure Apple Developer settings later
- Save

**Google Sign In**:
- Click "Google"
- Enable toggle
- Enter support email
- Save

#### Enable Storage

1. Firebase Console → Storage
2. Click "Get Started"
3. Use default rules (will customize later)
4. Click "Next"
5. Select location (same as Database)
6. Click "Done"

#### Set Storage Rules

1. Go to Storage → Rules tab
2. Copy content from `storage.rules`
3. Paste into Rules editor
4. Click "Publish"

### 6. Configure Apple Sign In

#### In Apple Developer Portal

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Go to **Identifiers** → Select your App ID
4. Enable **Sign In with Apple** capability
5. Click "Save"

#### In Xcode

1. Select target "HideAndCSeek50"
2. Go to "Signing & Capabilities"
3. Click "+ Capability"
4. Add **Sign In with Apple**

#### In Firebase Console

1. Firebase Console → Authentication → Sign-in method
2. Click "Apple"
3. Enable if not already enabled
4. No additional configuration needed for development

### 7. Configure Google Sign In

#### Get OAuth Client ID

1. Firebase Console → Project Settings (gear icon)
2. Go to "Your apps" section
3. Select your iOS app
4. Copy **Client ID** (looks like `123456789-abcdef.apps.googleusercontent.com`)

#### Add to Xcode

1. Open `Info.plist`
2. Add URL scheme:
   - Key: `CFBundleURLTypes`
   - Add new URL Type
   - URL Schemes: `com.googleusercontent.apps.YOUR-CLIENT-ID` (reversed)

Or in Xcode Info.plist editor:
- Expand "URL types"
- Add new URL type
- URL Schemes: Enter reversed client ID

#### Update Code

The `GoogleService-Info.plist` automatically provides the necessary configuration.

## Push Notifications Setup

### 1. Enable Push Notifications in Xcode

1. Select target "HideAndCSeek50"
2. Go to "Signing & Capabilities"
3. Click "+ Capability"
4. Add **Push Notifications**
5. Add **Background Modes**
   - Check "Remote notifications"
   - Check "Background fetch"

### 2. Create APNs Authentication Key

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Go to **Keys**
4. Click "+" to create new key
5. Enter name: "Push Notifications Key"
6. Enable **Apple Push Notifications service (APNs)**
7. Click "Continue" → "Register" → "Download"
8. Save `.p8` file securely (can only download once!)
9. Note your **Key ID** and **Team ID**

### 3. Upload APNs Key to Firebase

1. Firebase Console → Project Settings → Cloud Messaging
2. Scroll to "Apple app configuration"
3. Click "Upload" under APNs Authentication Key
4. Upload your `.p8` file
5. Enter Key ID (from Apple Developer Portal)
6. Enter Team ID (from Apple Developer Portal)
7. Click "Upload"

### 4. Enable Firebase Cloud Messaging API

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your Firebase project
3. Go to **APIs & Services** → **Library**
4. Search for "Firebase Cloud Messaging API"
5. Click on it → Click "Enable"

## Firebase Cloud Functions Setup

### 1. Install Firebase CLI

```bash
npm install -g firebase-tools
```

Verify installation:
```bash
firebase --version
```

### 2. Login to Firebase

```bash
firebase login
```

Follow browser prompts to authenticate.

### 3. Initialize Functions (if not already done)

```bash
cd HideAndCSeek50  # project root
firebase init functions
```

When prompted:
- Select your Firebase project
- Choose **JavaScript**
- Use ESLint: **Yes**
- Install dependencies: **Yes**

### 4. Install Function Dependencies

```bash
cd cloud_functions/functions
npm install
```

### 5. Deploy Cloud Functions

```bash
# From project root or cloud_functions directory
firebase deploy --only functions
```

Expected output: 5 functions deployed successfully
- `sendChatNotification`
- `onPlayerJoinGame`
- `onPlayerLeaveGame`
- `updateGameStatistics`
- `cleanupInvalidTokens`

### 6. Verify Deployment

1. Firebase Console → Functions
2. Verify all 5 functions are listed
3. Check that status shows "Healthy"

### 7. Monitor Function Logs

```bash
# View all function logs
firebase functions:log

# View specific function
firebase functions:log --only sendChatNotification

# View recent logs
firebase functions:log --since 1h
```

## Xcode Project Configuration

### 1. Required Capabilities

Ensure these capabilities are enabled:

- **Sign In with Apple**
- **Push Notifications**
- **Background Modes**
  - Remote notifications
  - Background fetch
  - Location updates (if needed)

### 2. Required Permissions in Info.plist

Verify these keys exist:

```xml
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to take photos for the game.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to share photos in the game.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need your location to track your position during the game.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show your position on the map.</string>

<key>NSMicrophoneUsageDescription</key>
<string>We need access to your microphone for voice features.</string>
```

### 3. Build Settings

Recommended settings:

- **Swift Language Version**: Swift 5
- **iOS Deployment Target**: 15.0 or later
- **Bitcode**: No (not required for modern iOS)

## Testing Setup

### Testing on Simulator

**What Works**:
- UI and navigation
- Authentication (except Apple Sign In)
- Chat messaging (text)
- Map tools

**What Doesn't Work**:
- Camera access
- Real GPS locations (uses simulated location)
- Push notifications
- Apple Sign In

### Testing on Real Device

**Setup**:
1. Connect iPhone via USB
2. Trust computer on device
3. In Xcode, select your device from destination menu
4. Click "Run" (⌘R)

**First-time Device Setup**:
- Settings → General → Device Management
- Trust your developer certificate

**What to Test**:
- Location tracking
- Camera and photo library
- Push notifications
- Full gameplay experience

### Multi-Device Testing

For complete game testing, you need multiple devices:

**Option 1: Physical Devices**
- Use 2+ iPhones
- Each logged in with different Apple ID
- Test lobby joining, team play, chat

**Option 2: TestFlight**
- Upload build to TestFlight
- Invite test users
- Test on their devices

**Option 3: Simulator + Device**
- Limited functionality
- Good for basic flow testing

## Environment Configuration

### Development vs Production

**Development** (Firebase Test Mode):
- Database rules: Test mode (open access)
- Storage rules: Test mode (open access)
- Use separate Firebase project
- Test APNs sandbox environment

**Production** (Firebase Production Mode):
- Database rules: Restrictive (see `firebase-database-rules.json`)
- Storage rules: Restrictive (see `storage.rules`)
- Use production Firebase project
- Production APNs environment
- Enable billing and usage alerts

### Switching Environments

To use different Firebase projects:

1. Swap `GoogleService-Info.plist` files
2. Update Firebase CLI project:
   ```bash
   firebase use <project-id>
   ```
3. Clean and rebuild project

## Common Setup Issues

### Issue: "GoogleService-Info.plist not found"

**Solution**:
- Ensure file is in project root
- Check it's added to target
- Clean build folder (⌘⇧K) and rebuild

### Issue: "No such module 'Firebase'"

**Solution**:
```bash
# For SPM
File → Packages → Reset Package Caches

# For CocoaPods
pod deintegrate
pod install
```

### Issue: Firebase initialization fails

**Solution**:
- Verify `GoogleService-Info.plist` bundle ID matches Xcode
- Check Firebase project is active
- Ensure all required Firebase services are enabled

### Issue: Push notifications not working

**Checklist**:
- [ ] APNs key uploaded to Firebase
- [ ] Push Notifications capability enabled
- [ ] Background Modes enabled
- [ ] Firebase Cloud Messaging API enabled
- [ ] Testing on real device (not simulator)
- [ ] Notification permissions granted

### Issue: Authentication fails

**Solutions**:

For Apple Sign In:
- Enable capability in Xcode
- Enable in Apple Developer Portal
- Wait 10-15 minutes for changes to propagate

For Google Sign In:
- Verify `GoogleService-Info.plist` is correct
- Check URL scheme in Info.plist
- Ensure OAuth client ID is correct

### Issue: Cloud Functions not deploying

**Solution**:
```bash
# Check Node.js version
node --version  # Should be 18+

# Update Node if needed (using nvm)
nvm install 18
nvm use 18

# Clear and reinstall
cd cloud_functions/functions
rm -rf node_modules package-lock.json
npm install

# Deploy with verbose logging
firebase deploy --only functions --debug
```

### Issue: Location tracking not working

**Solution**:
- Check location permissions in Settings
- Verify "Always" permission is granted
- Test on real device (simulator has limited GPS)
- Check LocationManager initialization

## Development Workflow

### Daily Development

1. **Pull Latest Changes**
   ```bash
   git pull origin main
   ```

2. **Open Project**
   ```bash
   open ios/HideAndCSeek50.xcodeproj
   ```

3. **Build and Run**
   - Select device/simulator
   - Press ⌘R to run

4. **Test Features**
   - Verify changes work as expected
   - Test on real device for hardware features

5. **Commit Changes**
   ```bash
   git add .
   git commit -m "Descriptive message"
   git push origin your-branch
   ```

### Deploying Functions After Changes

```bash
cd cloud_functions/functions

# Run linter
npm run lint

# Fix auto-fixable issues
npm run lint -- --fix

# Deploy
firebase deploy --only functions

# Monitor logs
firebase functions:log
```

### Database Rule Updates

```bash
# Deploy updated rules
firebase deploy --only database

# Or via Firebase Console
# Database → Rules → Edit → Publish
```

## Production Deployment Checklist

Before deploying to production:

### Code Preparation
- [ ] All features tested on real devices
- [ ] No debug print statements in production code
- [ ] API keys not hardcoded (use Firebase config)
- [ ] Error handling comprehensive
- [ ] Analytics configured (if desired)

### Firebase Configuration
- [ ] Use production Firebase project
- [ ] Database rules restrictive and tested
- [ ] Storage rules restrictive and tested
- [ ] Functions deployed and tested
- [ ] Billing enabled with usage alerts
- [ ] Backup strategy in place

### iOS App
- [ ] Production provisioning profile
- [ ] Production APNs certificate/key
- [ ] Version number incremented
- [ ] Build number incremented
- [ ] App Store screenshots prepared
- [ ] Privacy policy URL configured

### Testing
- [ ] Full gameplay tested with multiple users
- [ ] Push notifications work in production
- [ ] Authentication flows tested
- [ ] Performance tested under load
- [ ] Edge cases and errors handled

### Deployment
- [ ] Archive app in Xcode
- [ ] Upload to App Store Connect
- [ ] Submit for review
- [ ] Monitor Firebase usage and costs

## Useful Commands Reference

### Firebase CLI

```bash
# Login/Logout
firebase login
firebase logout

# Project management
firebase use <project-id>
firebase projects:list

# Deployment
firebase deploy --only functions
firebase deploy --only database
firebase deploy --only storage

# Monitoring
firebase functions:log
firebase functions:log --only <function-name>
firebase functions:list

# Local testing
firebase emulators:start
firebase emulators:start --only functions
```

### Git

```bash
# Branch management
git checkout -b feature/new-feature
git checkout main
git branch -d feature/old-feature

# Sync with remote
git pull origin main
git push origin feature/new-feature

# Stash changes
git stash
git stash pop
```

### Xcode

```bash
# Clean build
⌘⇧K (Command + Shift + K)

# Build
⌘B (Command + B)

# Run
⌘R (Command + R)

# Stop
⌘. (Command + Period)
```

## Additional Resources

- **Firebase iOS SDK**: [https://github.com/firebase/firebase-ios-sdk](https://github.com/firebase/firebase-ios-sdk)
- **Firebase Documentation**: [https://firebase.google.com/docs/ios/setup](https://firebase.google.com/docs/ios/setup)
- **Apple Developer**: [https://developer.apple.com/documentation](https://developer.apple.com/documentation)
- **SwiftUI Tutorials**: [https://developer.apple.com/tutorials/swiftui](https://developer.apple.com/tutorials/swiftui)
- **MapKit Documentation**: [https://developer.apple.com/documentation/mapkit](https://developer.apple.com/documentation/mapkit)

## Getting Help

- **Firebase Support**: [https://firebase.google.com/support](https://firebase.google.com/support)
- **Stack Overflow**: Tag questions with `firebase`, `ios`, `swift`
- **GitHub Issues**: Check repository issues for known problems
- **Project Documentation**: Refer to other markdown files in this directory

---

**Note**: This guide assumes a basic familiarity with iOS development and Firebase. For complete beginners, consider reviewing Apple's Swift and SwiftUI tutorials first.
