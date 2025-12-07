# Quick Start Guide: Photo Sending in Chat

## 🚀 Quick Setup (5 minutes)

### Step 1: Add Permissions to Info.plist
Open your `Info.plist` file and add these two entries:

```xml
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to take and send photos in the game chat.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to send photos in the game chat.</string>
```

**Or** in the Xcode Property List editor:
- Key: `Privacy - Camera Usage Description`
- Value: `We need access to your camera to take and send photos in the game chat.`

- Key: `Privacy - Photo Library Usage Description`  
- Value: `We need access to your photo library to send photos in the game chat.`

### Step 2: Enable Firebase Storage
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click "Storage" in the left sidebar
4. Click "Get Started"
5. Choose production mode or test mode
6. Click "Done"

### Step 3: Deploy Storage Rules
1. In Firebase Console → Storage → Rules tab
2. Copy the content from `storage.rules` file
3. Paste it into the rules editor
4. Click "Publish"

### Step 4: Verify Firebase SDK
Make sure `FirebaseStorage` is in your dependencies:

**Swift Package Manager** (Package.swift or Xcode):
```swift
dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0")
]
```
And add `FirebaseStorage` to your target.

**CocoaPods** (Podfile):
```ruby
pod 'Firebase/Storage'
```

### Step 5: Build and Test! 🎉
1. Build your project
2. Run on a device (camera not available in simulator)
3. Open a chat
4. Tap the photo icon
5. Select "Camera" or "Photo Library"
6. Take/select a photo
7. Watch it upload and appear in chat!

## 📱 Testing Tips

### Test on Simulator (Limited)
- ✅ Photo Library access works
- ❌ Camera not available
- ✅ Can test with existing photos

### Test on Device (Full Experience)
- ✅ Both camera and photo library work
- ✅ Real permission dialogs
- ✅ Complete user flow

### Test Scenarios
1. **First Time**: User sees permission request
2. **Permission Denied**: App shows helpful alert
3. **Large Images**: Compression kicks in automatically
4. **Slow Network**: Progress indicator shows status
5. **Offline**: Error handling (upload will fail)

## 🔍 Troubleshooting

### "Camera not available" alert
- **Cause**: Running in simulator or permission denied
- **Solution**: Test on real device, check Settings → Privacy → Camera

### Images not uploading / "User does not have permission" error
- **Cause**: Firebase Storage not configured, rules too restrictive, or missing metadata
- **Solution**: 
  1. Verify Storage is enabled in Firebase Console
  2. Verify storage rules are deployed correctly
  3. Ensure user is authenticated (`Auth.auth().currentUser != nil`)
  4. Check that upload includes required metadata (uploadedBy field)

### Images appear sideways
- **Cause**: Orientation metadata not handled
- **Solution**: Already handled! The code includes `.fixOrientation()`

### Upload takes too long
- **Cause**: Large image file
- **Solution**: Already handled! Images compressed to max 5MB

### Permission dialog not appearing
- **Cause**: Info.plist entries missing
- **Solution**: Add NSCameraUsageDescription and NSPhotoLibraryUsageDescription

## 📝 Code Overview

### Main Components

**ImagePicker.swift**: Bridge between UIKit and SwiftUI
```swift
ImagePicker(selectedImage: $selectedImage, sourceType: .camera)
```

**ChatViewModel.swift**: Handles uploads
```swift
// Set metadata to match Storage rules
let metadata = StorageMetadata()
metadata.contentType = "image/jpeg"
metadata.customMetadata = ["uploadedBy": currentUID]

await chatViewModel.sendPhotoMessage(
    gameId: gameId,
    image: selectedImage,
    currentUser: user,
    currentUserName: userName,
    currentPlayerTeam: team
)
```

**GameChatView.swift**: User interface
- Photo button in input area
- Message bubbles with photos
- Full-screen image viewer

### Photo Upload Flow
```
User taps photo icon
       ↓
Select source (Camera/Library)
       ↓
Pick/Take photo
       ↓
UIImage returned
       ↓
Orientation fix + Compression
       ↓
Upload to Firebase Storage
       ↓
Get download URL
       ↓
Create message with URL
       ↓
Save to Realtime Database
       ↓
All users see the photo
```

## 🎨 Customization Options

### Change compression quality
In `ChatViewModel.swift`:
```swift
// More quality, larger file
.compressedJPEGData(maxSizeInMB: 10.0, compressionQuality: 0.9)

// Less quality, smaller file
.compressedJPEGData(maxSizeInMB: 2.0, compressionQuality: 0.5)
```

### Change photo button icon
In `GameChatView.swift`:
```swift
Image(systemName: "camera.fill")  // Camera icon
Image(systemName: "photo.on.rectangle")  // Alternative
```

### Change message bubble style
In `MessageBubble` view:
```swift
.background(isCurrentUser ? Color.green : Color.gray)  // Different colors
.clipShape(RoundedRectangle(cornerRadius: 20))  // More rounded
```

## 📊 Firebase Console Monitoring

### View Uploaded Photos
Firebase Console → Storage → Files → games → {gameId} → photos

### Monitor Usage
Firebase Console → Storage → Usage tab
- Total storage used
- Download bandwidth
- Upload count

### Check Costs
Firebase Console → Storage → Usage → View in Billing

## ✅ Production Checklist

Before releasing:
- [ ] Info.plist permissions added
- [ ] Firebase Storage enabled
- [ ] Storage rules deployed
- [ ] Tested on real device
- [ ] Tested camera permission flow
- [ ] Tested photo library permission flow
- [ ] Verified photos upload successfully
- [ ] Verified photos display correctly
- [ ] Tested on slow network
- [ ] Tested error scenarios
- [ ] Set up storage usage alerts in Firebase
- [ ] Consider implementing photo moderation
- [ ] Review and optimize storage rules

## 📚 Additional Resources

- [Firebase Storage Documentation](https://firebase.google.com/docs/storage)
- [UIImagePickerController Documentation](https://developer.apple.com/documentation/uikit/uiimagepickercontroller)
- [SwiftUI AsyncImage Documentation](https://developer.apple.com/documentation/swiftui/asyncimage)
- [iOS Privacy Best Practices](https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy)

## 🆘 Need Help?

Common questions answered in `PHOTO_SENDING_SETUP.md`

For issues:
1. Check console logs for error messages
2. Verify Firebase configuration
3. Test permissions in Settings app
4. Review storage rules in Firebase Console
