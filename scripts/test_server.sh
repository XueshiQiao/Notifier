#!/bin/bash

# Test script for Notifier HTTP Server
# Make sure the Notifier app is running before executing this script

echo "🧪 Testing Notifier HTTP Server on localhost:8000"
echo "=================================================="
echo ""

# Test 1: Valid notification with all fields
echo "Test 1: Sending notification with title, body, and subtitle..."
curl -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Notification",
    "body": "This is a test message from the curl script",
    "subtitle": "Test Subtitle"
  }'
echo -e "\n"

sleep 2

# Test 2: Valid notification without subtitle
echo "Test 2: Sending notification without subtitle..."
curl -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Second Test",
    "body": "This notification has no subtitle"
  }'
echo -e "\n"

sleep 2

# Test 3: Invalid request - empty title
echo "Test 3: Sending invalid request (empty title) - should fail..."
curl -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d '{
    "title": "",
    "body": "This should fail"
  }'
echo -e "\n"

sleep 2

# Test 4: Invalid request - missing body
echo "Test 4: Sending invalid request (missing body) - should fail..."
curl -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Only Title"
  }'
echo -e "\n"

sleep 2

# Test 5: Invalid request - not POST
echo "Test 5: Sending GET request - should fail..."
curl -X GET http://localhost:8000
echo -e "\n"

sleep 2

# Test 6: Invalid JSON
echo "Test 6: Sending invalid JSON - should fail..."
curl -X POST http://localhost:8000 \
  -H "Content-Type: application/json" \
  -d 'not valid json'
echo -e "\n"

echo ""
echo "=================================================="
echo "✅ Testing complete!"
echo "Check your notifications to see if they appeared."
