# PID-Based App Activation Feature

## Overview

When you send a notification with a `pid` parameter, clicking that notification will automatically activate (bring to front) the application with that Process ID.

## Usage

### JSON Request Format

```json
{
  "title": "Notification Title",
  "body": "Notification message",
  "subtitle": "Optional subtitle",
  "pid": 1234
}
```

**Fields:**
- `title` (required): Notification title
- `body` (required): Notification message
- `subtitle` (optional): Additional subtitle
- `pid` (optional): Process ID of app to activate when clicked

### Finding an App's PID

#### Method 1: Using `pgrep`
```bash
# Get Safari's PID
pgrep -x "Safari"

# Get any app's PID
pgrep -x "AppName"
```

#### Method 2: Using `ps`
```bash
# List all processes
ps aux | grep -i "safari"
```

#### Method 3: Using Activity Monitor
1. Open Activity Monitor
2. Find the app
3. The PID is shown in the PID column

### Example Commands

#### Activate Safari
```bash
SAFARI_PID=$(pgrep -x "Safari")
curl -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Back to Safari\",\"body\":\"Click to activate Safari\",\"pid\":$SAFARI_PID}"
```

#### Activate Terminal
```bash
TERMINAL_PID=$(pgrep -x "Terminal")
curl -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Return to Terminal\",\"body\":\"Click to switch back\",\"pid\":$TERMINAL_PID}"
```

#### Activate Xcode
```bash
XCODE_PID=$(pgrep -x "Xcode")
curl -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Build Complete\",\"body\":\"Click to return to Xcode\",\"pid\":$XCODE_PID}"
```

#### Get current shell's PID
```bash
# $$ is the current shell's PID
curl -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Back to Shell\",\"body\":\"Click to return\",\"pid\":$$}"
```

## How It Works

### 1. Request Processing
```
POST request → HTTPServer → NotificationRequest (with pid)
     ↓
NotificationManager stores pid in notification.userInfo
     ↓
Notification is displayed
```

### 2. User Clicks Notification
```
User clicks notification → NotificationDelegate receives event
     ↓
Extract pid from userInfo
     ↓
NSWorkspace finds running app with that PID
     ↓
App is activated (brought to front)
```

### 3. Components

**NotificationRequest.swift**
- Added `pid: Int?` field

**NotificationManager.swift**
- Stores PID in `content.userInfo = ["pid": pid]`

**NotificationDelegate.swift** (new file)
- Implements `UNUserNotificationCenterDelegate`
- Handles notification clicks
- Uses `NSWorkspace` to find and activate apps by PID

**NotifierApp.swift**
- Sets up the notification delegate

## Use Cases

### 1. Development Workflow
```bash
# Start a long build, get notified when done, click to return to Xcode
XCODE_PID=$(pgrep -x "Xcode")
./long_build.sh && curl -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Build Complete\",\"body\":\"Your project is ready\",\"pid\":$XCODE_PID}"
```

### 2. Task Management
```bash
# When a task completes, notify and switch to relevant app
task_complete() {
    APP_PID=$1
    curl -X POST http://localhost:8000 \
      -H "Content-Type: application/json" \
      -d "{\"title\":\"Task Complete\",\"body\":\"Click to return to your work\",\"pid\":$APP_PID}"
}
```

### 3. Context Switching
```bash
# Pomodoro timer: switch between work app and break app
work_session() {
    WORK_APP=$(pgrep -x "Xcode")
    # ... do work ...
    curl -X POST http://localhost:8000 \
      -H "Content-Type: application/json" \
      -d "{\"title\":\"Break Time!\",\"body\":\"Take a 5 minute break\",\"pid\":$WORK_APP}"
}
```

## Testing

Run the test script:
```bash
chmod +x test_pid_activation.sh
./test_pid_activation.sh
```

This will:
1. Find PIDs of common running apps
2. Send test notifications with those PIDs
3. When you click a notification, it will activate that app

## Troubleshooting

### "No running application found with PID"
**Cause**: The process with that PID doesn't exist or has terminated

**Solutions**:
- Check if the app is still running: `ps -p <PID>`
- Get the current PID: `pgrep -x "AppName"`
- PIDs change when apps restart

### Notification appears but app doesn't activate
**Possible causes**:
1. App is hidden or minimized
2. App doesn't have permission to activate
3. Another app has focus lock

**Check console logs**:
```bash
log stream --predicate 'subsystem == "com.apple.notificationcenterui"'
```

### Wrong app activates
**Cause**: PID belongs to a different app

**Solution**:
Verify the PID:
```bash
ps -p <PID> -o comm=
```

## Advanced Usage

### Python Example
```python
import subprocess
import requests

# Get app PID
pid = int(subprocess.check_output(['pgrep', '-x', 'Safari']).strip())

# Send notification
requests.post('http://localhost:8000', json={
    'title': 'Task Complete',
    'body': 'Click to return to Safari',
    'pid': pid
})
```

### Swift Example
```swift
import Foundation

let task = Process()
task.launchPath = "/usr/bin/curl"
task.arguments = [
    "-X", "POST",
    "http://localhost:8000",
    "-H", "Content-Type: application/json",
    "-d", #"{"title":"Test","body":"Click me","pid":\#(ProcessInfo.processInfo.processIdentifier)}"#
]
task.launch()
```

## Security Considerations

⚠️ **Important**: This feature can activate any running application on the system. In a production environment, you should:

1. Validate PIDs belong to expected apps
2. Implement authentication for the HTTP server
3. Restrict which apps can be activated
4. Log all activation attempts

Example validation:
```swift
private func isAllowedPID(_ pid: Int) -> Bool {
    let runningApps = NSWorkspace.shared.runningApplications
    guard let app = runningApps.first(where: { $0.processIdentifier == pid_t(pid) }) else {
        return false
    }
    
    // Only allow specific apps
    let allowedBundleIDs = [
        "com.apple.Safari",
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode"
    ]
    
    return allowedBundleIDs.contains(app.bundleIdentifier ?? "")
}
```

## Permissions

The app uses `NSWorkspace.shared.runningApplications` which requires:
- ✅ No special entitlements needed
- ✅ Works in sandboxed apps
- ✅ No privacy prompts required

However, if you're using App Sandbox, ensure you don't have restrictions that prevent app activation.
