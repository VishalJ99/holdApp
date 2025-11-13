# Hold - System Architecture
**Update Process**:
1. Read this entire document to understand current state
2. Make your code changes
3. Update relevant sections in this document
4. Verify all cross-references are still accurate
5. Update "File Structure Summary" if files added/removed
6. Commit code changes AND documentation updates together
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
- **Responsibility**: App lifecycle, component initialization, task creation orchestration, sibling selection
- **Key Logic**:
  - Initializes Spotlight UI, Sibling Selector UI, hotkey manager, and LogManager
  - Handles `onTaskSubmit` callback with modifier key detection
  - Implements 5 task creation handlers (top-level, child, sibling with variations)
  - Implements sibling selection workflow (Cmd+Shift+S)
  - Coordinates between UI (SpotlightViewController, SiblingSelectorViewController), state (AppState), and data layer (CloudKitManager)
- **Task Creation Methods** (lines 58-384):
  - `handleTaskCreation()`: Routes based on TaskCreationType
  - `createTopLevelTask()`: Creates root task with optional switch
    - If `switchTo: true`, fetches siblings, calculates all metadata, updates pointer with 10 fields
    - Uses DispatchGroup to coordinate parallel fetches (no parent/root for top-level)
  - `createChildTask()`: Creates child under current task
    - Always switches to new child (`switchTo: true` implicit)
    - Fetches parent text, root text (if exists), calculates ellipsis, fetches siblings
    - Uses DispatchGroup for parallel metadata fetches
    - Updates pointer with complete hierarchy and sibling info
  - `createSiblingTask()`: Creates sibling of current task with optional switch
    - If `switchTo: true`, fetches parent text, root text, calculates ellipsis, fetches siblings
    - Uses DispatchGroup for parallel metadata fetches
    - Updates pointer with all display metadata
  - **Key Pattern**: All "switch" operations (Ctrl+Enter, Shift+Enter, Cmd+Ctrl+Enter) now:
    1. Save Task record to CloudKit
    2. Fetch parent/root texts (if applicable) via `fetchTaskById()`
    3. Calculate `showEllipsis` (level 4+ hierarchy: `parent.parent_id != nil && parent.parent_id != rootId`)
    4. Fetch siblings via `fetchSiblings(parentId:)` and calculate position/count
    5. Update CurrentTaskPointer with ALL 10 fields
    6. Update AppState and show success toast
- **Sibling Selection Methods** (lines 386-561):
  - `showSiblingSelector()`: Validates current task has parent, fetches siblings, displays panel
  - `handleSiblingSelection()`: Updates CurrentTaskPointer with selected sibling, fetches all display metadata
    - Follows same DispatchGroup pattern as task creation for metadata fetching
- **Error Handling**: Shows toasts for missing current task references, no parent errors, fetch failures

**`HotkeyManager.swift`** (`HoldApp/HotkeyManager.swift`)
- **Responsibility**: Global keyboard shortcut registration
- **Key Logic**:
  - Uses Carbon API to register system-wide hotkeys
  - Triggers callbacks for Spotlight panel and Sibling Selector
  - Registered hotkeys:
    - Cmd+Shift+Space (ID 1): Show Spotlight panel
    - Escape (ID 2): Hide panel
    - Cmd+Shift+S (ID 3): Show Sibling Selector panel

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

**`SiblingSelectorViewController.swift`** (`HoldApp/SiblingSelectorViewController.swift`) - NEW
- **Responsibility**: Displays list of sibling tasks for selection (Cmd+Shift+S)
- **Key Logic**:
  - Uses NSTableView to display siblings with position indicators ([1/5], [2/5], etc.)
  - Highlights current sibling (bold, full opacity)
  - Arrow keys navigate through list
  - Enter key selects highlighted sibling → fires `onSiblingSelected` callback
  - Escape key cancels → fires `onCancel` callback
- **UI Design**:
  - Minimal, terminal-inspired aesthetic matching Hold's vision
  - Black background, white text, SF Pro Rounded font
  - Current sibling: opacity 1.0, semibold
  - Other siblings: opacity 0.7, regular weight
  - Format: "[position/total] task text"
- **Callbacks**:
  - `onSiblingSelected: ((String, String) -> Void)?` - (taskId, taskText)
  - `onCancel: (() -> Void)?`

**`SiblingSelectorPanel.swift`** (`HoldApp/SiblingSelectorPanel.swift`) - NEW
- **Responsibility**: Floating window container for sibling selector
- **Key Logic**:
  - NSPanel configured as borderless, floating window (level: `.floating`)
  - Dynamically adjusts height based on sibling count (min: 100px, max: 500px)
  - Centers on screen when shown
  - Black background (0.95 alpha), rounded corners (12px radius)
- **Methods**:
  - `show(siblings: [(id: String, text: String)], currentIndex: Int)` - Display panel with sibling list
  - `hide()` - Close panel

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
  - **Lines 21-43**: SwiftUI view - displays hierarchical task context on black background
    - Uses `HierarchyView_MaxContrast` component for rendering
    - Conditionally shows root, ellipsis, parent, current task based on hierarchy depth
    - Shows sibling position dots if task has siblings
  - **Lines 44-53**: `onAppear` - disables screen auto-lock, initializes subscription and fetches current task
  - **Lines 56-101**: `fetchCurrentTask()` - fetches pointer record, extracts ALL display fields:
    - `currentText` - Current task text
    - `parentText` - Parent task text (for hierarchy display)
    - `rootText` - Root task text (for hierarchy display)
    - `showEllipsis` - Whether to show ellipsis (level 4+ hierarchy)
    - `siblingPos` - Position among siblings (1-based)
    - `siblingCnt` - Total sibling count
  - **Lines 103-128**: `setupCloudKitSubscription()` - **CRITICAL**:
    - Creates CKQuerySubscription for CurrentTaskPointer records (line 107)
    - Registers NotificationCenter observer for "CloudKitTaskUpdated" (line 116)
    - When notification received → Triggers `fetchCurrentTask()` (line 124)
    - **Note**: Subscribes to pointer updates (not Task saves) to eliminate race condition
- **State Management** (lines 13-19):
  - `@State private var rootTask: String?` - Root task text for hierarchy display
  - `@State private var parentTask: String?` - Parent task text for hierarchy display
  - `@State private var currentTask: String?` - Current task text (main display)
  - `@State private var showEllipsis: Bool` - Whether to show ellipsis between root and parent
  - `@State private var siblingPosition: Int?` - Current task's position among siblings
  - `@State private var siblingTotal: Int?` - Total number of siblings
  - `@State private var isLoading: Bool` - Loading indicator state
- **HierarchyView_MaxContrast** (lines 131-220):
  - Displays adaptive hierarchy based on task depth (1-4 levels)
  - SF Pro Rounded typography with varying sizes: root (15pt), parent (20pt), current (40pt)
  - Dynamic spacing - elements only take space when rendered
  - Sibling indicator dots (○ ● ○ ○) showing position among siblings
  - Opacity hierarchy: current (1.0), parent (0.75), root (0.55)

---

### Shared Layer (Both Targets)

**`CloudKitManager.swift`** (`HoldApp/CloudKitManager.swift`)

- **Target Membership**: ✅ HoldApp (Mac) + ✅ HoldApp-iOS (iPhone)
- **Responsibility**: All CloudKit operations - save, fetch, subscribe
- **Key Logic**:

  **Initialization (Lines 10-28)**:
  ```swift
  container = CKContainer.default()              // iCloud.com.vishaljain.HoldApp
  database = container.privateCloudDatabase      // Private database (user-isolated)
  ```
  - Uses default CloudKit container (configured in entitlements)
  - Uses **private database** (isolated per Apple ID, syncs across user's devices)
  - Logs container ID and environment (production vs development)

  **`saveTask()` (Lines 31-74)**:
  - Creates `CKRecord(recordType: "Task")`
  - Sets fields: `text`, `timestamp`, `isCompleted`, **`isCurrent`** (boolean), **`parent_id`** (optional), **`root_id`** (optional)
  - Supports hierarchical task relationships via parent_id and root_id parameters
  - `isCurrent` field kept for backward compatibility (deprecated, use pointer instead)
  - Saves to database
  - **Called from**: Mac AppDelegate task creation handlers
  - **Logs**: Save duration, record ID, parent relationship, root relationship, current task status

  **`fetchTaskById()` (Lines 77-98)**:
  - Fetches specific task record by CloudKit record ID
  - Used by Mac for fetching parent/root task texts
  - Returns CKRecord with all task fields
  - **Called from**: Mac AppDelegate task creation handlers (for building hierarchy display metadata)
  - **Logs**: Fetch duration, task text, parent_id, root_id

  **`fetchCurrentTask()` (Lines 102-168)**:
  - **Fetches by hardcoded ID**: `CKRecord.ID(recordName: "CURRENT_TASK_POINTER")`
  - **No query, no index lag** - direct database fetch
  - Extracts **9 fields** from pointer record:
    - `taskId` - Current task's CloudKit record ID
    - `text` - Current task text
    - `parentId` - Parent task's CloudKit record ID
    - `rootId` - Root task's CloudKit record ID
    - `parentTaskText` - Parent task text (for hierarchy display)
    - `rootTaskText` - Root task text (for hierarchy display)
    - `showEllipsis` - Boolean indicating level 4+ hierarchy (stored as Int: 1=true, 0=false)
    - `siblingPosition` - 1-based position among siblings
    - `siblingCount` - Total number of siblings (including current)
  - Returns tuple with all 9 fields
  - Returns `nil` values if pointer doesn't exist (no current task set)
  - **Called from**: iPhone ContentView on app launch and notification
  - **Logs**: Fetch duration, all extracted fields, "Fetched from pointer (instant, no index lag)"

  **`updateCurrentTaskPointer()` (Lines 171-253)**:
  - Fetches or creates singleton pointer record with ID "CURRENT_TASK_POINTER"
  - Updates **ALL 10 fields**:
    - `currentTaskId` - Current task's record ID
    - `currentTaskText` - Current task text
    - `parentId` - Parent task's record ID
    - `rootId` - Root task's record ID
    - `parentTaskText` - Parent task text
    - `rootTaskText` - Root task text
    - `showEllipsis` - 1 if level 4+, 0 otherwise
    - `siblingPosition` - Position among siblings
    - `siblingCount` - Total sibling count
    - `timestamp` - Update time
  - **Called from**: Mac AppDelegate when task becomes current (Ctrl+Enter, Shift+Enter, Cmd+Ctrl+Enter) AND sibling selection
  - **Logs**: Pointer update/creation duration, all fields, "Pointer Summary"
  - **Purpose**: Enable instant iPhone sync without query index lag, provide complete display info in one fetch

  **`fetchSiblings()` (Lines 256-285)**:
  - Queries CloudKit for all tasks with matching `parent_id`
  - Sorts by timestamp (ascending) for stable ordering
  - Returns array of tuples: `(id: String, text: String, timestamp: Date)`
  - **Called from**: Mac AppDelegate during task creation (to calculate siblingPosition/siblingCount) and sibling selection UI
  - **Logs**: Fetch duration, sibling count

  **`subscribeToTaskChanges()` (Lines 288-319)**:
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
   (ALL 10 fields)
2. Find subscription ID  →  "55C508DF-..."
3. Get device token      →  "d87224f72212ec54..."
4. Send push             →  APNs servers          →  iPhone receives
5. Silent notification   →                        →  didReceiveRemoteNotification
6. Post local notif      →                        →  "CloudKitTaskUpdated"
7. ContentView observes  →                        →  Triggers fetchCurrentTask()
8. Fetch pointer by ID   →  Fetch pointer         ←  database.fetch(withRecordID:)
   Extract 9 fields:
   - taskId, text
   - parentId, rootId
   - parentTaskText, rootTaskText
   - showEllipsis
   - siblingPosition, siblingCount
9. Update UI with:       →                        →  Display hierarchy:
   - Root (if level 3+)                             "New parent"
   - Ellipsis (if level 4+)                         "⋯"
   - Parent (if level 2+)                           "New child 2"
   - Current task                                   "New child 3" (40pt, bold)
   - Sibling dots (if siblings)                     ○ ○ ● ○
```

**Timing**: < 1 second after subscription activates (5-15 min activation on first registration)
**Key**: Subscribes to CurrentTaskPointer (not Task) to eliminate race condition
**Efficiency**: iPhone does ONE fetch, gets everything needed for display (no calculations, no additional fetches)

### Hierarchy Display Metadata Calculation (Mac → CloudKit):

**When creating/switching to a task, Mac calculates ALL display metadata before updating pointer:**

```
Task Creation Flow (e.g., Shift+Enter creates child)
────────────────────────────────────────────────────
1. Save Task record
   - text: "New child 3"
   - parent_id: "ABC123" (id of "New child 2")
   - root_id: "XYZ789" (id of "New parent")

2. Fetch Parent Task (parent_id = "ABC123")
   - parent.text = "New child 2"
   - parent.parent_id = "DEF456" (id of "New child")
   - parent.root_id = "XYZ789"

3. Fetch Root Task (root_id = "XYZ789")
   - root.text = "New parent"

4. Calculate showEllipsis
   - Logic: parent.parent_id != nil && parent.parent_id != rootId
   - parent.parent_id = "DEF456"
   - rootId = "XYZ789"
   - DEF456 != XYZ789 → showEllipsis = true (level 4+ hierarchy)

5. Fetch Siblings (all tasks with parent_id = "ABC123")
   - Query: WHERE parent_id == "ABC123" ORDER BY timestamp ASC
   - Results: ["New child 3" (timestamp: 1), "Sibling 1" (timestamp: 2), "Sibling 2" (timestamp: 3)]
   - siblingCount = 3
   - Find current task in list → siblingPosition = 1 (first sibling)

6. Update CurrentTaskPointer with ALL 10 fields
   - currentTaskId: [new task ID]
   - currentTaskText: "New child 3"
   - parentId: "ABC123"
   - rootId: "XYZ789"
   - parentTaskText: "New child 2"
   - rootTaskText: "New parent"
   - showEllipsis: 1 (true)
   - siblingPosition: 1
   - siblingCount: 3
   - timestamp: [now]

7. Push notification triggers → iPhone fetches pointer → Displays immediately
```

**Ellipsis Calculation Logic:**
- **Level 1 (root)**: No ellipsis (no parent)
- **Level 2 (child of root)**: No ellipsis (only 2 levels)
- **Level 3 (grandchild)**: No ellipsis (root → parent → current fits in 3 rows)
- **Level 4+ (great-grandchild+)**: Show ellipsis (root → ... → parent → current)
  - Condition: `parent.parent_id != nil && parent.parent_id != rootId`
  - If parent's parent exists AND isn't the root → we're skipping levels → show ellipsis

**Sibling Position Calculation:**
- Fetch all siblings (tasks with same parent_id)
- Sort by timestamp (ascending) for stable ordering
- Find current task in sorted list → position = index + 1 (1-based)
- Count = total siblings in list

**Optimization: DispatchGroup for Parallel Fetches**
- Parent fetch, root fetch, sibling fetch run in parallel (not sequential)
- All must complete before pointer update
- Reduces total sync time from 3 sequential fetches to 1 parallel batch

---

## Sibling Tracking System

The sibling tracking system allows users to navigate between tasks that share the same parent, with real-time iPhone display updates showing sibling position and count.

### Overview

**Key Components:**
- `HoldApp/SiblingTableView.swift` - Custom NSTableView subclass for keyboard event handling
- `HoldApp/SiblingSelectorViewController.swift` - Sibling list UI controller
- `HoldApp/SiblingSelectorPanel.swift` - Floating panel for sibling selection
- `HoldApp/HotkeyManager.swift` - Cmd+Shift+S hotkey registration
- `HoldApp/AppDelegate.swift` - Unified pointer update logic (lines 281-402, 467-586)
- `HoldApp/CloudKitManager.swift` - `fetchSiblings()` method (lines 256-285)

**CloudKit Schema Fields (CurrentTaskPointer):**
- `siblingPosition` (Int) - Current task's position among siblings (1-based)
- `siblingCount` (Int) - Total number of siblings (including current task)

### Three Sibling Operations

#### 1. Create Sibling Without Switch (Cmd+Enter)

**Flow:**
```
User: Cmd+Enter on "Buy groceries"
├─ Current task: "Clean room" (sibling #2/3 under "Home tasks")
├─ Creates: "Buy groceries" (becomes sibling #4)
├─ Keeps current: "Clean room"
└─ iPhone updates: Shows 4 dots instead of 3 (position stays at #2)
```

**Code Path (AppDelegate.swift:281-402):**
1. **Determine display task** (lines 282-304):
   ```swift
   if switchTo {
       displayTaskId = newSiblingId  // Not taken
   } else {
       displayTaskId = currentTask.id  // Keep current task
   }
   ```

2. **Unified pointer update** (lines 306-402):
   - Fetch parent text
   - Fetch root text
   - **Fetch siblings** (line 356): Query returns ALL tasks with same parent_id
   - Calculate count: `siblings.count + 1` (accounts for index lag - new sibling just saved)
   - Calculate position: Find current task in siblings array → `index + 1`
   - Update pointer → CloudKit subscription fires → iPhone refreshes

**Key Insight:** Database query automatically includes newly created sibling, so count increments naturally without manual calculation.

#### 2. Create Sibling With Switch (Cmd+Ctrl+Enter)

**Flow:**
```
User: Cmd+Ctrl+Enter on "Call dentist"
├─ Current task: "Clean room" (sibling #2/3 under "Home tasks")
├─ Creates: "Call dentist" (becomes sibling #4)
├─ Switches to: "Call dentist"
└─ iPhone updates: Shows "Call dentist" at position 4/4
```

**Code Path:** Same as Operation #1, but:
- Line 289: `displayTaskId = newSiblingId` (switch to new task)
- Line 362-364: New sibling position = `siblingCount` (goes last by timestamp)

#### 3. Select Sibling from Panel (Cmd+Shift+S)

**Flow:**
```
User: Cmd+Shift+S
├─ Panel shows: All siblings sorted by timestamp
├─ User navigates: Arrow keys or mouse
├─ User selects: Enter or double-click
└─ iPhone updates: Switches to selected sibling with correct position
```

**UI Components:**

**SiblingTableView.swift** - Custom NSTableView subclass
- **Problem Solved:** NSTableView intercepts keyboard events internally, never calling view controller's `keyDown()`
- **Solution:** Subclass NSTableView, override `keyDown()`, forward to delegate
- **Lines 20-34:** Keyboard event handling
  ```swift
  override func keyDown(with event: NSEvent) {
      if event.keyCode == 53 { // Escape
          keyboardDelegate?.siblingTableViewDidPressEscape(self)
      } else if event.keyCode == 36 { // Enter
          keyboardDelegate?.siblingTableViewDidPressEnter(self)
      } else {
          super.keyDown(with: event)  // Let NSTableView handle arrows
      }
  }
  ```
- **Arrow keys:** NSTableView's default behavior (row selection) used naturally
- **Enter/Escape:** Forwarded to view controller via `SiblingTableViewDelegate`

**SiblingSelectorViewController.swift**
- **Lines 92-97:** Enter key handler → triggers `onSiblingSelected` callback
- **Lines 100-102:** Escape key handler → triggers `onCancel` callback
- **Lines 92-97:** Double-click handler → same as Enter (selects sibling)
- **Lines 55:** Sets `keyboardDelegate = self` to receive keyboard events

**SiblingSelectorPanel.swift**
- **Line 16:** `styleMask: [.borderless, .fullSizeContentView]` (NO `.nonactivatingPanel`)
- **Line 70:** `makeKey()` to receive keyboard focus
- **Line 65:** `focusTableView()` to set table as first responder

**Code Path (AppDelegate.swift:467-586):**
1. **showSiblingSelector()** (lines 409-464):
   - Fetch siblings from CloudKit
   - Find current task's index in list
   - Show panel with siblings + currentIndex

2. **handleSiblingSelection()** (lines 467-586):
   - Fetch selected task metadata (parentId, rootId)
   - Update AppState to selected task
   - Fetch parent/root/sibling display info
   - Calculate position: Find task in siblings array
   - Update pointer with all 9 fields
   - Push notification → iPhone refreshes

### Unified Pointer Update Architecture

**Design Principle:** All three operations use the SAME update logic by determining the "display task" first, then fetching/calculating metadata for that task.

**AppDelegate.swift:281-402** (Sibling Creation Flow):
```swift
// Step 1: Determine which task to display
if switchTo {
    displayTask = newSibling
} else {
    displayTask = currentTask
}

// Step 2: Unified update (same code for both paths)
fetchSiblings(parent) {
    count = siblings.count + 1  // Auto-includes new sibling from DB
    position = find(displayTask, in: siblings)
    updatePointer(displayTask, count, position)  // → Push notification
}
```

**Why This Works:**
- **No hardcoded increment logic** - Database is source of truth
- **No special cases** - Both Cmd+Enter and Cmd+Ctrl+Enter use same flow
- **Automatically correct** - Query includes newly saved sibling
- **DRY principle** - Single update path, easier to maintain

### CloudKit Sibling Query

**CloudKitManager.swift:256-285** - `fetchSiblings(parentId:)`

**Query Logic:**
```swift
let predicate = NSPredicate(format: "parent_id == %@", parentId)
let query = CKQuery(recordType: "Task", predicate: predicate)
query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
```

**Returns:** Array of `(id: String, text: String, timestamp: Date)` tuples sorted by creation time

**Why Timestamp Sorting:**
- Stable ordering (new siblings always go last)
- Position calculation: `firstIndex(where: { $0.id == taskId }) + 1`
- Count calculation: `siblings.count` (or `siblings.count + 1` if accounting for just-created sibling)

### Data Flow: Mac → CloudKit → iPhone

**Complete Sibling Update Flow:**

```
Mac: User creates sibling with Cmd+Enter
├─ 1. Save new Task record to CloudKit (with parent_id)
├─ 2. Query siblings: fetchSiblings(parent_id)
├─    └─ Returns: All tasks with same parent (includes new sibling)
├─ 3. Calculate metadata:
├─    - siblingCount = siblings.count + 1 (accounts for index lag)
├─    - siblingPosition = findPosition(currentTask, in: siblings)
├─ 4. Update CurrentTaskPointer with 9 fields:
├─    - currentTaskId, currentTaskText
├─    - parentId, rootId
├─    - parentTaskText, rootTaskText
├─    - showEllipsis
├─    - siblingPosition ← Updated
├─    - siblingCount ← Updated
└─ 5. CloudKit subscription fires

CloudKit: Detects pointer update
├─ Push notification sent to iPhone
└─ Silent content-available notification

iPhone: Receives notification
├─ 1. Fetch CurrentTaskPointer (1 read, instant)
├─ 2. Extract 9 fields from pointer
├─ 3. Update UI state variables:
├─    - siblingPosition = pointer.siblingPosition
├─    - siblingCount = pointer.siblingCount
└─ 4. Render HierarchyView with updated dots
```

**Performance:**
- Mac: 3 reads + 2 writes (parallel fetches via DispatchGroup)
- iPhone: 1 read (no additional queries needed - all in pointer)
- Total sync time: ~500-700ms (depending on network)

### Edge Cases

**Top-Level Task (No Parent):**
- `siblingPosition = nil`
- `siblingCount = nil`
- No dots shown on iPhone

**Single Child (No Siblings):**
- `siblingPosition = 1`
- `siblingCount = 1`
- One dot shown (no sibling navigation needed)

**Newly Created Sibling Not in Query Results (Index Lag):**
- Query returns N siblings (new sibling hasn't indexed yet)
- Count calculation: `siblings.count + 1 = N + 1` (correct)
- Position calculation: New sibling goes last = N + 1 (correct)
- **Solution:** Always add +1 to account for just-saved sibling

**Sibling Selector: Current Task Missing from Results:**
- Line 542-544 (AppDelegate.swift): Add current task to array if missing
- Ensures user can always see their current task in list
- Position still calculated correctly from final array

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

**Purpose**: Singleton record that points to the current task, enabling instant fetch without query index lag. Contains ALL display metadata (hierarchy context, sibling info) so iPhone only needs ONE fetch.

| Field Name        | Type      | Description                                    |
|-------------------|-----------|------------------------------------------------|
| `currentTaskId`   | String    | CloudKit record ID of the current task         |
| `currentTaskText` | String    | Text of the currently active task              |
| `parentId`        | String?   | CloudKit record ID of parent task (nil if top-level) |
| `rootId`          | String?   | CloudKit record ID of root task (nil if level 1-2) |
| `parentTaskText`  | String?   | Text of parent task for hierarchy display      |
| `rootTaskText`    | String?   | Text of root task for hierarchy display        |
| `showEllipsis`    | Int       | 1 if ellipsis needed (level 4+), 0 otherwise (stored as Int, not Bool) |
| `siblingPosition` | Int?      | Position among siblings (1-based index)        |
| `siblingCount`    | Int?      | Total number of siblings (including current)   |
| `timestamp`       | Date/Time | When this pointer was last updated             |

**Record ID**: **Hardcoded to "CURRENT_TASK_POINTER"** (both macOS and iPhone know this ID)

**Current Task Synchronization Flow**:
1. **macOS creates task with Ctrl+Enter/Shift+Enter/Cmd+Ctrl+Enter**
2. **macOS saves Task record** with `isCurrent = true` (backward compatibility)
3. **macOS calls `updateCurrentTaskPointer(taskId, text, parentId, rootId, parentTaskText, rootTaskText, showEllipsis, siblingPosition, siblingCount)`**:
   - Fetches record by ID "CURRENT_TASK_POINTER" (not a query!)
   - If exists: updates ALL 10 fields
   - If not exists: creates new record with this hardcoded ID
   - **Mac calculates everything**: Fetches parent/root texts, calculates ellipsis, queries siblings
4. **CloudKit subscription fires** → notification sent to iPhone
5. **iPhone calls `fetchCurrentTask()`**:
   - Fetches by ID "CURRENT_TASK_POINTER" (bypasses query index - instant!)
   - Extracts ALL 9 fields (taskId, text, parentId, rootId, parentTaskText, rootTaskText, showEllipsis, siblingPosition, siblingCount)
   - **iPhone just reads**: No additional fetches, no calculations needed
6. **Result**: < 1 second sync, no index lag, complete display info in one fetch

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

### 8. Sibling Selection (Mac)
**File**: `HoldApp/AppDelegate.swift`
**Lines**: 386-561
**Trigger**: User presses Cmd+Shift+S
**Action**:
1. Validates current task exists and has parent
2. Fetches siblings via `CloudKitManager.shared.fetchSiblings(parentId:)`
3. Displays `SiblingSelectorPanel` with sibling list
4. User navigates with arrow keys and selects with Enter
5. Fetches selected task's full metadata
6. Updates `CurrentTaskPointer` with all display info (parent/root texts, ellipsis, sibling position)
7. Updates AppState and shows success toast



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
│   ├── AppDelegate.swift             # Mac app lifecycle, task capture, sibling selection coordinator
│   ├── HotkeyManager.swift           # Global keyboard shortcuts (Cmd+Shift+Space, Cmd+Shift+S)
│   ├── SpotlightViewController.swift # Capture bar UI (text field)
│   ├── SpotlightPanel.swift          # Floating window container for Spotlight
│   ├── SiblingSelectorViewController.swift # 🆕 Sibling task list UI (Cmd+Shift+S)
│   ├── SiblingSelectorPanel.swift    # 🆕 Floating window container for sibling selector
│   ├── SubmitTextField.swift         # Custom NSTextField for modifier key detection
│   ├── TaskInputUI.swift             # Protocol for task input interface
│   ├── AppState.swift                # Global state (current task tracking)
│   ├── ToastManager.swift            # Temporary notification messages
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

**Last Updated**: 2025-11-13
**Version**: 1.3 (Updated CloudKit schema documentation - expanded CurrentTaskPointer to 10 fields, documented hierarchy display metadata calculation, updated ContentView/CloudKitManager/AppDelegate documentation to reflect Phase 1-6 implementation)
