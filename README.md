# Notifier - Never miss a prompt again

A macOS app that routes permission requests from AI agentic code tools to native notifications.

## Features
- ✅ **Secure**, **local-only with no outbound request**.
- ✅ ***Native*** experience, built with Swift, SwiftUI
- ✅ ***Activate the source app*** when clicking the notification banner
- ✅ Support `callback_url` to open source app directly (takes priority over `pid`)
- ✅ if `callback_url` was not provided, but `pid` exists, we use `pid` to open the source app instead
- ✅ Parse source app icon from `pid` and attach it to notification content
- ✅ Compatible with nearly any terminal, ***Terminal, Ghostty, Tabby*** and others
- ✅ Compatible with ***Gemini Cli, Claude code***, and any agentic coding tool supports hook

## Screenshot
![App Screenshot](docs/screenshot_01.png)
![App Screenshot](docs/screenshot_02.png)
## Requirements

- macOS 13.0 or later

## Integration with Gemini CLI and Claude Code

* For Claude Code, see [integrate_claude_code.md](docs/integrate_claude_code.md)
* For Gemini CLI, see [integrate_gemini_cli.md](docs/integrate_gemini_cli.md)

## Usage

### 1. Launch the App

1. Download the app from Release / Build and run the app in Xcode
2. The app will request notification permissions on first launch
3. Click "Start Server" to begin listening for requests

### 2. Send POST Requests

Send POST requests to `http://localhost:8000` with a JSON body containing:

```json
{
  "title": "Notification Title",
  "body": "Notification message content",
  "subtitle": "Optional subtitle",
  "callback_url": "myapp://open/somewhere",
  "pid": 1234
}
```

**Required fields:**
- `title` (String): The notification title
- `body` (String): The notification message

**Optional but important fields:**
- `subtitle` (String): An optional subtitle
- `callback_url` (String): URL scheme callback to open directly when notification is clicked
- `pid` (Int): ***Process ID to activate when notification is clicked***

If `callback_url` is provided, Notifier opens it directly on click and does not use `pid` activation.
If `pid` is provided, Notifier also parses the source app icon from that PID and attaches it to the notification content (shown in expanded notification UI).


### 3. Example Requests

#### Using curl:

```bash
curl -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Build Complete",
    "body": "Project compiled successfully",
    "subtitle": "Success",
    "pid": 1234
  }'
```

Note: When executing this command in a terminal, use `$PPID` for the pid parameter. While `$PID` would represent the current shell's process (which spawns the curl process), `$PPID` refers to the terminal application itself. Since the curl process terminates after execution, passing the terminal's process ID (`$PPID`) allows Notifier to correctly activate the terminal window when you click the notification banner.

## Permissions

1. Notification: Needed, for posting Notification
2. Accessibility: Optional, for activating the source app according to the pid you passed in, if you don't need the activation, you needn't grant this permission.

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

## License
GNU General Public License v3.0
