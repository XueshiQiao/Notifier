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
    "PreToolUse": [
      {
        "matcher": "Read|Bash|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "INPUT=$(cat) && TOOL=$(echo \"$INPUT\" | jq -r '.tool_name // \"Tool\"') && BODY=$(echo \"$INPUT\" | jq -r 'if .tool_input.file_path then .tool_input.file_path elif .tool_input.command then (.tool_input.command | tostring | .[0:100]) else .tool_name end') && BODY=$(echo \"$BODY\" | sed \"s|$HOME|~|\") && curl -s -o /dev/null -X POST http://localhost:8000 -H 'Content-Type: application/json' -d \"$(jq -n --arg title 'Claude Code' --arg body \"$TOOL: $BODY\" --arg pid \"$PPID\" '{title: $title, body: $body, pid: ($pid | tonumber)}')\""
          }
        ]
      }
    ],
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
| `PreToolUse` | Immediately before a tool runs (Read, Bash, Edit, Write) | Shows the tool name and file path or command |
| `Notification` | Claude needs attention (idle prompts, etc.) | Shows the message from Claude |
| `Stop` | Claude finishes responding | "Task finished" |

All hooks pass the terminal's PID (`$PPID`) to Notifier. When you click a notification, Notifier brings your terminal window to the front — even if it was minimized.

> **Note:** The `PreToolUse` hook fires for **every** matched tool call, including auto-approved ones. If notifications are too frequent, narrow the matcher (e.g. just `"Bash"`) or remove it entirely — the `Notification` hook still covers permission prompts after a short delay.

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
