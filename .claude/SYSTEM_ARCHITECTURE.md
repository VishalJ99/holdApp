# Hold - System Architecture

## Mission Statement

Hold is a focus tool that helps you stay committed to ONE task at a time. Capture your current task on Mac with a quick keyboard shortcut, and see it instantly displayed on your iPhone. No lists, no distractions—just your current focus, always visible. Built with CloudKit for real-time sync across your devices with zero setup.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                            USER FLOW                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Mac (Input)                CloudKit (Sync)         iPhone (Output)│
│  ┌──────────┐              ┌──────────┐             ┌──────────┐  │
│  │ Cmd+     │              │ Database │             │          │  │
│  │ Shift+   │──Save Task──>│  Task    │──Push──────>│ Display  │  │
│  │ Space    │              │ Records  │ Notification│ Current  │  │
│  │          │              │          │             │ Task     │  │
│  │ Type &   │              │Subscription│            │          │  │
│  │ Enter    │              │ Triggers  │            │ Center   │  │
│  └──────────┘              └──────────┘             │ Aligned  │  │
│                                                      └──────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### Core Flow:
1. **Capture** (Mac): User presses Cmd+Shift+Space → Types task → Hits Enter
2. **Save** (Mac): Task saved to CloudKit public database as a CKRecord
3. **Detect** (CloudKit): Subscription detects new Task record creation
4. **Notify** (CloudKit → APNs): Silent push notification sent to subscribed iPhone
5. **Fetch** (iPhone): App receives notification → Fetches latest task
6. **Display** (iPhone): UI updates to show new task (< 1 second end-to-end)

---

## Component Architecture

### Mac App (HoldApp Target)

**Entry Point**: `HoldApp/AppDelegate.swift`

**Purpose**: Capture bar UI and CloudKit write operations

#### Key Components:

**`AppDelegate.swift`** (`HoldApp/AppDelegate.swift`)
- **Responsibility**: App lifecycle, component initialization, task capture callback
- **Key Logic**:
  - Initializes Spotlight UI, hotkey manager, and LogManager
  - Handles `onEnterPressed` callback: saves task to CloudKit
  - Coordinates between UI (SpotlightViewController) and data layer (CloudKitManager)
- **Lines to Note**:
  - Line 29-43: Task capture flow - when user presses Enter, saves to CloudKit
  - Line 31: `CloudKitManager.shared.saveTask()` - the write operation

**`HotkeyManager.swift`** (`HoldApp/HotkeyManager.swift`)
- **Responsibility**: Global keyboard shortcut registration (Cmd+Shift+Space)
- **Key Logic**:
  - Uses Carbon API to register system-wide hotkeys
  - Triggers show/hide callbacks for Spotlight panel
  - Currently registers Cmd+Shift+Space (lines 23-28)

**`SpotlightViewController.swift`** (`HoldApp/SpotlightViewController.swift`)
- **Responsibility**: The capture bar UI (text field, appearance)
- **Key Logic**:
  - NSViewController with single text field
  - Handles Enter key press → fires `onEnterPressed` callback
  - Handles Escape key → fires `onEscapePressed` callback
  - Placeholder text: "What task are you holding?" (line showing placeholder)

**`SpotlightPanel.swift`** (`HoldApp/SpotlightPanel.swift`)
- **Responsibility**: The floating window that contains the capture bar
- **Key Logic**:
  - NSPanel configured as borderless, floating window
  - `show()`: Centers on screen, activates app, focuses text field
  - `hide()`: Closes window, clears text field
  - Level: `.floating` so it appears above all windows

**`LogManager.swift`** (`HoldApp/LogManager.swift`)
- **Responsibility**: Legacy backup logging (currently broken, not critical)
- **Status**: ⚠️ DEPRECATED - Attempts to write to `/logs.json` (read-only location)
- **Note**: Safe to remove - CloudKit is the single source of truth

---

### iOS App (HoldApp-iOS Target)

**Entry Point**: `HoldApp-iOS/HoldApp_iOSApp.swift`

**Purpose**: Display UI and CloudKit read operations with push notification handling

#### Key Components:

**`HoldApp_iOSApp.swift`** (`HoldApp-iOS/HoldApp_iOSApp.swift`)
- **Responsibility**: App lifecycle, APNs registration, notification permission, push notification handling
- **Key Logic**:
  - **Lines 24-36**: App launch - requests notification permission
  - **Lines 38-60**: `requestNotificationPermission()` - UNUserNotificationCenter authorization
  - **Lines 62-67**: `didRegisterForRemoteNotificationsWithDeviceToken` - APNs success callback (logs device token)
  - **Lines 69-72**: `didFailToRegisterForRemoteNotificationsWithError` - APNs failure callback
  - **Lines 74-83**: `didReceiveRemoteNotification` - **CRITICAL** - receives CloudKit push notifications
- **Push Notification Flow**:
  1. Request permission (line 42)
  2. If granted → Register with APNs (line 54)
  3. Receive device token (line 62) or error (line 69)
  4. When CloudKit notification arrives → Line 77: Post local notification "CloudKitTaskUpdated"

**`ContentView.swift`** (`HoldApp-iOS/ContentView.swift`)
- **Responsibility**: The iPhone display UI and subscription setup
- **Key Logic**:
  - **Lines 16-33**: SwiftUI view - displays `currentTask` centered on black background
  - **Lines 34-38**: `onAppear` - initializes subscription and fetches current task
  - **Lines 40-59**: `fetchCurrentTask()` - queries CloudKit for latest incomplete task
  - **Lines 61-86**: `setupCloudKitSubscription()` - **CRITICAL**:
    - Creates CKQuerySubscription for Task records (line 65)
    - Registers NotificationCenter observer for "CloudKitTaskUpdated" (line 74)
    - When notification received → Triggers `fetchCurrentTask()` (line 82)
- **State Management**:
  - `@State private var currentTask: String` - The displayed task text
  - `@State private var isLoading: Bool` - Loading indicator state

---

### Shared Layer (Both Targets)

**`CloudKitManager.swift`** (`HoldApp/CloudKitManager.swift`)

- **Target Membership**: ✅ HoldApp (Mac) + ✅ HoldApp-iOS (iPhone)
- **Responsibility**: All CloudKit operations - save, fetch, subscribe
- **Key Logic**:

  **Initialization (Lines 8-13)**:
  ```swift
  container = CKContainer.default()              // iCloud.com.vishaljain.HoldApp
  database = container.publicCloudDatabase       // Public database
  ```
  - Uses default CloudKit container (configured in entitlements)
  - Uses public database (records still user-scoped by CloudKit automatically)

  **`saveTask()` (Lines 16-36)**:
  - Creates `CKRecord(recordType: "Task")`
  - Sets fields: `text`, `timestamp`, `isCompleted`
  - Saves to database
  - **Called from**: Mac AppDelegate when user presses Enter
  - **Logs**: Save duration, record ID

  **`fetchCurrentTask()` (Lines 39-62)**:
  - Queries: `recordType == "Task" AND isCompleted == false`
  - Sorts by: `timestamp` descending (most recent first)
  - Returns: First result (latest incomplete task)
  - **Called from**: iPhone ContentView on app launch and notification
  - **Logs**: Fetch duration, task text, record ID

  **`subscribeToTaskChanges()` (Lines 65-95)**:
  - Creates `CKQuerySubscription` for "Task" records
  - Options: `.firesOnRecordCreation`, `.firesOnRecordUpdate`
  - Notification: `shouldSendContentAvailable = true` (silent push)
  - **Called from**: iPhone ContentView on first launch
  - **Logs**: Subscription configuration, success/failure, subscription ID
  - **Critical**: This links the iPhone's device token to CloudKit's notification system

---

## Data Flow & Synchronization

### Task Capture Flow (Mac → CloudKit):

```
User Input                    Mac App                    CloudKit
─────────────────────────────────────────────────────────────────
1. Press Cmd+Shift+Space  →  HotkeyManager detects
2. Spotlight bar appears  →  SpotlightPanel.show()
3. Type "Buy groceries"   →  SpotlightViewController
4. Press Enter            →  onEnterPressed callback
                          →  AppDelegate line 31
                          →  CloudKitManager.saveTask()
5. Create CKRecord        →  recordType: "Task"
                          →  text: "Buy groceries"
                          →  timestamp: Date()
                          →  isCompleted: false
6. Save to database       →  database.save(record)     → CloudKit receives
                                                        → Record stored
                                                        → Triggers subscriptions
```

**Timing**: ~1-2 seconds for CloudKit save to complete

### Push Notification Flow (CloudKit → iPhone):

```
CloudKit Server              APNs                      iPhone App
─────────────────────────────────────────────────────────────────
1. Task record saved     →  Check subscriptions
2. Find subscription ID  →  "55C508DF-..."
3. Get device token      →  "d87224f72212ec54..."
4. Send push             →  APNs servers          →  iPhone receives
5. Silent notification   →                        →  didReceiveRemoteNotification
6. Post local notif      →                        →  "CloudKitTaskUpdated"
7. ContentView observes  →                        →  Triggers fetchCurrentTask()
8. Query CloudKit        →  Fetch latest task     ←  database.perform(query)
9. Update UI             →                        →  Display "Buy groceries"
```

**Timing**: < 1 second after subscription activates (5-15 min activation on first registration)

### User Isolation (Multi-User):

```
CloudKit Automatic Scoping
──────────────────────────────────────────────────────────────
User A (john@icloud.com):
  Mac saves task → CloudKit adds: record.createdBy = john@icloud.com
  iPhone subscribes → CloudKit links: subscription → john@icloud.com → device token
  iPhone fetches → CloudKit filters: WHERE createdBy == john@icloud.com

User B (sarah@icloud.com):
  Mac saves task → CloudKit adds: record.createdBy = sarah@icloud.com
  iPhone subscribes → CloudKit links: subscription → sarah@icloud.com → device token
  iPhone fetches → CloudKit filters: WHERE createdBy == sarah@icloud.com

Result: Users never see each other's data (automatic isolation by iCloud account)
```

---

## Key Technical Decisions

### 1. CloudKit Public Database
**Choice**: `container.publicCloudDatabase`
**Reasoning**:
- Records are automatically user-scoped by CloudKit
- No need for private database for single-user app
- Simpler permission model
- Future: Can add sharing if needed

**Alternative Considered**: Private database (more isolated but functionally identical for this use case)

### 2. CKQuerySubscription (Not Database Subscription)
**Choice**: `CKQuerySubscription(recordType: "Task", predicate: ...)`
**Reasoning**:
- Fine-grained control: only notify on Task record changes
- Can filter by predicate (currently matches all: `NSPredicate(value: true)`)
- Options: `.firesOnRecordCreation` and `.firesOnRecordUpdate`

**Alternative Considered**: `CKDatabaseSubscription` (too broad, would fire on all record types)

### 3. Silent Push Notifications
**Choice**: `shouldSendContentAvailable = true`, no alert/badge/sound
**Reasoning**:
- iPhone is a display, not an interactive app
- User shouldn't be interrupted by notification alerts
- App silently fetches and updates UI in background/foreground

**Alternative Considered**: Visible notifications (too intrusive for focus tool)

### 4. Single Task Display (Not Task List)
**Design**: iPhone shows only the MOST RECENT incomplete task
**Reasoning**:
- Mission: "ONE task at a time"
- Reduces cognitive load
- Simple, uncluttered display
- Query: `ORDER BY timestamp DESC LIMIT 1`

**Alternative Considered**: Task list (contradicts "single focus" mission)

### 5. Shared CloudKitManager via Target Membership
**Choice**: One `CloudKitManager.swift` file, added to both Mac and iOS targets
**Reasoning**:
- DRY: No code duplication
- Single source of truth for CloudKit operations
- Automatic consistency between platforms
- Same database object reference ensures coordination

**Alternative Considered**: Separate managers per platform (more code, harder to maintain)

### 6. Global Hotkey (Not Menu Bar)
**Choice**: Cmd+Shift+Space triggers capture bar anywhere
**Reasoning**:
- Fast access without mouse movement
- Inspired by Spotlight (familiar UX)
- Works across all apps (global registration)

**Alternative Considered**: Menu bar icon (requires mouse, slower)

---

## CloudKit Schema

### Record Type: "Task"

| Field Name   | Type      | Description                          |
|--------------|-----------|--------------------------------------|
| `text`       | String    | The task description                 |
| `timestamp`  | Date/Time | When task was created (for sorting)  |
| `isCompleted`| Boolean   | Completion status (always false MVP) |

**Indexes**:
- Default index on `timestamp` for sorting
- Default index on `isCompleted` for filtering

**Permissions**:
- Created by: User's iCloud account (automatic)
- Readable by: Creator only (CloudKit default)
- Writable by: Creator only (CloudKit default)

---

## Entitlements & Capabilities

### Mac App: `HoldApp/HoldApp.entitlements`
```xml
<key>com.apple.developer.aps-environment</key>
<string>development</string>  <!-- Auto-switches to production on App Store -->

<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.vishaljain.HoldApp</string>
</array>

<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>

<key>com.apple.security.app-sandbox</key>
<false/>  <!-- Disabled for global hotkey access -->
```

### iOS App: `HoldApp-iOS/HoldApp-iOS.entitlements`
```xml
<key>aps-environment</key>
<string>development</string>  <!-- APNs environment -->

<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.vishaljain.HoldApp</string>  <!-- Same container as Mac -->
</array>

<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
```

**Critical**: Both apps MUST use the same CloudKit container identifier for sync to work.

---

## APNs (Apple Push Notification Service) Architecture

### Registration Flow (iPhone Only):

1. **Permission Request** (`HoldApp_iOSApp.swift:42`)
   - `UNUserNotificationCenter.current().requestAuthorization()`
   - Shows iOS permission dialog: "Allow Notifications?"
   - Required before APNs registration

2. **APNs Registration** (`HoldApp_iOSApp.swift:54`)
   - `application.registerForRemoteNotifications()`
   - iOS contacts Apple's APNs servers
   - Returns device token (64-char hex string)

3. **Device Token Received** (`HoldApp_iOSApp.swift:62`)
   - `didRegisterForRemoteNotificationsWithDeviceToken`
   - Device token logged (e.g., "d87224f72212ec54...")
   - CloudKit automatically links this token to subscriptions

4. **Subscription Created** (`ContentView.swift:65`)
   - `CloudKitManager.shared.subscribeToTaskChanges()`
   - CloudKit links: subscription → user's iCloud account → device token
   - Subscription ID assigned (e.g., "55C508DF-...")

5. **Activation Period** (5-15 minutes)
   - CloudKit backend activates subscription (no callback)
   - After activation, push notifications start delivering

6. **Push Notification Delivery** (`HoldApp_iOSApp.swift:77`)
   - `didReceiveRemoteNotification` fires when CloudKit sends push
   - Posts local notification: `"CloudKitTaskUpdated"`
   - ContentView observes → Fetches latest task → Updates UI

**Important**: Mac app does NOT register for APNs (write-only, no subscriptions needed)

---

## Critical Code Paths

### 1. Task Capture (Mac)
**File**: `HoldApp/AppDelegate.swift`
**Lines**: 29-43
**Trigger**: User presses Enter in capture bar
**Action**: Saves task to CloudKit via `CloudKitManager.shared.saveTask()`

### 2. CloudKit Save (Shared)
**File**: `HoldApp/CloudKitManager.swift`
**Lines**: 16-36
**Trigger**: Called from Mac AppDelegate
**Action**: Creates CKRecord, saves to database, logs timing

### 3. Subscription Creation (iPhone)
**File**: `HoldApp-iOS/ContentView.swift`
**Lines**: 65-71
**Trigger**: `onAppear` (first app launch)
**Action**: Calls `CloudKitManager.shared.subscribeToTaskChanges()`

### 4. CloudKit Subscription (Shared)
**File**: `HoldApp/CloudKitManager.swift`
**Lines**: 65-95
**Trigger**: Called from iPhone ContentView
**Action**: Creates CKQuerySubscription, configures silent notification, saves to database

### 5. Push Notification Handler (iPhone)
**File**: `HoldApp-iOS/HoldApp_iOSApp.swift`
**Lines**: 74-83
**Trigger**: CloudKit sends push notification
**Action**: Posts "CloudKitTaskUpdated" to NotificationCenter

### 6. Notification Observer (iPhone)
**File**: `HoldApp-iOS/ContentView.swift`
**Lines**: 74-83
**Trigger**: Receives "CloudKitTaskUpdated" notification
**Action**: Calls `fetchCurrentTask()` to get latest task

### 7. CloudKit Fetch (Shared)
**File**: `HoldApp/CloudKitManager.swift`
**Lines**: 39-62
**Trigger**: Called from iPhone ContentView
**Action**: Queries CloudKit for latest incomplete task, updates UI state

---

## Development vs Production

### Development Environment (Current):
- **APNs**: `aps-environment = development`
- **CloudKit**: Development schema (separate from production)
- **Push Reliability**: Less reliable, 5-15 min subscription activation
- **Testing**: Xcode debugger, physical devices

### Production Environment (App Store):
- **APNs**: Automatically switches to `production`
- **CloudKit**: Production schema (deploy from CloudKit Dashboard)
- **Push Reliability**: Highly reliable, instant subscription activation
- **Distribution**: TestFlight → App Store

**Migration Steps**:
1. Deploy CloudKit schema to production (CloudKit Dashboard)
2. Archive both apps for production
3. Upload to App Store Connect
4. APNs environment switches automatically
5. Test on TestFlight before public release

---

## Known Issues & Technical Debt

### 1. LogManager (Mac Only)
**Status**: ⚠️ DEPRECATED
**Issue**: Attempts to write to `/logs.json` (read-only filesystem)
**Impact**: Error logged but app functions normally
**Fix**: Remove LogManager from AppDelegate.swift (lines 16, 21, 41)
**Reasoning**: CloudKit is single source of truth, file backup unnecessary

### 2. Subscription Activation Delay
**Status**: ⚠️ KNOWN LIMITATION
**Issue**: First-time subscription takes 5-15 minutes to activate
**Impact**: Push notifications don't work immediately on first install
**Workaround**: Wait or use polling fallback in DEBUG builds
**Fix**: None (Apple's CloudKit limitation in development)

### 3. No Task Completion
**Status**: 📝 FUTURE FEATURE
**Issue**: Tasks are never marked as `isCompleted = true`
**Impact**: All tasks persist in CloudKit indefinitely
**Future**: Add swipe gesture on iPhone to mark complete, cleanup old tasks

### 4. No Multi-Task Support
**Status**: 📝 FUTURE FEATURE
**Issue**: Only shows one task at a time
**Impact**: Can't queue or reorder tasks
**Future**: Add task list with arrow keys (Mac) or swipe (iPhone)

---

## File Structure Summary

```
HoldApp/
├── HoldApp/                          # Mac App Target
│   ├── AppDelegate.swift             # Mac app lifecycle, task capture coordinator
│   ├── HotkeyManager.swift           # Global keyboard shortcut (Cmd+Shift+Space)
│   ├── SpotlightViewController.swift # Capture bar UI (text field)
│   ├── SpotlightPanel.swift          # Floating window container
│   ├── LogManager.swift              # ⚠️ DEPRECATED file backup (broken)
│   ├── CloudKitManager.swift         # ✅ SHARED - All CloudKit operations
│   ├── Assets.xcassets/
│   │   └── AppIcon.appiconset/       # Mac app icon (.icns)
│   └── HoldApp.entitlements          # CloudKit + Push capabilities
│
├── HoldApp-iOS/                      # iOS App Target
│   ├── HoldApp_iOSApp.swift          # iOS app lifecycle, APNs, push handler
│   ├── ContentView.swift             # Display UI, subscription setup
│   ├── Assets.xcassets/
│   │   └── AppIcon.appiconset/       # iOS app icons (multiple PNGs)
│   └── HoldApp-iOS.entitlements      # CloudKit + Push capabilities
│
├── HoldApp.xcodeproj/                # Xcode project configuration
└── .claude/
    ├── CLAUDE.md                     # Development protocols
    └── SYSTEM_ARCHITECTURE.md        # 📄 THIS FILE
```

---

## Future Agent Instructions

**⚠️ CRITICAL: If you modify any of the following, you MUST update this document:**

1. **File Structure Changes**:
   - Adding/removing Swift files
   - Changing target membership of shared files
   - Renaming key components

2. **Architecture Changes**:
   - Modifying CloudKit schema (adding/removing record types or fields)
   - Changing sync mechanism (e.g., switching from subscriptions to polling)
   - Altering data flow (e.g., adding caching layer)

3. **Component Responsibility Changes**:
   - Moving logic between files (e.g., moving CloudKit code from AppDelegate to new manager)
   - Changing which component handles push notifications
   - Modifying subscription setup flow

4. **Key Technical Decisions**:
   - Switching from public to private database
   - Changing subscription type (CKQuerySubscription → CKDatabaseSubscription)
   - Modifying notification behavior (silent → visible)

5. **Critical Code Path Changes**:
   - Changing how tasks are saved (saveTask logic)
   - Modifying how subscriptions are created
   - Altering push notification handling flow

**Update Process**:
1. Read this entire document to understand current state
2. Make your code changes
3. Update relevant sections in this document
4. Verify all cross-references are still accurate
5. Update "File Structure Summary" if files added/removed
6. Commit code changes AND documentation updates together

**Document Location**: `/Users/vishaljain/xcode_projects/HoldApp/.claude/SYSTEM_ARCHITECTURE.md`

**Last Updated**: 2025-11-04
**Version**: 1.0 (Initial Release - Pre-TestFlight)
