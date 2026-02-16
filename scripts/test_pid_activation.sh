#!/bin/bash

# Example script showing how to use the PID parameter
# This will send a notification that, when clicked, will activate the specified app

echo "🔍 Finding running applications and their PIDs..."
echo ""

# Show some common apps and their PIDs
echo "Common running apps:"
ps aux | grep -E "(Safari|Chrome|Firefox|Code|Terminal|Xcode)" | grep -v grep | awk '{printf "%-30s PID: %s\n", $11, $2}' | head -10

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Example 1: Get Safari's PID and send notification
SAFARI_PID=$(pgrep -x "Safari" | head -1)

if [ ! -z "$SAFARI_PID" ]; then
    echo "Example 1: Sending notification that will activate Safari (PID: $SAFARI_PID)"
    curl -X POST http://localhost:8000 \
      -H "Content-Type: application/json" \
      -d "{\"title\":\"Switch to Safari\",\"body\":\"Click this notification to activate Safari\",\"pid\":$SAFARI_PID}"
    echo -e "\n"
else
    echo "Safari is not running. Skipping Safari example."
fi

sleep 2

# Example 2: Get Terminal's PID and send notification
TERMINAL_PID=$(pgrep -x "Terminal" | head -1)

if [ ! -z "$TERMINAL_PID" ]; then
    echo "Example 2: Sending notification that will activate Terminal (PID: $TERMINAL_PID)"
    curl -X POST http://localhost:8000 \
      -H "Content-Type: application/json" \
      -d "{\"title\":\"Back to Terminal\",\"body\":\"Click to return to Terminal\",\"pid\":$TERMINAL_PID}"
    echo -e "\n"
else
    echo "Terminal is not running. Using current shell PID: $$"
    curl -X POST http://localhost:8000 \
      -H "Content-Type: application/json" \
      -d "{\"title\":\"Back to Terminal\",\"body\":\"Click to return to Terminal\",\"pid\":$$}"
    echo -e "\n"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📱 Notifications sent! Click them to activate the corresponding app."
echo ""
echo "💡 To get a specific app's PID, use:"
echo "   pgrep -x \"AppName\""
echo ""
echo "💡 To list all running apps with PIDs:"
echo "   ps aux | grep -i \"appname\""
