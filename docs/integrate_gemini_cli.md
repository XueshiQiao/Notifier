# Integrate Notifier with Gemini CLI

Get native macOS notifications when Gemini CLI needs your permission or has a question for you.

## Prerequisites

- Notifier app running with the HTTP server started
- [Gemini CLI](https://github.com/google-gemini/gemini-cli) installed
- Node.js available in your shell

## Setup

### 1. Create the notification script

Save the following script to `~/.gemini/scripts/notify_via_app.js`:

```js
#!/usr/bin/env node
const http = require('http');
const fs = require('fs');
const path = require('path');

function sendNotification(data) {
    const postData = JSON.stringify(data);

    const options = {
        hostname: 'localhost',
        port: 8000,
        path: '/',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(postData)
        }
    };

    const req = http.request(options, (res) => {
        res.on('data', () => {});
    });

    req.on('error', () => {});

    req.write(postData);
    req.end();
}

try {
    const inputData = fs.readFileSync(0, 'utf8');
    if (!inputData) {
        process.stdout.write(JSON.stringify({ decision: "allow" }));
        return;
    }

    let input;
    try {
        input = JSON.parse(inputData);
    } catch (e) {
        process.stdout.write(JSON.stringify({ decision: "allow" }));
        return;
    }

    const toolName = input.tool_name;
    const eventName = input.hook_event_name || "Notification";

    let title = "Gemini CLI";
    let body = "Action Required";
    let subtitle = "";
    let shouldNotify = false;

    if (eventName === "Notification" && input.notification_type === "ToolPermission") {
        shouldNotify = true;
        const details = input.details || {};
        subtitle = "Permission Requested";

        if (details.command) {
            body = `Run: ${details.command}`;
        } else if (details.filePath) {
            const action = details.type === 'edit' ? 'Edit' : 'Write';
            body = `${action}: ${path.basename(details.filePath)}`;
            const dir = path.dirname(details.filePath);
            if (dir && dir !== '.') {
                subtitle = dir.replace(process.env.HOME, '~');
            }
        } else if (input.message) {
            body = input.message.replace(/^Tool /, "").replace(/ requires (editing|execution)$/, "");
        }
    } else if (toolName === "ask_user") {
        shouldNotify = true;
        const questions = input.tool_input?.questions || [];
        const firstQ = questions[0] || {};
        body = firstQ.question || "The agent has a question for you.";
        subtitle = firstQ.header ? `Question: ${firstQ.header}` : "User Choice Requested";
    }

    if (shouldNotify) {
        const pidArg = process.argv[2];
        let pid = null;
        if (pidArg) {
            const parsed = parseInt(pidArg, 10);
            if (!isNaN(parsed)) {
                pid = parsed;
            }
        }

        sendNotification({
            title: title,
            body: body,
            subtitle: subtitle,
            pid: pid
        });
    }

} catch (e) {
    // ignore errors
} finally {
    process.stdout.write(JSON.stringify({ decision: "allow" }));
}
```

Make the script executable:

```bash
chmod +x ~/.gemini/scripts/notify_via_app.js
```

### 2. Add hooks to Gemini CLI settings

Add the following `hooks` section to your `~/.gemini/settings.json`:

```json
{
  "hooks": {
    "BeforeTool": [
      {
        "matcher": "ask_user|run_shell_command|write_file|replace|delete_file",
        "hooks": [
          {
            "type": "command",
            "name": "BeforeTool Notification",
            "command": "~/.gemini/scripts/notify_via_app.js $PPID"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "ToolPermission",
        "hooks": [
          {
            "type": "command",
            "name": "Notification",
            "command": "~/.gemini/scripts/notify_via_app.js $PPID"
          }
        ]
      }
    ]
  }
}
```

> If you already have other settings in this file, merge the `hooks` section into your existing config.

Restart your Gemini CLI session for the hooks to take effect.

## How It Works

| Hook | Matcher | When it fires | Notification |
|------|---------|---------------|--------------|
| `BeforeTool` | `ask_user\|run_shell_command\|write_file\|replace\|delete_file` | Before a tool that needs permission runs | Shows what the tool wants to do (run a command, edit a file, etc.) |
| `Notification` | `ToolPermission` | Gemini requests explicit tool permission | Shows the permission details |

Gemini CLI pipes a JSON object into the script via stdin. The script parses the event, builds a human-readable notification body, and POSTs it to Notifier's HTTP server.

Both hooks pass the terminal's PID (`$PPID`) as a command-line argument. When you click a notification, Notifier brings your terminal window to the front.

## Custom Port

If you changed the Notifier port from the default `8000`, update the `port` value in the `sendNotification` function inside the script.

## Test

With Notifier running, send a test notification from your terminal:

```bash
curl -s -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d '{"title":"Gemini CLI","body":"Hello from Gemini CLI","pid":'$$'}'
```

## API Reference

The Notifier HTTP server accepts POST requests with a JSON body:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | yes | Notification title |
| `body` | string | yes | Notification body text |
| `subtitle` | string | no | Optional subtitle |
| `callback_url` | string | no | URL scheme callback opened directly when notification is clicked (takes priority over `pid`) |
| `pid` | integer | no | PID of the app to activate when notification is clicked; also used to parse and attach source app icon in notification content |
