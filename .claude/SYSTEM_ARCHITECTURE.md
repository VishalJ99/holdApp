# Hold - System Architecture

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
- **Responsibility**: App lifecycle, component initialization, task creation orchestration
- **Key Logic**:
  - Initializes Spotlight UI, hotkey manager, and LogManager
  - Handles `onTaskSubmit` callback with modifier key detection
  - Implements 5 task creation handlers (top-level, child, sibling with variations)
  - Coordinates between UI (SpotlightViewController), state (AppState), and data layer (CloudKitManager)
- **Task Creation Methods** (lines 58-156):
  - `handleTaskCreation()`: Routes based on TaskCreationType
  - `createTopLevelTask()`: Creates root task with optional switch
  - `createChildTask()`: Creates child under current task
  - `createSiblingTask()`: Creates sibling of current task with optional switch
- **Error Handling**: Shows toasts for missing current task references

**`HotkeyManager.swift`** (`HoldApp/HotkeyManager.swift`)
- **Responsibility**: Global keyboard shortcut registration (Cmd+Shift+Space)
- **Key Logic**:
  - Uses Carbon API to register system-wide hotkeys
  - Triggers show/hide callbacks for Spotlight panel
  - Currently registers Cmd+Shift+Space (lines 23-28)

**`SpotlightViewController.swift`** (`HoldApp/SpotlightViewController.swift`)
- **Responsibility**: The capture bar UI (text field, modifier key detection)
- **Conforms to**: TaskInputUI protocol
- **Key Logic**:
  - NSViewController with single SubmitTextField instance
  - **Modifier Detection** (lines 61-92): `handleSubmit()` detects Control, Shift, Cmd keys
  - **Arrow Handlers** (lines 96-110): Up = load current task, Down = clear text
  - Handles Escape key → fires `onCancel` callback
  - Placeholder text: "What task are you holding?"
- **Modifier Key Mappings**:
  - Enter → topLevel
  - **Ctrl+Enter** → topLevelAndSwitch
  - Shift+Enter → child
  - Cmd+Enter → sibling
  - **Cmd+Ctrl+Enter** → siblingAndSwitch

**`SubmitTextField.swift`** (`HoldApp/SubmitTextField.swift`) - NEW
- **Responsibility**: Custom NSTextField subclass for intercepting Enter key with modifiers
- **Key Logic**:
  - Overrides `performKeyEquivalent(with:)` to catch Enter key (keyCode 36)
  - Extracts modifier flags: `.control`, `.shift`, `.command`
  - Fires `onSubmit` callback with detected modifiers
  - **Design Decision**: Uses Control instead of Option because Option+Enter is treated as text input (newline) by macOS
- **Purpose**: Standard NSTextField doesn't trigger delegate callbacks for modifier+Enter combinations

**`SpotlightPanel.swift`** (`HoldApp/SpotlightPanel.swift`)
- **Responsibility**: The floating window that contains the capture bar
- **Key Logic**:
  - NSPanel configured as borderless, floating window
  - `show()`: Centers on screen, activates app, focuses text field
  - `hide()`: Closes window, clears text field
  - Level: `.floating` so it appears above all windows

**`LogManager.swift`** (`HoldApp/LogManager.swift`)
- **Responsibility**: Local backup logging to Application Support directory
- **Status**: ✅ WORKING - Writes to `~/Library/Application Support/HoldApp/logs.json`
- **Key Logic**:
  - Logs task entries with id, text, timestamp, and parent_id
  - JSON format: `{"timestamp": "...", "text": "...", "id": "...", "parent_id": "..." or null}`
  - Used for debugging and backup (CloudKit is primary source of truth)

**`TaskInputUI.swift`** (`HoldApp/TaskInputUI.swift`) - NEW
- **Responsibility**: Protocol defining task input interface contract
- **Purpose**: Allows hotswapping different spotlight implementations
- **Defines**: `show()`, `hide()`, `isVisible`, callbacks for task submission and cancellation
- **TaskCreationType enum**: Defines 5 task creation types based on modifier keys

**`AppState.swift`** (`HoldApp/AppState.swift`) - NEW
- **Responsibility**: Global state management for current task tracking
- **Key Data**: `currentTask` - TaskReference with id, text, parentId
- **Purpose**: Tracks which task iPhone is currently displaying (anchor for child/sibling operations)
- **Methods**: `setCurrent()`, `clearCurrent()`

**`ToastManager.swift`** (`HoldApp/ToastManager.swift`) - NEW
- **Responsibility**: Temporary notification messages (success/error)
- **Key Logic**:
  - Shows floating NSPanel with message
  - Auto-dismisses after 2 seconds
  - Two types: success (green) and error (red)
  - Positioned at top center of screen

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
    - Creates CKQuerySubscription for CurrentTaskPointer records (line 65)
    - Registers NotificationCenter observer for "CloudKitTaskUpdated" (line 74)
    - When notification received → Triggers `fetchCurrentTask()` (line 82)
    - **Note**: Subscribes to pointer updates (not Task saves) to eliminate race condition
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
  database = container.privateCloudDatabase      // Private database (user-isolated)
  ```
  - Uses default CloudKit container (configured in entitlements)
  - Uses **private database** (isolated per Apple ID, syncs across user's devices)

  **`saveTask()` (Lines 16-50)**:
  - Creates `CKRecord(recordType: "Task")`
  - Sets fields: `text`, `timestamp`, `isCompleted`, **`isCurrent`** (boolean), **`parent_id`** (optional)
  - Supports parent/child task relationships via parent_id parameter
  - `isCurrent` field kept for backward compatibility (deprecated, use pointer instead)
  - Saves to database
  - **Called from**: Mac AppDelegate task creation handlers
  - **Logs**: Save duration, record ID, parent relationship, current task status

  **`fetchCurrentTask()` (Lines 52-78)**:
  - **Fetches by hardcoded ID**: `CKRecord.ID(recordName: "CURRENT_TASK_POINTER")`
  - **No query, no index lag** - direct database fetch
  - Extracts `currentTaskText` field from pointer record
  - Returns `nil` if pointer doesn't exist (no current task set)
  - **Called from**: iPhone ContentView on app launch and notification
  - **Logs**: Fetch duration, task text, "Fetched from pointer (instant, no index lag)"

  **`updateCurrentTaskPointer()` (Lines 80-132)**:
  - Fetches or creates singleton pointer record with ID "CURRENT_TASK_POINTER"
  - Updates `currentTaskText` and `timestamp` fields
  - **Called from**: Mac AppDelegate when task becomes current (Ctrl+Enter, Shift+Enter, Cmd+Ctrl+Enter)
  - **Logs**: Pointer update/creation duration, task text
  - **Purpose**: Enable instant iPhone sync without query index lag

  **`subscribeToTaskChanges()` (Lines 149-181)**:
  - Creates `CKQuerySubscription` for "CurrentTaskPointer" records (not Task records!)
  - Options: `.firesOnRecordCreation`, `.firesOnRecordUpdate`
  - Notification: `shouldSendContentAvailable = true` (silent push)
  - **Called from**: iPhone ContentView on first launch
  - **Logs**: Subscription configuration, success/failure, subscription ID
  - **Critical**: This links the iPhone's device token to CloudKit's notification system
  - **Race Condition Fix**: Subscribing to pointer (not Task) ensures notification only fires AFTER pointer update completes

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
1. Pointer updated       →  Check subscriptions
2. Find subscription ID  →  "55C508DF-..."
3. Get device token      →  "d87224f72212ec54..."
4. Send push             →  APNs servers          →  iPhone receives
5. Silent notification   →                        →  didReceiveRemoteNotification
6. Post local notif      →                        →  "CloudKitTaskUpdated"
7. ContentView observes  →                        →  Triggers fetchCurrentTask()
8. Fetch pointer by ID   →  Fetch pointer         ←  database.fetch(withRecordID:)
9. Update UI             →                        →  Display "Buy groceries"
```

**Timing**: < 1 second after subscription activates (5-15 min activation on first registration)
**Key**: Subscribes to CurrentTaskPointer (not Task) to eliminate race condition

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

## Keyboard Modifier Detection Flow

### User Input → Task Creation Pipeline

```
User Action                  Component Chain                         Result
──────────────────────────────────────────────────────────────────────────────
1. Type "task text"      →   SubmitTextField                    →   Text stored
2. Press Enter+Modifiers →   SubmitTextField.performKeyEquivalent →   Event captured
3. Extract modifiers     →   modifierFlags.intersection([.option, .shift, .command])
4. Fire callback         →   onSubmit?(modifiers)               →   Closure called
5. Handle in ViewController → SpotlightViewController.handleSubmit()
6. Map to type           →   TaskCreationType enum              →   Determined
7. Submit task           →   onTaskSubmit?(text, creationType)  →   Callback fired
8. Route to handler      →   AppDelegate.handleTaskCreation()   →   Logic routed
9. Create task           →   CloudKitManager.saveTask()         →   Saved to CloudKit
10. Update state         →   AppState.setCurrent()              →   Current task set
11. Show feedback        →   ToastManager.show()                →   Toast displayed
```

### Detailed Flow Breakdown

#### Step 1-4: SubmitTextField Key Interception
**File**: `HoldApp/SubmitTextField.swift` (lines 14-26)

```swift
override func performKeyEquivalent(with event: NSEvent) -> Bool {
    // Check for Return/Enter key (keyCode 36)
    if event.keyCode == 36 {
        // Extract ONLY relevant modifiers (ignore Caps Lock, Function, etc.)
        let relevantModifiers: NSEvent.ModifierFlags = [.option, .shift, .command]
        let modifiers = event.modifierFlags.intersection(relevantModifiers)

        // Fire callback with detected modifiers
        onSubmit?(modifiers)  // Passes to SpotlightViewController
        return true           // Event consumed, don't pass to super
    }
    return super.performKeyEquivalent(with: event)
}
```

**What Happens**:
- macOS routes Enter key event to text field
- `performKeyEquivalent` catches it before text processing
- Extracts modifier flags (empty set if no modifiers pressed)
- Calls `onSubmit` closure set by SpotlightViewController

**Design Note**:
- `performKeyEquivalent` fires for command modifiers (Control, Shift, Command)
- Option+Enter would bypass this method (goes to text input system as newline)
- This is why Control is used instead of Option for the "switch" modifier

#### Step 5-6: SpotlightViewController Modifier Mapping
**File**: `HoldApp/SpotlightViewController.swift` (lines 61-92)

```swift
private func handleSubmit(modifiers: NSEvent.ModifierFlags) {
    let text = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }

    // Detect which modifier keys are pressed
    let controlPressed = modifiers.contains(.control)
    let shiftPressed = modifiers.contains(.shift)
    let commandPressed = modifiers.contains(.command)

    // Map modifier combination to task creation type
    let creationType: TaskCreationType
    if commandPressed && controlPressed {
        creationType = .siblingAndSwitch      // Cmd+Ctrl+Enter
    } else if commandPressed {
        creationType = .sibling               // Cmd+Enter
    } else if shiftPressed {
        creationType = .child                 // Shift+Enter
    } else if controlPressed {
        creationType = .topLevelAndSwitch     // Ctrl+Enter
    } else {
        creationType = .topLevel              // Plain Enter
    }

    // Clear field and submit
    textField.stringValue = ""
    onTaskSubmit?(text, creationType)  // Passes to AppDelegate
}
```

**TaskCreationType enum** (`HoldApp/TaskInputUI.swift:38-44`):
```swift
enum TaskCreationType {
    case topLevel              // Enter - Create root task, don't switch
    case topLevelAndSwitch     // Ctrl+Enter - Create root + make current
    case child                 // Shift+Enter - Create child of current, always switch
    case sibling               // Cmd+Enter - Create sibling of current, don't switch
    case siblingAndSwitch      // Cmd+Ctrl+Enter - Create sibling + switch
}
```

#### Step 7-8: AppDelegate Task Routing
**File**: `HoldApp/AppDelegate.swift` (lines 58-89)

```swift
private func handleTaskCreation(text: String, type: TaskCreationType) {
    switch type {
    case .topLevel:
        createTopLevelTask(text: text, switchTo: false)
    case .topLevelAndSwitch:
        createTopLevelTask(text: text, switchTo: true)
    case .child:
        guard let current = AppState.shared.currentTask else {
            ToastManager.shared.show("⚠️ No parent task. Create a top-level task first.", type: .error)
            return
        }
        createChildTask(text: text, parent: current)
    case .sibling:
        guard let current = AppState.shared.currentTask else {
            ToastManager.shared.show("⚠️ No reference task. Create a task first.", type: .error)
            return
        }
        createSiblingTask(text: text, reference: current, switchTo: false)
    case .siblingAndSwitch:
        guard let current = AppState.shared.currentTask else {
            ToastManager.shared.show("⚠️ No reference task. Create a task first.", type: .error)
            return
        }
        createSiblingTask(text: text, reference: current, switchTo: true)
    }
    spotlightPanel.hide()
}
```

**Error Handling**:
- `.child`, `.sibling`, `.siblingAndSwitch` require `AppState.shared.currentTask` to exist
- If `currentTask == nil`, shows error toast and aborts creation
- User must explicitly create and switch to a task using Ctrl+Enter to set the first current task

#### Step 9-11: Task Creation & State Update
**File**: `HoldApp/AppDelegate.swift` (lines 91-156)

**Example: `createTopLevelTask()`** (lines 91-113):
```swift
private func createTopLevelTask(text: String, switchTo: Bool) {
    CloudKitManager.shared.saveTask(text: text, parentId: nil, isCurrent: switchTo) { [weak self] result in
        switch result {
        case .success(let record):
            let taskId = record.recordID.recordName

            if switchTo {
                // Ctrl+Enter case - set as current and sync to CloudKit
                AppState.shared.setCurrent(id: taskId, text: text, parentId: nil)
                ToastManager.shared.show("✓ Task created (current)", type: .success)
            } else {
                // Plain Enter case - create but don't set as current
                ToastManager.shared.show("✓ Task created", type: .success)
            }

            self?.logManager.log(text: text, id: taskId, parentId: nil)

        case .failure(let error):
            ToastManager.shared.show("❌ Error: \(error.localizedDescription)", type: .error)
        }
    }
}
```

**Key Behaviors**:
- `switchTo: true` → Sets task as current in AppState, saves with `isCurrent: true` to CloudKit (syncs to iPhone)
- `switchTo: false` → Creates task without setting as current, saves with `isCurrent: false` (won't display on iPhone)
- Logs to both CloudKit and local logs.json file
- Shows success/error toast for user feedback

**Modifier Key → isCurrent Mapping**:
- **Enter** (.topLevel) → `isCurrent: false` - Create task, don't display on iPhone
- **Ctrl+Enter** (.topLevelAndSwitch) → `isCurrent: true` - Create and display on iPhone
- **Shift+Enter** (.child) → `isCurrent: true` - Child tasks always become current
- **Cmd+Enter** (.sibling) → `isCurrent: false` - Create sibling, don't switch
- **Cmd+Ctrl+Enter** (.siblingAndSwitch) → `isCurrent: true` - Create sibling and display on iPhone

---

## macOS Event Handling Architecture

### Why We Use Control Instead of Option

macOS has a multi-layer event handling system for NSTextField:

```
Event Layer                  What Gets Handled                   Modifier Behavior
──────────────────────────────────────────────────────────────────────────────────────
1. performKeyEquivalent     Command-based shortcuts              ✅ Ctrl+Enter, Cmd+Enter, Shift+Enter
2. keyDown                  ALL key events (pre-interpretation)  ⚠️  Catches all but breaks delegates
3. Text Input System        Interprets keys as text/commands     ✅ Option+Enter (newline insertion)
4. NSTextFieldDelegate      Command selectors (insertNewline)    ❌ Too late for modified Enter
```

**Current Implementation**:
- Uses Layer 1 (`performKeyEquivalent`) with Control, Shift, Command modifiers
- ✅ Ctrl+Enter, Shift+Enter, Cmd+Enter all work perfectly
- ❌ Option+Enter would bypass Layer 1 → goes to text input → interpreted as newline

**Why Option Doesn't Work**:
- Option is used by macOS for typing special characters (Option+e = é, etc.)
- Option+Enter is categorized as **text input**, not a command
- Goes to Layer 3 (text input system) instead of Layer 1 (command handling)
- This is a macOS design decision, not a bug

**Why keyDown Doesn't Work**:
- Layer 2 catches ALL keys (including arrows, Tab, Escape)
- NSTextField needs these to flow through its internal delegate chain
- If we intercept and `return` early, Arrow keys and other navigation breaks
- Attempted during development, broke all modifier combinations

**Solution**: Use Control (.control) instead of Option (.option)
- Control is a command modifier (like Cmd/Shift)
- Caught by `performKeyEquivalent` reliably
- No text input conflicts

---

## Key Technical Decisions

### 1. CloudKit Private Database
**Choice**: `container.privateCloudDatabase`
**Reasoning**:
- **User isolation**: Each user gets their own private partition (isolated by Apple ID)
- **Cross-device sync**: Syncs across all devices signed into the same Apple ID (Mac + iPhone)
- **Hardcoded record IDs work correctly**: "CURRENT_TASK_POINTER" is unique per user, not shared globally
- **Security**: Personal tasks remain private, no accidental data leakage between users

**Why Not Public Database**:
- Public database is shared across ALL users of the app
- Hardcoded IDs like "CURRENT_TASK_POINTER" would be globally unique → all users would overwrite each other's pointer
- Not suitable for personal task management

### 2. CKQuerySubscription for CurrentTaskPointer (Not Task Records)
**Choice**: `CKQuerySubscription(recordType: "CurrentTaskPointer", predicate: ...)`
**Reasoning**:
- **Eliminates race condition**: Notification only fires AFTER pointer update completes
- Fine-grained control: only notify on pointer changes (when current task actually changes)
- More efficient: iPhone doesn't wake for plain Enter tasks (only switchTo tasks)
- Can filter by predicate (currently matches all: `NSPredicate(value: true)`)
- Options: `.firesOnRecordCreation` and `.firesOnRecordUpdate`

**Previous Bug**: Subscribed to "Task" records, but iPhone fetched from pointer → race condition
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

| Field Name   | Type      | Description                                    |
|--------------|-----------|------------------------------------------------|
| `text`       | String    | The task description                           |
| `timestamp`  | Date/Time | When task was created (for sorting)            |
| `isCompleted`| Boolean   | Completion status (always false MVP)           |
| `isCurrent`  | Boolean   | DEPRECATED - kept for backward compatibility |
| `parent_id`  | String?   | CloudKit record ID of parent task (nil if top-level) |

**Indexes**:
- Default index on `timestamp` for sorting
- Default index on `isCompleted` for filtering

**Parent-Child Relationships**:
- `parent_id` establishes task hierarchy (used for child/sibling creation)
- Top-level tasks have `parent_id = nil`
- Child tasks have `parent_id` set to their parent's CloudKit record ID
- Sibling tasks share the same `parent_id` as their reference task

### Record Type: "CurrentTaskPointer"

**Purpose**: Singleton record that points to the current task, enabling instant fetch without query index lag.

| Field Name        | Type      | Description                                    |
|-------------------|-----------|------------------------------------------------|
| `currentTaskText` | String    | Text of the currently active task              |
| `timestamp`       | Date/Time | When this pointer was last updated             |

**Record ID**: **Hardcoded to "CURRENT_TASK_POINTER"** (both macOS and iPhone know this ID)

**Current Task Synchronization Flow**:
1. **macOS creates task with Ctrl+Enter/Shift+Enter/Cmd+Ctrl+Enter**
2. **macOS saves Task record** with `isCurrent = true` (backward compatibility)
3. **macOS calls `updateCurrentTaskPointer(text)`**:
   - Fetches record by ID "CURRENT_TASK_POINTER" (not a query!)
   - If exists: updates `currentTaskText` field
   - If not exists: creates new record with this hardcoded ID
4. **CloudKit subscription fires** → notification sent to iPhone
5. **iPhone calls `fetchCurrentTask()`**:
   - Fetches by ID "CURRENT_TASK_POINTER" (bypasses query index - instant!)
   - Extracts `currentTaskText` and displays
6. **Result**: < 1 second sync, no index lag

**Why This Works**:
- ✅ **No query** - fetch by ID goes directly to database
- ✅ **No index lag** - doesn't use query indexes
- ✅ **Only one pointer** - singleton by design (hardcoded ID)
- ✅ **Instant updates** - as soon as macOS saves, iPhone can fetch immediately

**Contrast with Previous Query Approach**:
- ❌ **Query-based**: `database.perform(CKQuery...)` → uses query index → 1-30s lag
- ✅ **Fetch by ID**: `database.fetch(withRecordID:)` → direct database access → instant

**Permissions**:
- Created by: User's iCloud account (automatic)
- Readable by: Creator only (CloudKit default)
- Writable by: Creator only (CloudKit default)

---

## Entitlements & Capabilities

### Mac App: `HoldApp/HoldApp.entitlements`
```xml
<key>com.apple.developer.aps-environment</key>
<string>production</string>  <!-- Push notifications environment -->

<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.vishaljain.HoldApp</string>
</array>

<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>

<key>com.apple.developer.icloud-container-environment</key>
<string>Development</string>  <!-- CloudKit database environment -->

<key>com.apple.security.app-sandbox</key>
<false/>  <!-- Disabled for global hotkey access -->
```

### iOS App: `HoldApp-iOS/HoldApp-iOS.entitlements`
```xml
<key>aps-environment</key>
<string>production</string>  <!-- Push notifications environment -->

<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.vishaljain.HoldApp</string>  <!-- Same container as Mac -->
</array>

<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>

<key>com.apple.developer.icloud-container-environment</key>
<string>Development</string>  <!-- CloudKit database environment -->
```

**Critical**: Both apps MUST use the same CloudKit container identifier for sync to work.

### CloudKit Environment Configuration

**Two Separate Keys**:
1. **`aps-environment`** - Controls push notification service (APNs)
   - `development` - Development APNs servers
   - `production` - Production APNs servers (auto-set by Xcode for App Store builds)

2. **`com.apple.developer.icloud-container-environment`** - Controls CloudKit database
   - `Development` - Development database (separate from production data)
   - `Production` - Production database (real user data)

**Important Limitation**:
- **Development**: Subscriptions work in local Xcode builds ✅
- **Production**: Subscriptions ONLY work in TestFlight/App Store builds ❌
  - Local Xcode builds will fail with: "attempting to create a subscription in a production container"
  - Must deploy to TestFlight to test Production subscriptions

**Current Configuration**: Development environment for local testing with subscriptions enabled

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

## Known Issues & Technical Debt

### 0. CloudKit Subscription Race Condition
**Status**: ✅ FIXED (2025-11-09)
**Issue**: iPhone sometimes showed stale task (1 task behind) when creating tasks with Ctrl+Enter
**Root Cause**: Subscribed to "Task" records, but iPhone fetched from "CurrentTaskPointer"
- Task save completed → notification sent immediately
- Pointer update still in progress → iPhone fetched old pointer value
- Race condition: notification arrival vs pointer update completion
**Fix**: Changed subscription from "Task" to "CurrentTaskPointer" (CloudKitManager.swift:154)
**Impact**: Notification now only fires AFTER pointer update completes, eliminating race
**Side Benefit**: More efficient - iPhone only wakes when current task actually changes

### 1. Modifier Key Constraints for Customization
**Status**: ⚠️ IMPORTANT LIMITATION
**Issue**: Not all keys can be used as modifiers with Enter key
**Root Cause**: macOS text input system treats certain modifier combinations as text input, not commands
**Impact**: Limits which keys can be used for custom hotkey combinations
**Resolution**: Changed from Option to Control modifier (see below)

**Technical Explanation**:
- **True Modifier Keys** (work with `performKeyEquivalent`):
  - ✅ Control (.control) - Used in current implementation
  - ✅ Shift (.shift)
  - ✅ Command (.command)
  - ⚠️ Caps Lock (.capsLock) - Works but is a toggle, not hold
- **Text Input Modifiers** (bypass `performKeyEquivalent`, treated as text):
  - ❌ Option (.option) - Option+Enter = newline character insertion
- **Non-Modifier Keys** (cannot be used as modifiers):
  - ❌ Tab, Arrow keys, etc. - These are key presses, not modifiers

**Future Customization Guidelines**:
If implementing user-customizable hotkeys, ONLY allow selection from:
- Control (.control)
- Shift (.shift)
- Command (.command)
- Combinations of the above

Do NOT allow:
- Option as a modifier (text input path)
- Tab, arrows, or other keys as "modifiers" (they're key presses, not flags)
- Any keys that require sequential press detection (timing issues, poor UX)

**Current Mapping** (using Control):
- Enter → topLevel
- Ctrl+Enter → topLevelAndSwitch
- Shift+Enter → child
- Cmd+Enter → sibling
- Cmd+Ctrl+Enter → siblingAndSwitch

### 2. LogManager (Mac Only)
**Status**: ✅ FIXED
**Issue**: Was attempting to write to `/logs.json` (read-only filesystem)
**Fix**: Now writes to `~/Library/Application Support/HoldApp/logs.json`
**Impact**: Backup logging now works correctly

### 3. Subscription Activation Delay
**Status**: ⚠️ KNOWN LIMITATION
**Issue**: First-time subscription takes 5-15 minutes to activate
**Impact**: Push notifications don't work immediately on first install
**Workaround**: Wait or use polling fallback in DEBUG builds
**Fix**: None (Apple's CloudKit limitation in development)

### 4. No Task Completion
**Status**: 📝 FUTURE FEATURE
**Issue**: Tasks are never marked as `isCompleted = true`
**Impact**: All tasks persist in CloudKit indefinitely
**Future**: Add swipe gesture on iPhone to mark complete, cleanup old tasks

### 5. No Multi-Task Support
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
│   ├── SubmitTextField.swift         # 🆕 Custom NSTextField for modifier key detection
│   ├── TaskInputUI.swift             # 🆕 Protocol for task input interface
│   ├── AppState.swift                # 🆕 Global state (current task tracking)
│   ├── ToastManager.swift            # 🆕 Temporary notification messages
│   ├── LogManager.swift              # ✅ FIXED - Logs to Application Support directory
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
    ├── SYSTEM_ARCHITECTURE.md        # 📄 THIS FILE
    └── Hold State Diagrams.md        # State machine specifications
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

**Last Updated**: 2025-11-09
**Version**: 1.1 (Fixed CloudKit subscription race condition)
