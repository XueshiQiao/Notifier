#!/usr/bin/env python3

"""
Test script for Notifier HTTP Server
Make sure the Notifier app is running before executing this script
"""

import requests
import json
import time

SERVER_URL = "http://localhost:8000"

def test_notification(test_name, data, should_succeed=True):
    """Send a test notification and print the result"""
    print(f"\n{'='*60}")
    print(f"Test: {test_name}")
    print(f"{'='*60}")
    print(f"Sending: {json.dumps(data, indent=2)}")
    
    try:
        response = requests.post(SERVER_URL, json=data)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        
        if should_succeed:
            if response.status_code == 200:
                print("✅ Success!")
            else:
                print("❌ Expected success but got error")
        else:
            if response.status_code != 200:
                print("✅ Failed as expected!")
            else:
                print("❌ Expected failure but succeeded")
                
    except requests.exceptions.ConnectionError:
        print("❌ Connection failed! Is the Notifier app running?")
    except Exception as e:
        print(f"❌ Error: {e}")

def main():
    print("🧪 Testing Notifier HTTP Server")
    print(f"Server: {SERVER_URL}")
    
    # Test 1: Valid notification with all fields
    test_notification(
        "Valid notification with all fields",
        {
            "title": "Python Test",
            "body": "This is a test notification from Python",
            "subtitle": "Test Subtitle"
        },
        should_succeed=True
    )
    time.sleep(2)
    
    # Test 2: Valid notification without subtitle
    test_notification(
        "Valid notification without subtitle",
        {
            "title": "Python Test 2",
            "body": "This notification has no subtitle"
        },
        should_succeed=True
    )
    time.sleep(2)
    
    # Test 3: Empty title (should fail validation)
    test_notification(
        "Invalid - empty title",
        {
            "title": "",
            "body": "This should fail"
        },
        should_succeed=False
    )
    time.sleep(2)
    
    # Test 4: Missing body field
    test_notification(
        "Invalid - missing body",
        {
            "title": "Only Title"
        },
        should_succeed=False
    )
    time.sleep(2)
    
    # Test 5: Empty body (should fail validation)
    test_notification(
        "Invalid - empty body",
        {
            "title": "Test Title",
            "body": ""
        },
        should_succeed=False
    )
    time.sleep(2)
    
    # Test 6: Extra fields (should still work)
    test_notification(
        "Valid with extra fields",
        {
            "title": "Test with extras",
            "body": "This has extra fields",
            "subtitle": "Subtitle",
            "extra_field": "This will be ignored"
        },
        should_succeed=True
    )
    
    print(f"\n{'='*60}")
    print("✅ Testing complete!")
    print("Check your notifications to see if they appeared.")
    print(f"{'='*60}\n")

if __name__ == "__main__":
    main()
