# Xcode Project Configuration Guide

## Overview

To make the Notifier app work properly, you need to configure some settings in Xcode. Here's a complete guide.

## 1. ✅ Add Entitlements File

### Option A: Using Xcode UI

1. Select your **Notifier** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add these capabilities:
   - **Outgoing Connections (Client)**
   - **Incoming Connections (Server)**

### Option B: Manual Entitlements File

1. Add the `Notifier.entitlements` file to your project
2. In Xcode, select your target
3. Go to **Build Settings**
4. Search for "Code Signing Entitlements"
5. Set the value to: `Notifier.entitlements`

### Required Entitlements:

```xml
<key>com.apple.security.network.server</key>
<true/>

<key>com.apple.security.network.client</key>
<true/>

<key>com.apple.security.automation.apple-events</key>
<true/>
```

## 2. 🔐 Permissions

### Notification Permission
- Requested automatically when app launches
- User will see a system dialog

### AppleScript/Automation Permission
- First time you click a notification, macOS will prompt:
  > "Notifier" would like to control "Terminal"
- Click **OK** to allow

### Network Permission (macOS 13+)
- First time server starts, macOS may prompt for network access
- Click **Allow**

## 3. 📝 Info.plist Configuration

The `Info.plist` file should include:

### Privacy Descriptions:
```xml
<key>NSAppleEventsUsageDescription</key>
<string>Notifier uses AppleScript to activate specific Terminal tabs and other apps when you click notifications.</string>
```

### Minimum macOS Version:
```xml
<key>LSMinimumSystemVersion</key>
<string>13.0</string>
```

## 4. 🎯 Xcode Target Settings

### Deployment Target
- **macOS**: 13.0 or later
- Go to: Target → General → Deployment Info

### Bundle Identifier
- Example: `com.yourname.Notifier`
- Go to: Target → General → Identity

### Signing
- Team: Select your Apple Developer team
- Go to: Target → Signing & Capabilities

## 5. 📦 Project Structure

Your Xcode project should have:

```
Notifier/
├── NotifierApp.swift              ✅ Main app entry
├── ContentView.swift              ✅ UI
├── HTTPServer.swift               ✅ Network server
├── NotificationRequest.swift      ✅ Data model
├── NotificationManager.swift      ✅ Notification handling
├── NotificationDelegate.swift     ✅ Notification interactions
├── Notifier.entitlements          ✅ Capabilities
└── Info.plist                     ✅ App metadata (optional)
```

## 6. 🧪 Testing Checklist

### Before First Run:
- [ ] Entitlements file added
- [ ] Network server capability enabled
- [ ] Deployment target set to macOS 13.0+
- [ ] Valid signing certificate selected

### First Launch:
- [ ] Grant notification permission when prompted
- [ ] Grant AppleScript permission when prompted
- [ ] Allow network access when prompted

### Test Server:
```bash
# Start the app, then test:
curl -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","body":"Hello"}'
```

## 7. 🚨 Common Issues

### Issue 1: "Network server not allowed"
**Solution**: Add `com.apple.security.network.server` to entitlements

### Issue 2: "AppleScript not allowed"
**Solution**: 
1. Add `com.apple.security.automation.apple-events` to entitlements
2. System Settings → Privacy & Security → Automation → Notifier → Enable Terminal

### Issue 3: Notifications don't appear
**Solution**: 
- System Settings → Notifications → Notifier → Enable notifications
- Check notification style is set to "Alerts" or "Banners"

### Issue 4: Can't bind to port 8000
**Solution**: 
```bash
# Check if port is in use
lsof -i :8000

# Kill the process
kill -9 <PID>
```

## 8. 🎨 Optional: App Icon

1. Create an `.appiconset` in Assets.xcassets
2. Add icon images at various sizes
3. Drag into Xcode asset catalog

## 9. 🔒 Hardened Runtime (for Notarization)

If you plan to distribute your app:

1. Target → Signing & Capabilities
2. Add **Hardened Runtime** capability
3. Under Hardened Runtime, enable:
   - **Allow Unsigned Executable Memory** (if needed)
   - **Disable Library Validation** (if needed)

## 10. 📱 Build & Run

### Debug Build:
```
⌘R - Build and run in Xcode
```

### Release Build:
```
1. Product → Archive
2. Distribute App → Copy App
3. Notarize (if distributing)
```

## 11. 🎯 Quick Setup Script

For Xcode 15+, you can set up via command line:

```bash
# Set deployment target
xcrun agvtool new-marketing-version 1.0.0

# Add entitlements (already in project)
# Just make sure it's in Build Settings → Code Signing Entitlements
```

## Summary

### Minimum Required:
✅ **Notifier.entitlements** with network permissions
✅ **macOS 13.0+** deployment target
✅ **Valid signing certificate**

### Recommended:
✅ **Info.plist** with privacy descriptions
✅ **AppleScript automation** entitlement
✅ **Proper bundle identifier**

### Optional:
- App icon
- Hardened runtime
- Notarization (for distribution)

---

Once configured, your app should:
1. ✅ Listen on port 8000
2. ✅ Receive POST requests
3. ✅ Show notifications
4. ✅ Activate apps via AppleScript
5. ✅ Switch Terminal tabs by TTY

🚀 You're ready to go!
