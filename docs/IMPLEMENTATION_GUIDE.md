# Implementation Guide & Troubleshooting

## Implementation Overview

This macOS app implements a complete HTTP notification server with the following architecture:

### 1. **HTTPServer.swift** - Network Layer
- Uses Apple's `Network` framework (modern, async-friendly)
- `NWListener` listens on TCP port 8000
- Handles concurrent connections with `NWConnection`
- Parses HTTP requests manually (method, headers, body)
- Routes POST requests to the notification handler
- Returns appropriate HTTP status codes

### 2. **NotificationRequest.swift** - Data Model
- Codable struct for JSON parsing
- Required fields: `title`, `body`
- Optional field: `subtitle`
- Validation logic via `isValid` property

### 3. **NotificationManager.swift** - Notification System
- Uses `UserNotifications` framework
- Manages authorization state
- Posts notifications with `UNUserNotificationCenter`
- Observable for UI updates with `@MainActor`

### 4. **ContentView.swift** - User Interface
- SwiftUI interface with `@Observable` for reactivity
- Real-time server status display
- Start/Stop server controls
- Permission management
- Usage instructions with code examples

## Project Setup in Xcode

### Required Files
Make sure all these files are added to your Xcode project:

1. ✅ NotifierApp.swift (already exists)
2. ✅ ContentView.swift (updated)
3. ✅ HTTPServer.swift (new)
4. ✅ NotificationRequest.swift (new)
5. ✅ NotificationManager.swift (new)
6. ✅ NotifierTests.swift (for testing)

### Required Capabilities

#### 1. Outgoing Network Connections
The app needs to listen on a network port. In Xcode:

1. Select your target
2. Go to "Signing & Capabilities"
3. Click "+ Capability"
4. Add "Outgoing Connections (Client)"

OR manually edit your entitlements file:
```xml
<key>com.apple.security.network.server</key>
<true/>
```

#### 2. App Sandbox (if enabled)
If you're using App Sandbox, you need:
```xml
<key>com.apple.security.network.server</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

### Build Settings
- **Minimum macOS Version**: 13.0 or later
- **Swift Version**: 5.9 or later

## How It Works

### Request Flow

```
Client (curl/browser/app)
    ↓
  [POST Request with JSON]
    ↓
HTTPServer (port 8000)
    ↓
  [Parse HTTP Request]
    ↓
  [Extract JSON Body]
    ↓
NotificationRequest (Decode JSON)
    ↓
  [Validate Data]
    ↓
NotificationManager
    ↓
  [Post Notification]
    ↓
macOS Notification Center
    ↓
  [Display to User]
```

### Expected JSON Format

```json
{
  "title": "Required - The notification title",
  "body": "Required - The notification message",
  "subtitle": "Optional - Additional context"
}
```

## Testing the Server

### 1. Using the bash script
```bash
chmod +x test_server.sh
./test_server.sh
```

### 2. Using the Python script
```bash
chmod +x test_server.py
python3 test_server.py
```

### 3. Manual curl command
```bash
curl -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","body":"Hello World"}'
```

## Common Issues & Solutions

### Issue 1: "Address already in use"
**Symptom**: Server fails to start, console shows port 8000 is busy

**Solutions**:
```bash
# Find what's using port 8000
lsof -i :8000

# Kill the process
kill -9 <PID>

# Or change the port in HTTPServer.swift
let port: UInt16 = 8001  // Use different port
```

### Issue 2: Notifications not appearing
**Possible causes**:
1. ❌ Permission denied
   - Solution: Check System Settings → Notifications → Notifier
   
2. ❌ Do Not Disturb is enabled
   - Solution: Disable Focus modes
   
3. ❌ Screen mirroring or presentation mode
   - Solution: Check if system is in presentation mode
   
4. ❌ App in background without proper entitlements
   - Solution: Keep app in foreground or add background entitlements

### Issue 3: "Connection refused"
**Possible causes**:
1. ❌ Server not running
   - Solution: Click "Start Server" in the app
   
2. ❌ Firewall blocking
   - Solution: System Settings → Network → Firewall → Allow Notifier
   
3. ❌ Wrong URL
   - Solution: Use `http://localhost:8000` (not https)

### Issue 4: JSON parsing errors
**Common mistakes**:
```json
❌ Wrong: {"title":"Test","body":}           // Invalid JSON
❌ Wrong: {title:"Test",body:"Hello"}        // Missing quotes
❌ Wrong: {"title":"Test"}                   // Missing required field
✅ Correct: {"title":"Test","body":"Hello"}
```

### Issue 5: Server state not updating in UI
**Cause**: Using `@Observable` incorrectly

**Solution**: Make sure you're using:
```swift
@State private var server = HTTPServer()
```

Not:
```swift
let server = HTTPServer()  // Won't update UI
```

## Security Considerations

### Local Network Only
The current implementation binds to all interfaces. For production:

```swift
// Bind only to localhost
let parameters = NWParameters.tcp
let endpoint = NWEndpoint.hostPort(
    host: "127.0.0.1",
    port: NWEndpoint.Port(integerLiteral: port)
)
listener = try NWListener(using: parameters, on: endpoint.port!)
```

### Add Authentication
For production use, add token-based auth:

```swift
private func validateAuth(headers: [String: String]) -> Bool {
    guard let auth = headers["Authorization"],
          auth == "Bearer YOUR_SECRET_TOKEN" else {
        return false
    }
    return true
}
```

### Rate Limiting
Prevent spam:

```swift
private var requestCounts: [String: Int] = [:]
private let maxRequestsPerMinute = 60

func shouldAllowRequest(from ip: String) -> Bool {
    let count = requestCounts[ip] ?? 0
    return count < maxRequestsPerMinute
}
```

## Performance Notes

- **Concurrent Connections**: Server handles multiple connections simultaneously
- **Memory**: Each connection holds ~64KB buffer for request data
- **CPU**: Minimal usage, mostly I/O bound
- **Network**: Localhost only = very fast (<1ms latency)

## Extending the Implementation

### Add HTTPS Support
```swift
let options = NWProtocolTLS.Options()
// Configure TLS with certificates
parameters.defaultProtocolStack.applicationProtocols.insert(
    NWProtocolTLS.Options.self as! NWProtocolOptions,
    at: 0
)
```

### Add More Notification Options
```swift
struct NotificationRequest: Codable {
    let title: String
    let body: String
    let subtitle: String?
    let sound: String?           // NEW
    let badge: Int?              // NEW
    let actionButtons: [String]? // NEW
}
```

### Add Logging
```swift
import OSLog

let logger = Logger(subsystem: "com.example.notifier", category: "server")

logger.info("Server started on port \(port)")
logger.error("Failed to parse request: \(error)")
```

## Resources

- [Network Framework Documentation](https://developer.apple.com/documentation/network)
- [UserNotifications Framework](https://developer.apple.com/documentation/usernotifications)
- [SwiftUI @Observable](https://developer.apple.com/documentation/observation)
- [HTTP/1.1 Specification](https://www.rfc-editor.org/rfc/rfc2616)

## Support

If you encounter issues:
1. Check Console.app for app logs
2. Verify permissions in System Settings
3. Test with curl first before custom clients
4. Check firewall and network settings
