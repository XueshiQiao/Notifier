# TTY-Based Terminal Tab Activation

## Overview

When working with multiple Terminal tabs, you can now specify a `tty` parameter in your notification request. When the notification is clicked, it will activate the specific Terminal tab with that TTY, not just the Terminal app.

## How It Works

### Request Format

```json
{
  "title": "Notification Title",
  "body": "Notification message",
  "subtitle": "Optional subtitle",
  "pid": 12345,
  "tty": "/dev/ttys003"
}
```

### Flow

```
1. Send notification with PID and TTY
2. User clicks notification
3. Code finds parent app (Terminal.app)
4. AppleScript iterates through all Terminal windows and tabs
5. Finds tab with matching TTY
6. Activates that specific tab
```

## Getting Your Terminal's TTY

### Method 1: `tty` command
```bash
tty
# Output: /dev/ttys003
```

### Method 2: In your script
```bash
CURRENT_TTY=$(tty)
echo "My TTY is: $CURRENT_TTY"
```

### Method 3: `ps` command
```bash
ps -p $$ -o tty=
```

## Usage Examples

### Example 1: Return to Current Terminal Tab

```bash
# Get current TTY and PID
CURRENT_TTY=$(tty)
CURRENT_PID=$$

# Send notification
curl -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Back to Terminal\",\"body\":\"Click to return to $CURRENT_TTY\",\"pid\":$CURRENT_PID,\"tty\":\"$CURRENT_TTY\"}"
```

### Example 2: Long-Running Task

```bash
#!/bin/bash

MY_TTY=$(tty)
MY_PID=$$

echo "Starting long task in $MY_TTY..."

# Do some work
sleep 10
./build.sh

# Notify when done
curl -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Build Complete\",\"body\":\"Click to return to your terminal\",\"pid\":$MY_PID,\"tty\":\"$MY_TTY\"}"
```

### Example 3: Function for Easy Reuse

```bash
notify_this_terminal() {
    local title="$1"
    local body="$2"
    local tty=$(tty)
    local pid=$$
    
    curl -X POST http://localhost:8000 \
      -H "Content-Type: application/json" \
      -d "{\"title\":\"$title\",\"body\":\"$body\",\"pid\":$pid,\"tty\":\"$tty\"}"
}

# Usage
./long_task.sh
notify_this_terminal "Task Complete" "Your build is ready!"
```

## AppleScript Details

The code uses this AppleScript to activate the specific tab:

```applescript
tell application "Terminal"
    activate
    repeat with w in windows
        repeat with t in tabs of w
            if tty of t as string is "/dev/ttys003" then
                set selected of t to true    -- Switch to this tab
                set frontmost of w to true   -- Bring window to front
                set index of w to 1          -- Move window to front
                return
            end if
        end repeat
    end repeat
end tell
```

### What It Does:

1. **Activates Terminal.app** - Brings Terminal to the foreground
2. **Iterates through windows** - Checks all Terminal windows
3. **Iterates through tabs** - Checks all tabs in each window
4. **Finds matching TTY** - Compares each tab's TTY with the target
5. **Selects the tab** - Makes it the active tab in its window
6. **Brings window forward** - Ensures the window is visible
7. **Moves to front** - Sets window index to 1 (topmost)

## Use Cases

### 1. Multi-Tab Development Workflow

```bash
# Tab 1: Frontend development
cd ~/project/frontend
FRONTEND_TTY=$(tty)

# Tab 2: Backend development  
cd ~/project/backend
BACKEND_TTY=$(tty)

# In Tab 1, run build and notify
npm run build && \
curl -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Frontend Build Done\",\"body\":\"Click to return\",\"pid\":$$,\"tty\":\"$FRONTEND_TTY\"}"
```

### 2. SSH Sessions

```bash
# Keep track of which SSH session you're in
ssh user@server
MY_TTY=$(tty)
MY_PID=$$

# Run long command
./deploy.sh

# Notify when done
curl -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Deployment Complete\",\"body\":\"SSH session $MY_TTY\",\"pid\":$MY_PID,\"tty\":\"$MY_TTY\"}"
```

### 3. Parallel Tasks

```bash
# Terminal Tab 1
tty  # /dev/ttys003
./task1.sh && notify "Task 1 Done" "ttys003"

# Terminal Tab 2
tty  # /dev/ttys004
./task2.sh && notify "Task 2 Done" "ttys004"

# Terminal Tab 3
tty  # /dev/ttys005
./task3.sh && notify "Task 3 Done" "ttys005"
```

## Testing

### Quick Test

```bash
# Make the test script executable
chmod +x test_terminal_tty.sh

# Run it
./test_terminal_tty.sh

# Switch to another Terminal tab or app
# Click the notification
# You'll be brought back to the exact tab where you ran the script!
```

### Manual Test

```bash
# In Terminal Tab 1
echo "This is tab 1"
tty  # Note the TTY, e.g., /dev/ttys003
CURRENT_TTY=$(tty)

# Switch to Terminal Tab 2
echo "This is tab 2"

# From Tab 2, send notification with Tab 1's TTY
curl -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Go to Tab 1\",\"body\":\"Click me\",\"pid\":$$,\"tty\":\"/dev/ttys003\"}"

# Click the notification → Tab 1 activates!
```

## Troubleshooting

### TTY not found in Terminal

**Symptom**: Notification activates Terminal but doesn't switch tabs

**Possible causes**:
1. TTY string doesn't match exactly
2. Terminal tab was closed
3. TTY changed (rare, but can happen)

**Solution**:
```bash
# Verify your TTY
tty

# Check it matches what you're sending
echo "Sending TTY: /dev/ttys003"
```

### AppleScript permission denied

**Symptom**: Error in console about AppleScript

**Solution**:
1. System Settings → Privacy & Security → Automation
2. Find your Notifier app
3. Enable Terminal.app access

### Tab doesn't activate

**Symptom**: Terminal activates but wrong tab is selected

**Solutions**:
1. Make sure the TTY is still active: `ps -t /dev/ttys003`
2. Close and reopen Terminal if TTYs are stale
3. Check console logs for AppleScript errors

## Advanced Usage

### Function Library

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# Notify current terminal tab
notify_here() {
    local title="$1"
    local body="${2:-Notification from $(tty)}"
    curl -s -X POST http://localhost:8000 \
      -H "Content-Type: application/json" \
      -d "{\"title\":\"$title\",\"body\":\"$body\",\"pid\":$$,\"tty\":\"$(tty)\"}"
}

# Notify and return to this tab when command completes
notify_when_done() {
    "$@"
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        notify_here "✅ Command Complete" "$* finished successfully"
    else
        notify_here "❌ Command Failed" "$* failed with code $exit_code"
    fi
    return $exit_code
}

# Usage:
# notify_when_done ./long_build.sh
# notify_when_done npm test
```

### Python Integration

```python
import subprocess
import requests
import os

def get_tty():
    """Get the current TTY"""
    return subprocess.check_output(['tty']).decode().strip()

def notify_this_terminal(title, body):
    """Send notification that returns to this terminal tab"""
    tty = get_tty()
    pid = os.getpid()
    
    response = requests.post('http://localhost:8000', json={
        'title': title,
        'body': body,
        'pid': pid,
        'tty': tty
    })
    
    return response.status_code == 200

# Usage
import time
print("Starting long task...")
time.sleep(5)
notify_this_terminal("Task Complete", "Click to return to Python script")
```

## Benefits

✅ **Precise tab targeting** - Not just "any Terminal tab"
✅ **Multi-tab workflows** - Work in multiple tabs simultaneously  
✅ **Context preservation** - Return exactly where you were
✅ **No manual searching** - No need to find the right tab
✅ **Works with many tabs** - Even with 10+ tabs open

## Limitations

- Only works with macOS Terminal.app
- Does not work with iTerm2 (uses different AppleScript API)
- Requires Terminal.app automation permission
- TTYs can be recycled if terminal is closed and reopened

## Future Enhancements

Potential additions:
- iTerm2 support (different AppleScript)
- Window positioning
- Tab title matching as fallback
- Session ID support
