# Notifier - HTTP Notification Server

A macOS app that runs an HTTP server on port 8000, receives POST requests, and displays system notifications based on the request body.

## Features

- ✅ HTTP server listening on port 8000
- ✅ Accepts POST requests with JSON body
- ✅ Posts macOS system notifications
- ✅ Simple UI to control server and view status
- ✅ Built with Swift, SwiftUI, and modern async/await

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later

## Usage

### 1. Launch the App

1. Build and run the app in Xcode
2. The app will request notification permissions on first launch
3. Click "Start Server" to begin listening for requests

### 2. Send POST Requests

Send POST requests to `http://localhost:8000` with a JSON body containing:

```json
{
  "title": "Notification Title",
  "body": "Notification message content",
  "subtitle": "Optional subtitle"
}
```

**Required fields:**
- `title` (String): The notification title
- `body` (String): The notification message

**Optional fields:**
- `subtitle` (String): An optional subtitle

### 3. Example Requests

#### Using curl:

```bash
curl -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Hello from curl",
    "body": "This is a test notification",
    "subtitle": "Testing"
  }'
```

#### Using Python:

```python
import requests
import json

data = {
    "title": "Hello from Python",
    "body": "This is a test notification",
    "subtitle": "Testing"
}

response = requests.post(
    "http://localhost:8000",
    json=data
)

print(response.text)
```

#### Using JavaScript (Node.js):

```javascript
const fetch = require('node-fetch');

const data = {
  title: "Hello from Node",
  body: "This is a test notification",
  subtitle: "Testing"
};

fetch('http://localhost:8000', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify(data),
})
.then(response => response.text())
.then(data => console.log(data))
.catch(error => console.error('Error:', error));
```

## HTTP Response Codes

- **200 OK**: Notification posted successfully
- **400 Bad Request**: Invalid JSON or missing required fields
- **405 Method Not Allowed**: Only POST requests are accepted
- **500 Internal Server Error**: Failed to post notification (check permissions)

## Architecture

### Components

1. **HTTPServer.swift**: Network listener using the Network framework
   - Handles incoming TCP connections
   - Parses HTTP POST requests
   - Routes requests to notification handler

2. **NotificationRequest.swift**: Codable model for request body
   - Defines expected JSON structure
   - Validates required fields

3. **NotificationManager.swift**: Manages system notifications
   - Requests notification permissions
   - Posts local notifications using UserNotifications framework

4. **ContentView.swift**: SwiftUI interface
   - Server status display
   - Start/Stop controls
   - Usage instructions

## Permissions

The app requires notification permissions to display system notifications. On first launch, the app will request this permission. If denied, notifications won't appear but the server will still respond to requests.

To reset permissions:
1. Open System Settings
2. Go to Notifications
3. Find "Notifier" and adjust settings

## Troubleshooting

### Server won't start
- Make sure port 8000 is not already in use
- Check Console.app for error messages

### Notifications don't appear
- Grant notification permissions when prompted
- Check System Settings > Notifications > Notifier
- Make sure Do Not Disturb is disabled

### Connection refused
- Verify the server is running (green status indicator)
- Check that you're using the correct port (8000)
- Try using `127.0.0.1` instead of `localhost`

## License

Created by Xueshi Qiao on 2/16/26.
