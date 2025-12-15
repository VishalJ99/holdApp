# Hold - System Architecture

**Last Updated**: December 2024
**Version**: v2.6 (Welcome window onboarding)

---

## Overview

Hold is a local-first task management app with CloudKit synchronization for iPhone display. Tasks are stored locally in JSON on the Mac for instant access, with only a lightweight "current task pointer" synced to CloudKit for iPhone to display what you're currently working on.

**Architecture Principles**:
- **Local-first**: All task data stored in `~/Library/Application Support/HoldApp/tasks.json`
- **Instant operations**: No network lag for task creation/queries
- **Lightweight sync**: Only current task pointer synced to CloudKit (not task content)
- **Customizable**: Both global hotkeys and entry modifiers user-configurable

---

## Local-First Architecture

### The Shift (November 2024)

**Complete elimination of CloudKit Task records.** All task data now stored locally in JSON file. CloudKit only used for CurrentTaskPointer (iPhone sync).

### What Changed

**✅ Added**:
- **LocalTaskStore.swift** - Singleton managing `tasks.json`
  - All task CRUD operations happen locally (instant, no network lag)
  - Synchronous API - no callbacks, no DispatchGroups
  - Functions: `saveTask()`, `fetchRoots()`, `fetchSiblings()`, `fetchTaskById()`, `fetchLatestInTree()`, `clearAllTasks()`, `deleteTask()`, `hasChildren()`, `updateTaskText()`, `fetchLeaves()`, `fetchLeavesDFS()`, `fetchAllTasksInHierarchy()`, `updateTaskParent()`

**❌ Removed from CloudKit**:
- Task records - NO LONGER SAVED TO CLOUDKIT
- All CloudKit Task queries (fetchRoots, fetchSiblings, saveTask)

**🔄 Modified**:
- **AppDelegate** - All task operations now use LocalTaskStore
  - No more DispatchGroup complexity
  - Linear code flow, instant local reads
- **CloudKitManager** - ONLY handles CurrentTaskPointer operations
  - `fetchCurrentTask()` - iPhone reads pointer
  - `updateCurrentTaskPointer()` - Mac updates pointer
  - `clearCurrentTaskPointer()` - Clear when last task dismissed
  - `subscribeToTaskChanges()` - iPhone push notifications

### Benefits

**Performance**:
- 🚀 37x faster root selection (0.37s → <0.01s)
- 🚀 27x faster sibling operations (0.27s → <0.01s)
- 🚀 No CloudKit index lag

**Reliability**:
- ✅ Sibling count bug fixed (pre-query before save)
- ✅ No race conditions
- ✅ Offline support

### Data Flow

```
Mac Task Creation:
1. Generate UUID, save to LocalTaskStore (instant)
2. Fetch sibling/parent metadata from LocalTaskStore (instant)
3. Update CurrentTaskPointer on CloudKit (iPhone sync only)
4. CloudKit subscription fires → iPhone reads pointer → displays task

Root/Sibling Selection:
1. LocalTaskStore.fetchRoots() or fetchSiblings() (instant)
2. Display selector panel
3. User selects → update CurrentTaskPointer → iPhone syncs
```

---

## Core Features

### 1. Task Creation with Entry Modifiers

**3 Independent Modifiers (customizable)**:
- **Child modifier** (default: Shift) - Create child of current task, auto-switch
- **Sibling modifier** (default: Cmd) - Create sibling of current task
- **Switch modifier** (default: Ctrl) - Switch to newly created task

**Compositional Behavior**:
- Enter → Top-level task, no switch
- Shift+Enter → Child + auto-switch
- Cmd+Enter → Sibling, no switch
- Ctrl+Enter → Top-level + switch
- Cmd+Ctrl+Enter → Sibling + switch

**Implementation** (`SpotlightViewController.swift:125-150`):
- Loads modifier preferences from UserDefaults
- Checks which configured modifiers are pressed
- Maps to `TaskCreationType` enum
- Routes to `AppDelegate.handleTaskCreation()`

### 2. Global Hotkeys (Customizable)

**5 Global Hotkeys** (all customizable via Preferences):
1. **Show Spotlight** (default: Cmd+Shift+Space)
2. **Leaf Selector** (default: Cmd+Shift+S) - shows all leaf tasks in current root
3. **Root Selector** (default: Cmd+Shift+R)
4. **Dismiss Task** (default: Cmd+Shift+D)
5. **Nuke All Tasks** (default: Cmd+Shift+Backspace - requires 2 presses)

**Implementation** (`HotkeyManager.swift`):
- Config-driven registration using Carbon Event Manager
- Loads from `HotkeyPreferencesManager` (UserDefaults)
- Falls back to hardcoded defaults if not customized
- Reloads on preference changes via NotificationCenter

### 3. Task Dismissal (Cmd+Shift+D)

**Rules**:
- Can only dismiss leaf tasks (no children)
- Hierarchical navigation (siblings first, then move up):
  1. Youngest leaf sibling (same parent) - stay at same level
  2. Parent if now a leaf (bias toward moving up tree)
  3. Youngest leaf in root (fallback)
  4. Youngest root's youngest leaf (if root gone)
  5. Clear current task (no tasks left)

**Implementation** (`AppDelegate.dismissCurrentTask()`):
- `LocalTaskStore.hasChildren()` blocks dismissal of parents
- `LocalTaskStore.deleteTask()` hard deletes from tasks.json
- `LocalTaskStore.fetchSiblings(parentId)` gets siblings, filtered to leaves only
- `LocalTaskStore.fetchLeaves(rootId)` finds all leaves in root
- Checks if parent is in leaves list (parent became leaf after dismissal)
- Always navigates to a leaf node

### 4. Edit Mode (Up Arrow)

**Trigger**: Press Up Arrow in Spotlight field

**Behavior**:
- Loads current task text into input field
- Changes placeholder to "Editing task... (Press Enter to save)"
- Shows "Editing" flap below the main pill (pencil icon + text)
- Disables modifier keys (only plain Enter works)
- Enter → Updates task text via `LocalTaskStore.updateTaskText()`
- Escape → Hides panel (edit mode reset on next show)
- Down Arrow → Exits edit mode, hides flap, clears field
- **Cmd+P → Re-parent mode**: Opens parent selector to change task's parent

**Re-parent Mode (Cmd+P in Edit Mode)**:
- Triggers `isReparentMode` flag in SpotlightViewController
- Opens OutlineParentSelector showing entire hierarchy
- Validates task cannot be its own parent (shows toast, stays in selector)
- On selection: `AppDelegate.reparentExistingTask()` calls `LocalTaskStore.updateTaskParent()`
- Saves both text changes and new parent together

**State Management** (`SpotlightViewController.swift`):
- `isEditMode: Bool` - tracks whether editing
- `editingTaskId: String?` - ID of task being edited
- `isReparentMode: Bool` - tracks re-parent flow from edit mode
- `resetEditMode()` - clears all edit state (called by Down Arrow, focusTextField)
- `focusTextField()` - always calls `resetEditMode()` on panel show (guards against stale state)

**Implementation Notes**:
- Edit mode entry: `loadCurrentTask()` (line ~265) sets state from `AppState.shared.currentTask`
- Edit mode exit via Enter: `handleTaskUpdate()` calls `resetEditMode()` after save
- Edit mode exit via Down Arrow: `doCommandBy` handler calls `resetEditMode()` (line ~258)
- Edit mode exit via Escape: Panel intercepts Escape directly; `focusTextField()` resets on next show
- Re-parent via Cmd+P: `AppDelegate.reparentExistingTask()` handles parent change and CloudKit sync

### 5. Nuke Button (Cmd+Shift+Backspace)

**Two-Press Confirmation**:
- First press → Shows toast "⚠️ Press again to nuke all tasks"
- Second press (within 3 seconds) → Clears all tasks
- Timer expires → Resets confirmation state

**Implementation** (`AppDelegate.handleNuke()`):
- `nukeConfirmationPending` flag tracks state
- `nukeConfirmationTimer` (3 second timeout)
- Calls `LocalTaskStore.clearAllTasks()` + `CloudKitManager.clearCurrentTaskPointer()`

### 6. Leaf Selector (Cmd+Shift+S)

**Purpose**: Switch to any actionable (leaf) task in current root

**Behavior**:
- Shows all leaf tasks in the current root hierarchy (not just siblings)
- Leaf = task with no children (actionable endpoints)
- Fetches via `LocalTaskStore.fetchLeaves(rootId)`
- Arrow keys navigate, Enter selects
- Updates current task pointer on selection

**Why Leaf instead of Sibling?**
- Siblings = limited to same parent (too restrictive)
- Leaves = all actionable tasks across entire tree (more useful)
- Allows jumping between branches while staying in same root

**Example Tree**:
```
Root: "Complete hold app"
  ├─ "Add hotkeys"
  │   └─ "Test hotkeys" ← LEAF
  └─ "Add preferences"
      └─ "Design UI" ← LEAF
```
Leaf Selector shows both "Test hotkeys" AND "Design UI" (any leaf in root)

**Implementation** (`SwiftUILeafSelector.swift`):
- SwiftUI-based flat list with NSPanel wrapper
- `SwiftUILeafSelectorPanel` - handles keyboard events (arrows, Enter, Escape)
- `LeafSelectorView` - SwiftUI List with header "Select Leaf"
- `LeafRowView` - bullet icon + text + "current" badge
- Styling: `.ultraThinMaterial` blur, 16pt corners, white 0.2 border
- Custom selection highlighting (white 0.15 opacity background)

### 7. Parent Selector (Cmd+P in Spotlight)

**Purpose**: Select any task in hierarchy as parent for new task creation

**Trigger**: Press Cmd+P while typing in Spotlight

**Workflow**:
1. User types task text in Spotlight
2. Presses Cmd+P → Spotlight hides, Parent Selector opens
3. Shows ALL tasks in current root (sorted by depth: root → deepest)
4. User arrows to desired parent, presses:
   - **Enter** → Creates child of selected parent (no switch)
   - **Ctrl+Enter** → Creates child of selected parent + switches to it
   - **Escape** → Cancels, returns to Spotlight with text preserved
5. Task created immediately, both panels close

**Key Features**:
- Shows entire hierarchy flattened (root, siblings, cousins, all tasks)
- Current task highlighted but selectable (can create child of current)
- Text preserved when opening/closing selector
- Parent selection persists if user reopens with Cmd+P

**Implementation**:
- `LocalTaskStore.fetchAllTasksInHierarchy(taskId)` - returns all tasks sorted by depth
- `OutlineParentSelector.swift` - SwiftUI-based tree view with:
  - `OutlineParentSelectorPanel` - NSPanel wrapper with keyboard event handling
  - `OutlineParentSelectorView` - SwiftUI List with recursive DisclosureGroup
  - `ParentItem` - nested tree model built from flat TreeTask array
- `SpotlightViewController` - tracks `selectedParentId` and `preservedText`
- `AppDelegate.createTaskWithCustomParent()` - creates child of selected parent

**Use Case**:
User deep in tree wants to create sibling of root without navigating up:
```
Currently on: "Test hotkey manager" (depth 2)
Wants to create: Sibling of "Complete hold app" (root)
Solution: Cmd+P → Select "Complete hold app" → Enter
Result: New task created as child of root
```

### 8. Root Selector (Cmd+Shift+R)

**Purpose**: Switch to a different root task (top-level project)

**Behavior**:
- Shows flat list of root tasks (parent_id == nil)
- Fetches via `LocalTaskStore.fetchRoots()`
- Arrow keys navigate, Enter selects
- Updates current task pointer to latest task in selected root

**Implementation** (`SwiftUIRootSelector.swift`):
- SwiftUI-based flat list with NSPanel wrapper
- `SwiftUIRootSelectorPanel` - handles keyboard events (arrows, Enter, Escape)
- `RootSelectorView` - SwiftUI List with header "Select Root"
- `RootRowView` - bullet icon + text + "current" badge
- Styling: `.ultraThinMaterial` blur, 16pt corners, white 0.2 border
- Custom selection highlighting (white 0.15 opacity background)

### 9. Menu Bar Icon

**Icon Design**: `{...}` curly braces (176×176 PNG for retina)
**Location**: `Assets.xcassets/hold_icon.imageset/`

**Menu Items**:
- Show Spotlight
- Preferences... (Cmd+,)
- Quit Hold (Cmd+Q)

**Implementation** (`AppDelegate.setupMenuBar()`):
- NSStatusItem with squareLength
- Template mode (adapts to light/dark menu bar)
- Opens preferences window on Cmd+,

---

## Component Architecture

### Mac App Components

#### AppDelegate.swift
**Responsibilities**:
- App lifecycle coordinator
- Task creation/selection/dismissal logic
- Hotkey callbacks
- Preferences window management
- Menu bar setup

**Key Flow**:
```
User presses Cmd+Shift+Space
→ HotkeyManager callback
→ spotlightPanel.show()
→ User types + presses Enter
→ handleTaskCreation(text, type)
→ LocalTaskStore.saveTask()
→ CloudKitManager.updateCurrentTaskPointer()
```

#### LocalTaskStore.swift
**Purpose**: Local JSON file storage for all task data

**Location**: `~/Library/Application Support/HoldApp/tasks.json`

**Core Functions**:
- `saveTask(task)` - Add/update task in JSON
- `fetchRoots()` - Get all tasks where parent_id == nil
- `fetchSiblings(taskId)` - Get all tasks with same parent
- `fetchLeaves(rootId)` - Get all leaf tasks (no children) in a root (timestamp order)
- `fetchLeavesDFS(rootId)` - Get all leaf tasks in DFS tree order (used for leaf indicator)
- `fetchAllTasksInHierarchy(taskId)` - Get all tasks in same root, sorted by depth
- `fetchTaskById(id)` - Lookup single task
- `deleteTask(id)` - Remove task from JSON
- `hasChildren(taskId)` - Check if task has children (blocks dismissal)
- `updateTaskText(id, newText)` - Edit task description
- `updateTaskParent(id, newParentId, newRootId)` - Re-parent task to new location
- `clearAllTasks()` - Empty entire JSON file (nuke)

**Data Structure**:
```json
{
  "tasks": [
    {
      "id": "UUID-string",
      "text": "Task description",
      "parent_id": "UUID-or-null",
      "root_id": "UUID-of-root-task",
      "timestamp": "ISO8601-string",
      "isCompleted": false
    }
  ]
}
```

#### CloudKitManager.swift
**Purpose**: Manages CurrentTaskPointer ONLY (no Task records)

**Functions**:
- `fetchCurrentTask()` - Read pointer (iPhone uses this)
- `updateCurrentTaskPointer(taskId, text, parentId, rootId)` - Write pointer
- `clearCurrentTaskPointer()` - Set all fields to nil (when last task dismissed)
- `subscribeToTaskChanges()` - Setup push notifications for iPhone

**Important**: Does NOT save/query Task records. Only manages the pointer.

#### HotkeyManager.swift
**Purpose**: Global hotkey registration and handling

**Architecture**:
- Uses Carbon Event Manager for system-wide hotkeys
- Loads preferences from `HotkeyPreferencesManager`
- Falls back to hardcoded defaults
- Reloads on `.hotkeyPreferencesChanged` notification

**Event Flow**:
```
1. registerHotkeys() loads from UserDefaults
2. RegisterEventHotKey() tells macOS to intercept key combo
3. Event handler receives hotkey press
4. Routes by hotkeyId to appropriate callback
5. Callback executes (e.g., spotlightPanel.show())
```

#### HotkeyPreferences.swift / EntryModifierPreferences.swift
**Purpose**: Data models and UserDefaults managers

**Storage**:
- Global hotkeys: `com.holdapp.hotkeys` (keyCode + modifiers for 5 hotkeys)
- Entry modifiers: `com.holdapp.entryModifiers` (3 modifier flags)

**Validation**:
- No duplicates within app
- Requires at least one modifier (Cmd/Shift/Ctrl)
- Blocks Option key (macOS text input limitation)

#### PreferencesWindowController.swift
**Purpose**: Tabbed preferences interface

**Tabs**:
1. **Global Hotkeys** - HotkeyRecorderViewController (record buttons)
2. **Entry Modifiers** - EntryModifierViewController (dropdowns)

**Features**:
- Save/Cancel/Restore Defaults buttons
- Real-time validation
- Notification-based reload

#### SpotlightViewController.swift
**Purpose**: Task input field with modifier detection

**Key Components**:
- SubmitTextField (custom NSTextField)
- Modifier detection via `performKeyEquivalent()`
- Edit mode support
- Config-driven modifier→action mapping

**Modifier Detection**:
```swift
1. SubmitTextField.performKeyEquivalent() intercepts Enter
2. Extracts modifiers: event.modifierFlags.intersection([.command, .shift, .control])
3. Calls onSubmit?(modifiers)
4. SpotlightViewController.handleSubmit() loads preferences
5. Checks which configured modifiers are pressed
6. Maps to TaskCreationType enum
```

#### UI Panels
- **SpotlightPanel** - Floating window for task input (AppKit)
- **SwiftUILeafSelectorPanel** - Floating window for leaf list (SwiftUI + NSPanel)
- **SwiftUIRootSelectorPanel** - Floating window for root list (SwiftUI + NSPanel)
- **OutlineParentSelectorPanel** - Floating window for parent tree (SwiftUI + NSPanel)

All panels:
- Borderless, floating window level
- Escape key dismisses
- Arrow key navigation
- SwiftUI panels use `.ultraThinMaterial` blur, 16pt corners, white border

#### ToastManager.swift
**Purpose**: Display temporary notifications with frosted glass aesthetic

**Design Philosophy**: "Toasts should whisper, not shout" - informative without demanding attention

**Toast Levels** (`ToastLevel` enum):
| Level | SF Symbol | Duration | Background |
|-------|-----------|----------|------------|
| success | `checkmark.circle.fill` | 3s | Pure frosted glass |
| info | `info.circle.fill` | 3s | Pure frosted glass |
| warning | `exclamationmark.triangle.fill` | 4s | Pure frosted glass |
| error | `xmark.circle.fill` | 4s | Frosted glass + red 8% tint |

**Visual Design**:
- Material: `.popover` (frosted glass effect)
- Border: 1pt stroke, white 0.2 alpha
- Corner radius: 12px
- Position: Top center, 80px from top
- Animation: Fade + scale (0.95→1.0), respects Reduce Motion

**API**:
```swift
ToastManager.shared.show("Message", level: .success)
ToastManager.shared.show("Error message", level: .error)
```

**Dismiss Message Format**: "Dismissed: {task name}" (truncated to ~40 chars)

**Accessibility**:
- VoiceOver announces level prefix + message
- Reduce Motion disables scale animation

#### WelcomeWindow.swift
**Purpose**: First-launch onboarding walkthrough

**Visual Style**: Matches Spotlight pill (frosted glass, 30px corners, white border)

**Pages** (7 total):
1. Philosophy - "Hold frees your mind"
2. Capture - Cmd+Shift+Space to open Spotlight
3. Hierarchy - Modifier keys for child/sibling/switch
4. Navigate - Leaf/Root selectors, Cmd+P
5. Complete - Dismiss and Nuke shortcuts
6. Customize - Preferences for hotkeys
7. Get Started - Final page with button

**First-Launch Detection**: `UserDefaults.standard.bool(forKey: "hasSeenOnboarding")`

**Navigation**: Arrow keys, chevron buttons, pagination dots

---

### iOS App Components

#### HoldApp_iOSApp.swift
**Purpose**: App lifecycle and push notification handling

**Key Functions**:
- APNs registration
- Push notification handler
- CloudKit subscription setup on launch

#### ContentView.swift
**Purpose**: Display current task hierarchy

**Empty State**: "what are you holding?" (shown when currentTask == nil)

**Data Flow**:
```
1. App launches → subscribeToTaskChanges()
2. Mac updates pointer → CloudKit subscription fires
3. Push notification received → fetchCurrentTask()
4. Update @Published currentTask
5. SwiftUI view updates → displays task hierarchy
```

---

## Data Flow & Synchronization

### Task Creation Flow (Mac → iPhone)

```
1. User types in Spotlight, presses Enter+modifiers
2. SpotlightViewController determines TaskCreationType from modifiers
3. AppDelegate.handleTaskCreation():
   a. Generate UUID for new task
   b. Fetch sibling/parent metadata from LocalTaskStore (instant)
   c. Save task to LocalTaskStore.saveTask() → tasks.json (instant)
   d. Update CloudKitManager.updateCurrentTaskPointer() → CloudKit
4. CloudKit subscription fires → iPhone receives push notification
5. iPhone fetches pointer → displays task hierarchy
```

**Key Difference**: Task content stays on Mac (tasks.json). iPhone only gets pointer fields (id, text, parent_id, root_id) from CloudKit.

### Task Selection Flow (Root/Sibling Selector)

```
1. User presses Cmd+Shift+R (root selector)
2. AppDelegate.showRootSelector():
   a. Fetch roots from LocalTaskStore.fetchRoots() (instant)
   b. Display RootSelectorPanel with table
3. User selects root with arrow keys + Enter
4. AppDelegate.handleRootSelection():
   a. Fetch selected task metadata from LocalTaskStore (instant)
   b. Update current task pointer
   c. CloudKitManager.updateCurrentTaskPointer() → CloudKit
5. CloudKit subscription → iPhone updates display
```

### Task Dismissal Flow

```
1. User presses Cmd+Shift+D
2. AppDelegate.dismissCurrentTask():
   a. Check LocalTaskStore.hasChildren() → blocks if has children
   b. LocalTaskStore.deleteTask() → removes from tasks.json
   c. Navigation priority:
      - Youngest leaf sibling (same parent)
      - Parent if now a leaf
      - Youngest leaf in root
      - Youngest root's youngest leaf
   d. CloudKitManager.updateCurrentTaskPointer() or clear
3. CloudKit subscription → iPhone updates to new current task
```

---

## Storage Schemas

### Local Storage (tasks.json)

**Location**: `~/Library/Application Support/HoldApp/tasks.json`

**Schema**:
```json
{
  "tasks": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "text": "Complete hold app",
      "parent_id": null,
      "root_id": "550e8400-e29b-41d4-a716-446655440000",
      "timestamp": "2024-12-15T10:30:00Z",
      "isCompleted": false
    },
    {
      "id": "660e8400-e29b-41d4-a716-446655440000",
      "text": "Add customizable hotkeys",
      "parent_id": "550e8400-e29b-41d4-a716-446655440000",
      "root_id": "550e8400-e29b-41d4-a716-446655440000",
      "timestamp": "2024-12-15T10:31:00Z",
      "isCompleted": false
    }
  ]
}
```

**Fields**:
- `id`: UUID string (unique identifier)
- `text`: Task description
- `parent_id`: UUID of parent task (null for root tasks)
- `root_id`: UUID of topmost ancestor (for hierarchy display)
- `timestamp`: ISO8601 creation time
- `isCompleted`: Boolean (not currently used)

### CloudKit Schema (Private Database)

**CurrentTaskPointer Record**:

| Field | Type | Description |
|-------|------|-------------|
| `task_id` | String | UUID of current task |
| `task_text` | String | Current task description |
| `parent_id` | String? | Parent task UUID (nil for root) |
| `root_id` | String | Root task UUID (for hierarchy) |
| `siblingPosition` | Int? | Position of leaf in DFS order (1-indexed) |
| `siblingCount` | Int? | Total leaves in root tree |
| `timestamp` | Date | Last update time |
| `is_nuke` | Boolean | True if all tasks nuked (transient flag) |

**Note**: `siblingPosition`/`siblingCount` fields are named for backwards compatibility but store **leaf position in DFS order** (not sibling info).

**Record ID**: Always "CURRENT_TASK_POINTER" (single record, not per-task)

**Important**: This is the ONLY record type in CloudKit. Task content is NOT stored in CloudKit.

---

## Technical Decisions

### Why Local-First?

**Problems with CloudKit-first**:
- Network lag on every query (0.3-0.5s per operation)
- CloudKit index lag causes stale sibling counts
- Race conditions between saves and queries
- Offline mode doesn't work

**Benefits of Local-First**:
- Instant operations (< 0.01s)
- No network dependency for task management
- Deterministic behavior (no index lag)
- Simple linear code flow (no DispatchGroups)

### Why Pointer Pattern?

**Alternative**: Sync all tasks to CloudKit

**Why Not**:
- iPhone only needs current task + hierarchy
- Syncing 1000s of tasks wastes bandwidth/storage
- Pointer is lightweight (5 fields vs full task list)
- Reduces CloudKit usage/cost

### Why Control Instead of Option for Entry Modifiers?

**Attempted**: Option+Enter for "switch to task" modifier

**Problem**: macOS text input system intercepts Option+Enter BEFORE `performKeyEquivalent()` is called. It treats Option as a special character modifier (Option+e = é, etc.).

**Solution**: Use Control key instead. Control+Enter has no text input meaning, so it properly propagates through the event chain.

**Commits**: `11d03a3` (identified problem), `aae6cf3` (switched to Control)

### Why Leaf Indicator with DFS Order?

**Previous Approach**: Show sibling position (e.g., "2 of 3 siblings under same parent")

**Problem**:
- Siblings only show tasks with same parent - too narrow
- Doesn't indicate progress across entire project tree
- User can't tell how many actionable tasks remain in root

**New Approach**: Show leaf position in DFS order across entire root tree

**Benefits**:
- Shows position among ALL actionable tasks (leaves) in project
- DFS order matches visual tree structure (top-left to bottom-right)
- Gives sense of progress through project tree
- More meaningful indicator for task management

**Example**:
```
Root "Project"
├─ "Design"
│   ├─ "Mockup" (leaf) → position 1
│   └─ "Review" (leaf) → position 2
└─ "Build"
    └─ "Code" (leaf) → position 3
```
If on "Review", indicator shows: ○ ● ○ (position 2 of 3 leaves)

### Why Private Database?

**Alternative**: Public database for shared tasks

**Decision**: Private database

**Reasons**:
- Tasks are personal (no sharing needed currently)
- Private database included in free tier
- Simpler permissions model
- Can add public database later for sharing if needed

---

## File Structure

```
HoldApp/
├── HoldApp/                                  # Mac App Target
│   ├── AppDelegate.swift                    # App lifecycle, task coordinator, menu bar
│   ├── LocalTaskStore.swift                 # Local JSON storage (~/Library/Application Support)
│   ├── CloudKitManager.swift                # CurrentTaskPointer sync only
│   ├── HotkeyManager.swift                  # Config-driven global hotkeys (Carbon API)
│   ├── HotkeyPreferences.swift              # Global hotkey data model & manager
│   ├── EntryModifierPreferences.swift       # Entry modifier data model & manager
│   ├── KeyCodeHelper.swift                  # Key code ↔ string conversion
│   ├── PreferencesWindowController.swift    # Tabbed preferences window
│   ├── HotkeyRecorderViewController.swift   # Global hotkeys tab (record buttons)
│   ├── EntryModifierViewController.swift    # Entry modifiers tab (dropdowns)
│   ├── SpotlightViewController.swift        # Task input field controller
│   ├── SpotlightPanel.swift                 # Floating window for Spotlight
│   ├── SubmitTextField.swift                # Custom NSTextField (modifier + Cmd+P detection)
│   ├── SwiftUILeafSelector.swift            # SwiftUI leaf selector (flat list + NSPanel)
│   ├── SwiftUIRootSelector.swift            # SwiftUI root selector (flat list + NSPanel)
│   ├── OutlineParentSelector.swift          # SwiftUI parent selector (tree view + panel)
│   ├── WelcomeWindow.swift                  # First-launch onboarding (pill-style walkthrough)
│   ├── ParentSelectorMockups.swift          # Design mockups for parent selector UI
│   ├── TaskInputUI.swift                    # Protocol for task input
│   ├── AppState.swift                       # Global state (current task)
│   ├── ToastManager.swift                   # Toast notifications (frosted glass, SF Symbols)
│   ├── LogManager.swift                     # Logs to Application Support
│   ├── Assets.xcassets/
│   │   ├── AppIcon.appiconset/              # Mac app icon
│   │   └── hold_icon.imageset/              # Menu bar icon (176×176 PNG)
│   └── HoldApp.entitlements                 # CloudKit + Push capabilities
│
├── HoldApp-iOS/                             # iOS App Target
│   ├── HoldApp_iOSApp.swift                 # iOS lifecycle, APNs, push handler
│   ├── ContentView.swift                    # Display UI, "what are you holding?" empty state
│   ├── Assets.xcassets/
│   │   └── AppIcon.appiconset/              # iOS app icons
│   └── HoldApp-iOS.entitlements             # CloudKit + Push capabilities
│
└── .claude/
    ├── CLAUDE.md                            # Development protocols
    └── SYSTEM_ARCHITECTURE.md               # This file
```

---

## Known Issues & Limitations

### 1. Modifier Key Constraints

**Limitation**: Only Cmd, Shift, and Control keys supported for hotkeys and entry modifiers.

**Why**: Option key is intercepted by macOS text input system before reaching `performKeyEquivalent()`. See commits `11d03a3` and `aae6cf3` for historical context.

**Impact**: Users cannot use Option-based hotkeys.

### 2. System-Wide Hotkey Conflicts

**Issue**: If another app registers the same hotkey, `RegisterEventHotKey()` fails silently.

**Current Behavior**: HotkeyManager logs warning to console but doesn't notify user.

**Workaround**: Users must choose different hotkeys in Preferences.

**Future**: Could add UI notification when hotkey registration fails.

### 3. CloudKit Subscription Activation Delay

**Issue**: iPhone subscription takes ~5-10 seconds to activate on first launch.

**Impact**: First task created after app launch may not push to iPhone immediately.

**Workaround**: Subscription persists across launches, so issue is transient.

### 4. No Task Completion Tracking

**Status**: `isCompleted` field exists in tasks.json but no UI to toggle it.

**Future**: Could add checkbox in Spotlight or separate completion view.

### 5. No Task Editing Beyond Text

**Current**: Can only edit task text (Up Arrow in Spotlight).

**Missing**: Can't change parent, move between roots, or reorder siblings.

**Future**: Could add drag-and-drop or dedicated task editor.

---

## Future Agent Instructions

⚠️ **CRITICAL: If you modify any of the following, you MUST update this document:**

1. **File Structure Changes**:
   - Adding/removing Swift files
   - Changing target membership
   - Renaming key components

2. **Data Model Changes**:
   - tasks.json schema
   - CloudKit record types or fields
   - UserDefaults keys

3. **Architecture Changes**:
   - Data flow modifications
   - New synchronization patterns
   - Storage location changes

4. **Feature Additions**:
   - New MVP features
   - New hotkeys or modifiers
   - New UI components

5. **Bug Fixes with Architectural Impact**:
   - Changes to task creation flow
   - Modifications to CloudKit sync
   - Updates to local storage

**Update Process**:
1. Read this entire document to understand current state
2. Make your code changes
3. Update relevant sections in this document
4. Verify all cross-references are still accurate
5. Update "File Structure" if files added/removed
6. Commit code changes AND documentation updates together

**Keep This Document**:
- Accurate (reflects actual implementation)
- Concise (architecture overview, not code walkthrough)
- Current (update with every significant change)

---

**End of System Architecture Document**
