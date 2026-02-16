#!/bin/bash

# Script to demonstrate TTY-based Terminal tab activation
# When you click the notification, it will activate the specific Terminal tab

echo "🖥️  Terminal Tab Activation Demo"
echo "================================"
echo ""

# Get the current TTY
CURRENT_TTY=$(tty)
echo "📍 Current TTY: $CURRENT_TTY"

# Get the current shell's PID
CURRENT_PID=94673 #$$
echo "📍 Current PID: $CURRENT_PID"

echo ""
echo "Sending notification with TTY and PID..."
echo ""

# Send notification with both PID and TTY
curl -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Back to This Terminal Tab\",\"body\":\"Click to return to $CURRENT_TTY\",\"subtitle\":\"Terminal Activation\",\"pid\":$CURRENT_PID,\"tty\":\"$CURRENT_TTY\"}"

echo ""
echo ""
echo "✅ Notification sent!"
echo ""
echo "💡 Now:"
echo "   1. Switch to another app or Terminal tab"
echo "   2. Click the notification"
echo "   3. This exact Terminal tab will be activated!"
echo ""
