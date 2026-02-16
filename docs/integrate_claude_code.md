# Integrate Notifier with Claude Code

Get native macOS notifications when Claude Code finishes a task or needs your attention.

## Prerequisites

- Notifier app running with the HTTP server started
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- `jq` and `curl` available in your shell

## Setup

Add the following hooks to your Claude Code settings file at `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "MSG=$(cat | jq -r '.message // \"Claude needs your attention\"') && curl -s -X POST http://localhost:8000 -H 'Content-Type: application/json' -d \"$(jq -n --arg title 'Claude Code' --arg body \"$MSG\" --arg pid \"$PPID\" '{title: $title, body: $body, pid: ($pid | tonumber)}')\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "curl -s -X POST http://localhost:8000 -H 'Content-Type: application/json' -d \"$(jq -n --arg pid \"$PPID\" '{title: \"Claude Code\", body: \"Task finished\", pid: ($pid | tonumber)}')\""
          }
        ]
      }
    ]
  }
}
```

> If you already have other settings in this file, merge the `hooks` section into your existing config.

Restart your Claude Code session for the hooks to take effect.

## How It Works

| Hook | When it fires | Notification |
|------|--------------|--------------|
| `Notification` | Claude needs attention (permission prompts, idle prompts, etc.) | Shows the message from Claude |
| `Stop` | Claude finishes responding | "Task finished" |

Both hooks pass the terminal's PID (`$PPID`) to Notifier. When you click a notification, Notifier brings your terminal window to the front — even if it was minimized.

## Custom Port

If you changed the Notifier port from the default `8000`, update the `localhost:8000` in both hook commands to match.

## Test

With Notifier running, send a test notification from your terminal:

```bash
curl -s -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","body":"Hello from Claude Code","pid":'$$'}'
```

## API Reference

The Notifier HTTP server accepts POST requests with a JSON body:

```json
{
  "title": "Notification title",
  "body": "Notification body",
  "subtitle": "Optional subtitle",
  "pid": 12345
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | yes | Notification title |
| `body` | string | yes | Notification body text |
| `subtitle` | string | no | Optional subtitle |
| `pid` | integer | no | PID of the app to activate when notification is clicked |
