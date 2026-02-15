# Setting Up Tests in Xcode

## Problem
If you see "No such module 'XCTest'" when running the main app, it means the test file is incorrectly added to the main app target.

## Solution

### Step 1: Check Target Membership

1. Select **NotifierTests.swift** in Project Navigator
2. Open File Inspector (⌘⌥1)
3. Look at **Target Membership** section
4. The file should be:
   - ☑️ **NotifierTests** target (checked)
   - ☐️ **Notifier** target (UNCHECKED)

### Step 2: Create Test Target (if it doesn't exist)

1. **File → New → Target...**
2. Select **macOS** tab
3. Choose **Unit Testing Bundle**
4. Click **Next**
5. **Product Name**: NotifierTests
6. **Team**: (your team)
7. **Project**: Notifier
8. **Test Target**: Notifier
9. Click **Finish**

### Step 3: Add Test File to Test Target

1. Select **NotifierTests.swift**
2. In File Inspector, check **Target Membership**
3. Ensure only **NotifierTests** is checked
4. Uncheck **Notifier** if it's checked

### Step 4: Configure Test Target

Make sure your test target can access the main app:

1. Select **NotifierTests** target
2. Go to **Build Phases**
3. Expand **Dependencies**
4. Click **+** and add **Notifier** app target

### Step 5: Run Tests

- Press **⌘U** to run all tests
- Or click the diamond icon next to individual tests

## Quick Fix: Skip Tests for Now

If you just want to run the app without tests:

### Option A: Remove Test File Reference
1. Right-click **NotifierTests.swift**
2. **Delete**
3. Choose **Remove Reference** (not "Move to Trash")

### Option B: Don't Build Tests
1. Product → Scheme → Edit Scheme
2. Uncheck **Test** in the left sidebar
3. Now ⌘R will only build and run the app

## File Organization

```
Notifier/                    ← Main app target
├── NotifierApp.swift       ✅ Main target
├── ContentView.swift       ✅ Main target
├── HTTPServer.swift        ✅ Main target
├── NotificationRequest.swift   ✅ Main target
└── NotificationManager.swift   ✅ Main target

NotifierTests/              ← Test target only
└── NotifierTests.swift     ✅ Test target ONLY
```

## What Went Wrong?

When creating the test file, it was likely added to both targets. XCTest framework is only available in test targets, not in the main app target.

## Verify It's Fixed

Build the main app (⌘B):
- ✅ Should compile without "No such module 'XCTest'" error
- ✅ App should run normally (⌘R)

Run tests (⌘U):
- ✅ Tests should run and pass
