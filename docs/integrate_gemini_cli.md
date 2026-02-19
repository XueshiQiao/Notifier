# Integrate Notifier with Gemini CLI

Get native macOS notifications when Gemini CLI needs your permission or has a question for you.

## Prerequisites

- Notifier app running with the HTTP server started
- [Gemini CLI](https://github.com/google-gemini/gemini-cli) installed
- Python 3 available in your shell

## Setup

### 1. Create the notification script

Save the following script to `~/.gemini/scripts/notify_via_app.py`:

```python
#!/usr/bin/env python3
import json
import os
import re
import sys
import urllib.request


def send_notification(payload):
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        "http://localhost:8000/",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=1):
        pass


def allow_and_exit():
    sys.stdout.write(json.dumps({"decision": "allow"}))


try:
    input_data = sys.stdin.read()
    if not input_data:
        allow_and_exit()
        raise SystemExit(0)

    try:
        incoming = json.loads(input_data)
    except Exception:
        allow_and_exit()
        raise SystemExit(0)

    tool_name = incoming.get("tool_name")
    event_name = incoming.get("hook_event_name", "Notification")

    title = "Gemini CLI"
    body = "Action Required"
    subtitle = ""
    should_notify = False

    if event_name == "Notification" and incoming.get("notification_type") == "ToolPermission":
        should_notify = True
        details = incoming.get("details") or {}
        subtitle = "Permission Requested"

        command = details.get("command")
        file_path = details.get("filePath")
        message = incoming.get("message")

        if command:
            body = f"Run: {command}"
        elif file_path:
            action = "Edit" if details.get("type") == "edit" else "Write"
            body = f"{action}: {os.path.basename(file_path)}"
            directory = os.path.dirname(file_path)
            if directory and directory != ".":
                subtitle = directory.replace(os.environ.get("HOME", ""), "~")
        elif message:
            body = re.sub(r" requires (editing|execution)$", "", re.sub(r"^Tool ", "", message))

    elif tool_name == "ask_user":
        should_notify = True
        questions = ((incoming.get("tool_input") or {}).get("questions")) or []
        first_question = questions[0] if questions else {}
        body = first_question.get("question") or "The agent has a question for you."
        header = first_question.get("header")
        subtitle = f"Question: {header}" if header else "User Choice Requested"

    if should_notify:
        pid = None
        if len(sys.argv) > 1:
            try:
                pid = int(sys.argv[1])
            except ValueError:
                pid = None

        try:
            send_notification({
                "title": title,
                "body": body,
                "subtitle": subtitle,
                "pid": pid
            })
        except Exception:
            pass

except Exception:
    pass

allow_and_exit()
```

Make the script executable:

```bash
chmod +x ~/.gemini/scripts/notify_via_app.py
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
            "command": "~/.gemini/scripts/notify_via_app.py $PPID"
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
            "command": "~/.gemini/scripts/notify_via_app.py $PPID"
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
