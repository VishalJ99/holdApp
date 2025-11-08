# Hold - Implementation Plan

**Version:** 1.0
**Last Updated:** November 8, 2025
**Status:** Ready for Implementation

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Technology Decisions](#technology-decisions)
3. [Current State Analysis](#current-state-analysis)
4. [Architecture Overview](#architecture-overview)
5. [Implementation Phases](#implementation-phases)
6. [Phase Verification Outputs](#phase-verification-outputs)
7. [Detailed Implementation Specs](#detailed-implementation-specs)
8. [Migration Strategy](#migration-strategy)
9. [Testing Checklist](#testing-checklist)
10. [Commit Strategy](#commit-strategy)
11. [Open Questions & Risks](#open-questions--risks)

---

## Executive Summary

### Project Goals

Build the complete Hold app as specified in the design documents, implementing all 6 state machines:

1. **Spotlight (Entry Bar)** - Fast task capture with hierarchical creation modifiers
2. **Parent Selector** - Visual tree picker for parent selection
3. **Editor** - Tree view with 3-state filter system for task management
4. **Global Actions** - Complete/dismiss current task from anywhere
5. **Task Queue** - Current task tracking and advancement logic
6. **iPhone Display** - Passive display of current task with CloudKit sync

### Current State

**Working MVP:**
- ✅ Cmd+Shift+Space opens Spotlight panel
- ✅ Text input with Enter to create task
- ✅ CloudKit sync to iPhone
- ✅ iPhone displays task (full-screen view)
- ✅ 2-5 second sync lag working

**Implementation:**
- AppKit-based macOS app (NSApplicationDelegate)
- Carbon Event Manager for hotkeys (Cmd+Shift+Space, Esc)
- Pure CloudKit (no local persistence)
- SwiftUI for iPhone display
- No hierarchical relationships
- No state management system
- Simple task structure: text, timestamp, isCompleted

### Target State

**Full implementation with:**
- SwiftData + CloudKit for local persistence and automatic sync
- KeyboardShortcuts package for modern hotkey management
- Hierarchical task relationships (parent/child/sibling)
- Current task pointer system
- All 6 state machines fully functional
- Menu bar app with NSStatusItem
- Settings window for hotkey customization
- Cheat sheet overlay (Cmd+?)

---

## Technology Decisions

All architectural and framework choices made during planning:

### UI Framework
- **macOS**: SwiftUI + AppKit hybrid
  - Keep existing AppKit AppDelegate architecture
  - Use NSPanel for Spotlight (existing implementation)
  - SwiftUI for Editor, Parent Selector, Settings
  - NSHostingController to bridge SwiftUI views into AppKit windows
- **iOS**: SwiftUI (existing approach, works great)

### Data Layer
- **SwiftData** for local persistence
  - `@Model` classes for Task entity
  - Local-first architecture (fast, offline-capable)
  - All queries happen locally (instant response)
- **CloudKit** for sync
  - NSPersistentCloudKitContainer for automatic background sync
  - Private database (not public - user data privacy)
  - SwiftData handles conversion to CKRecords automatically
- **Decision**: SwiftData + CloudKit, not pure CloudKit or JSON
  - Rationale: Fast local queries, automatic sync, handles relationships well

### Hotkey System
- **KeyboardShortcuts** Swift package (modern, pure Swift)
  - Replaces existing Carbon Event Manager APIs
  - Easier to extend with new shortcuts
  - Better Swift integration
  - Built-in conflict detection
- **Decision**: Migrate from Carbon to KeyboardShortcuts
  - Rationale: Modern Swift, easier maintenance, can rollback commit if issues
  - Package: https://github.com/sindresorhus/KeyboardShortcuts

### Menu Bar
- **NSStatusItem** (standard macOS approach)
  - Menu bar icon always visible
  - Menu with: Show Spotlight, Show Editor, Settings, Quit
  - No dock icon (menubar-only app feel)

### UI Modularity
- **SwiftUI defaults + constants file**
  - No theming system for MVP
  - Create `UIConstants.swift` with colors, fonts, spacing values
  - Can evolve to theming system in v2 if needed
- **Modular views**: Separate files for each major view component
  - Enables easy UI changes without touching logic

### State Management
- **@Observable** classes (modern Swift concurrency)
  - AppState class for app-wide state
  - TaskManager class for task operations
  - Inject via SwiftUI environment
- **SwiftData ModelContext** for data operations
  - Passed through environment

---

## Current State Analysis

### What Exists (Working MVP)

#### macOS App Structure
**Files:**
- `AppDelegate.swift` - Main entry point, component ownership
- `HotkeyManager.swift` - Carbon-based hotkey registration
- `SpotlightPanel.swift` - NSPanel floating window (600×60px)
- `SpotlightViewController.swift` - NSTextField input with callbacks
- `CloudKitManager.swift` - Pure CloudKit operations
- `LogManager.swift` - File-based backup logging

**Architecture:**
```
AppDelegate
  ├─ HotkeyManager (registers Cmd+Shift+Space, Esc)
  ├─ SpotlightPanel (floating window)
  ├─ SpotlightViewController (text input)
  └─ CloudKitManager (saves to CloudKit)
```

**Hotkey Flow:**
```
Carbon Event: Cmd+Shift+Space
  → HotkeyManager callback
  → AppDelegate.showSpotlight()
  → SpotlightPanel.makeKeyAndOrderFront()
  → User types text
  → Enter pressed
  → SpotlightViewController.onEnterPressed callback
  → CloudKitManager.saveTask(text)
  → CloudKit saves
  → iPhone receives push notification
  → iPhone fetches latest task
```

#### iOS App Structure
**Files:**
- `HoldApp_iOSApp.swift` - SwiftUI App entry + UIApplicationDelegateAdaptor
- `ContentView.swift` - Full-screen task display

**Architecture:**
```
HoldApp_iOSApp (SwiftUI App lifecycle)
  ├─ UIApplicationDelegate for remote notifications
  └─ ContentView
       ├─ Fetches latest incomplete task on launch
       ├─ NotificationCenter listener for "CloudKitTaskUpdated"
       └─ Refetches task when notification received
```

#### CloudKit Configuration
- **Container**: `iCloud.com.vishaljain.HoldApp`
- **Database**: Public (⚠️ should be private)
- **Record Type**: "Task"
  - Fields: text (String), timestamp (Date), isCompleted (Bool)
- **Subscription**: CKQuerySubscription for all Task records
- **Notifications**: Silent push, triggers refetch

#### Current Limitations
- ❌ No local persistence (CloudKit-only)
- ❌ No hierarchical relationships
- ❌ No "current task" pointer (fetches "latest incomplete")
- ❌ No modifier key detection (no Option+Enter, Shift+Enter, etc.)
- ❌ No Up/Down arrow handling
- ❌ No task queue or advancement logic
- ❌ No Editor interface
- ❌ No Parent Selector
- ❌ No Global Actions (complete/dismiss)
- ❌ No menu bar app
- ❌ No state management system

---

## Architecture Overview

### Post-Implementation Architecture

#### macOS App Architecture
```
AppDelegate (NSApplicationDelegate)
  ├─ MenuBarManager
  │    └─ NSStatusItem (menu bar icon)
  │         └─ Menu: Show Spotlight, Editor, Settings, Quit
  │
  ├─ HotkeyManager (KeyboardShortcuts package)
  │    ├─ Cmd+Shift+Space → Show Spotlight
  │    ├─ Cmd+Shift+\ → Show Editor
  │    ├─ Cmd+Shift+Enter → Complete Current
  │    ├─ Cmd+Shift+Backspace → Dismiss Current
  │    └─ Cmd+? → Show Cheat Sheet
  │
  ├─ AppState (@Observable)
  │    ├─ currentTaskId: UUID?
  │    ├─ taskQueue: [UUID]
  │    ├─ isSpotlightOpen: Bool
  │    ├─ isEditorOpen: Bool
  │    └─ filterText: String
  │
  ├─ TaskManager
  │    ├─ ModelContext (SwiftData)
  │    ├─ createTask(...) → Task
  │    ├─ completeTask(id:)
  │    ├─ dismissTask(id:)
  │    ├─ setCurrentTask(id:)
  │    └─ getNextTask() → Task?
  │
  ├─ SpotlightPanel (NSPanel)
  │    └─ SpotlightView (SwiftUI via NSHostingController)
  │         ├─ TextField with modifier detection
  │         ├─ Up/Down arrow handling
  │         └─ Parent selection state
  │
  ├─ EditorWindow (NSWindow)
  │    └─ EditorView (SwiftUI)
  │         ├─ FilterBar (always visible, sticky)
  │         ├─ TaskTreeView (hierarchical list)
  │         └─ 3-state system (Tree → Filter → Navigation)
  │
  ├─ ParentSelectorWindow (NSWindow or Sheet)
  │    └─ ParentSelectorView (SwiftUI)
  │         ├─ Tree picker with filter
  │         └─ Keyboard + mouse navigation
  │
  ├─ SettingsWindow
  │    └─ SettingsView (SwiftUI)
  │         ├─ Keyboard shortcuts customization
  │         └─ Preferences
  │
  └─ ToastManager
       └─ Show confirmation/error toasts
```

#### iOS App Architecture
```
HoldApp_iOSApp (SwiftUI App)
  ├─ UIApplicationDelegate (remote notifications)
  ├─ ModelContainer (SwiftData + CloudKit sync)
  └─ ContentView
       ├─ @Query for current task (isCurrent = true)
       ├─ Auto-updates via SwiftData
       └─ StandBy Mode optimized layout
```

#### Data Model (SwiftData)
```swift
@Model
class Task {
    @Attribute(.unique) var id: UUID
    var text: String
    var createdAt: Date
    var timestamp: Date // For legacy compatibility

    // Hierarchy
    var parent: Task?
    var children: [Task] = []
    var sortOrder: Int // Sibling ordering

    // State
    var isCurrent: Bool = false
    var isCompleted: Bool = false
    var completedAt: Date?
    var dismissedAt: Date?

    // Computed
    var isDismissed: Bool { dismissedAt != nil }
    var isActive: Bool { !isCompleted && !isDismissed }
}
```

#### CloudKit Schema (Auto-generated by SwiftData)
```
Record Type: CD_Task (SwiftData generates this)
Fields:
  - id: String (UUID)
  - text: String
  - createdAt: Date
  - timestamp: Date
  - parentId: Reference (to CD_Task)
  - sortOrder: Int64
  - isCurrent: Bool
  - isCompleted: Bool
  - completedAt: Date (optional)
  - dismissedAt: Date (optional)
```

---

## Implementation Phases

Build incrementally in this order, committing after each milestone:

### Phase 0: Preparation & Foundation
**Goal**: Set up SwiftData, migrate from Carbon hotkeys, create base infrastructure

**Tasks:**
1. Add KeyboardShortcuts package via SPM
2. Create SwiftData Task model
3. Create ModelContainer configuration
4. Create AppState @Observable class
5. Create TaskManager class
6. Create UIConstants.swift
7. Migrate from public to private CloudKit database
8. Set up NSPersistentCloudKitContainer

**Deliverable**: Foundation ready, can create tasks with SwiftData + sync to CloudKit

**Commit**: "Add SwiftData + CloudKit sync foundation"

---

### Phase 1: State Machine #1 - Spotlight Enhancement
**Goal**: Complete Spotlight state machine with all modifiers and variations

**Reference**: Hold State Diagrams.md lines 22-133

**Tasks:**
1. Replace HotkeyManager Carbon APIs with KeyboardShortcuts package
2. Convert SpotlightViewController to SwiftUI view (SpotlightView)
3. Add modifier key detection for Enter key:
   - Detect Option, Shift, Cmd modifiers
   - Implement 5 variations: Enter, Option+Enter, Shift+Enter, Cmd+Enter, Cmd+Option+Enter
4. Implement Up/Down arrow handling:
   - Up: Load current task for editing (idempotent)
   - Down: Clear text (idempotent)
5. Add Cmd+P for parent selection (opens ParentSelector, returns with parent)
6. Create ToastManager for confirmation/error messages
7. Implement task creation logic:
   - Top-level (Enter)
   - Top-level + switch (Option+Enter)
   - Child of current (Shift+Enter) - error if no current
   - Sibling of current (Cmd+Enter) - error if no current
   - Sibling + switch (Cmd+Option+Enter)
8. Show appropriate confirmation toasts
9. Handle errors: "No parent task" and "No reference task"
10. Update current task pointer in AppState
11. Sync to CloudKit automatically (SwiftData handles this)

**Testing Checklist** (from design docs):
- [ ] Open with Cmd+Shift+Space
- [ ] Type and create with each Enter variation
- [ ] Test Up/Down arrows (idempotent behavior)
- [ ] Test Cmd+P parent selection flow (when ParentSelector exists)
- [ ] Verify error messages for no current task
- [ ] Test Esc closes without creating

**Commit**: "Implement Spotlight state machine with all modifiers"

---

### Phase 2: State Machine #5 - Task Queue
**Goal**: Current task tracking and advancement logic

**Reference**: Hold State Diagrams.md lines 392-459

**Tasks:**
1. Implement current task pointer in AppState
2. Create task queue ordering (chronological by createdAt)
3. Implement Next Task Selection Algorithm:
   ```
   When current task completed/dismissed:
   1. Check for next sibling (sortOrder + 1, same parent)
   2. If no sibling → return to parent
   3. If no parent → previous sibling (sortOrder - 1)
   4. If none → next in queue (oldest waiting active task)
   5. If queue empty → empty state (currentTaskId = nil)
   ```
4. Add helper methods to TaskManager:
   - `getNextSibling(of: Task) -> Task?`
   - `getPreviousSibling(of: Task) -> Task?`
   - `getNextInQueue() -> Task?`
   - `advanceToNextTask() -> Task?`
5. Update AppState when current changes
6. Trigger CloudKit sync (automatic via SwiftData)

**Testing Checklist**:
- [ ] Create tasks with/without Option modifier
- [ ] Verify queue order maintained (chronological)
- [ ] Complete task and check advancement follows algorithm
- [ ] Test empty state reached correctly
- [ ] Verify current pointer syncs to iPhone

**Commit**: "Implement task queue and advancement logic"

---

### Phase 3: State Machine #4 - Global Actions
**Goal**: Complete and dismiss current task from anywhere, with blocking

**Reference**: Hold State Diagrams.md lines 304-388

**Tasks:**
1. Register global hotkeys:
   - Cmd+Shift+Enter → Complete current task
   - Cmd+Shift+Backspace → Dismiss current task
2. Implement context-aware blocking:
   - Check `AppState.isSpotlightOpen` and `AppState.isEditorOpen`
   - If either true → show error toast, don't execute
   - If both false → execute action
3. Implement complete task:
   - Set `task.isCompleted = true`
   - Set `task.completedAt = Date()`
   - Call `TaskManager.advanceToNextTask()`
   - Show toast: "✓ Completed: [Task Name]\nCurrent: [Next Task]"
4. Implement dismiss task:
   - Set `task.dismissedAt = Date()`
   - Call `TaskManager.advanceToNextTask()`
   - Show toast: "✓ Dismissed: [Task Name]\nCurrent: [Next Task]"
5. Handle empty state:
   - Show toast: "✓ All tasks completed"
   - Set `AppState.currentTaskId = nil`
6. Update iPhone automatically (SwiftData sync)

**Error Messages**:
- "⚠️ Close Editor to complete current task"
- "⚠️ Close Spotlight to complete current task"

**Testing Checklist**:
- [ ] Complete task with Cmd+Shift+Enter
- [ ] Dismiss task with Cmd+Shift+Backspace
- [ ] Test blocking when Editor open
- [ ] Test blocking when Spotlight open
- [ ] Verify next task selection algorithm works
- [ ] Check confirmation messages display correctly

**Commit**: "Implement global actions with context-aware blocking"

---

### Phase 4: State Machine #3 - Editor
**Goal**: Full task management interface with 3-state filter system

**Reference**:
- Hold State Diagrams.md lines 196-301
- Hold Editor Filter Spec.md (entire document)

**Tasks:**

#### 4.1: Editor Window & Base UI
1. Create EditorWindow (NSWindow, resizable, min 400×600)
2. Create EditorView (SwiftUI)
3. Add filter bar at top (always visible)
4. Add task tree/list view below
5. Register Cmd+Shift+\ hotkey to show/hide
6. Set `AppState.isEditorOpen` when shown/hidden

#### 4.2: State 1 - Tree View
1. Display full task hierarchy:
   - Use SwiftUI List or OutlineGroup
   - Show disclosure triangles for parents
   - Indent children (20px per level)
   - Show current task indicator (★ or bold)
2. Filter bar empty and unfocused (dimmed)
3. Typing any character → State 2

#### 4.3: State 2 - Filter Mode
1. Filter bar focused (cursor blinking, accent border)
2. As user types, filter tasks:
   - Query SwiftData: `text CONTAINS[cd] filterText`
   - Show flat list of matching tasks
   - No hierarchy in results
3. Backspace to empty → State 1 (tree returns)
4. Tab or Arrow keys to navigate results → State 3
5. Enter → select first result → State 3
6. Esc → clear filter → State 1
7. Cmd+P → clear filter, open ParentSelector

#### 4.4: State 3 - Navigation Mode
1. Filter bar visible but unfocused (dimmed)
2. One task highlighted (blue background, left border)
3. Typing any character → State 2 (sticky filter!)
4. Space → set selected task as current
   - Update `AppState.currentTaskId`
   - Show toast: "✓ Set as current: [Task Name]"
5. Backspace → dismiss selected task
   - Set `task.dismissedAt = Date()`
   - If was current, advance to next
   - Show toast: "✓ Dismissed: [Task Name]"
6. Delete → same as Backspace
7. Cmd+P → open ParentSelector for selected task
8. Tab/Shift+Tab/Arrows → navigate between tasks
9. Double-click → set as current (same as Space)
10. Esc → clear filter → State 1
11. If last task dismissed → State 2 (return to filter)

#### 4.5: Filter Persistence
1. Store `AppState.filterText`
2. When Editor closes, keep filterText
3. When reopens, restore filter and state

#### 4.6: Drag & Drop (Defer to v2 if complex)
1. Allow dragging tasks to reparent
2. Show drop indicator
3. Update parent relationship
4. Show toast: "✓ Moved under [New Parent]"

**Testing Checklist**:
- [ ] Open with Cmd+Shift+\
- [ ] Type to enter filter mode (State 1 → 2)
- [ ] Navigate filtered results (State 2 → 3)
- [ ] Type while task selected (State 3 → 2, sticky!)
- [ ] Test Space to set current
- [ ] Test Backspace to dismiss (context-sensitive)
- [ ] Test filter persistence across reopens
- [ ] Verify filter bar always visible
- [ ] Test all keyboard navigation paths

**Commit**: "Implement Editor with 3-state filter system"

---

### Phase 5: State Machine #2 - Parent Selector
**Goal**: Tree picker for parent selection from Spotlight and Editor

**Reference**: Hold State Diagrams.md lines 137-193

**Tasks:**

#### 5.1: Parent Selector Window
1. Create ParentSelectorWindow (NSWindow or sheet)
2. Create ParentSelectorView (SwiftUI)
3. Layout: filter bar + tree view (same as Editor)

#### 5.2: Tree Display
1. Show full task hierarchy
2. Disable/dim currently selected task (can't self-parent)
3. If task has children, disable (can't create cycles)
4. Filter bar for search

#### 5.3: Selection Methods
1. **Keyboard navigation**:
   - Arrow keys: ↑/↓ to navigate
   - Tab: move forward, Shift+Tab: move backward
   - Enter: select highlighted task
2. **Mouse**:
   - Click: select immediately
   - Hover: highlight
3. **Filter**:
   - Type to narrow results
   - Show matching tasks with parent context (dimmed)

#### 5.4: Integration from Spotlight
1. Cmd+P in Spotlight → open ParentSelector
2. User selects parent → return to Spotlight
3. Spotlight shows: "Task Name → Parent Name"
4. User can continue editing or press Enter/Option+Enter to create

#### 5.5: Integration from Editor
1. Cmd+P with task selected → open ParentSelector
2. User selects new parent → update task.parent
3. Show toast: "✓ Parent changed to [Parent Name]"
4. Close ParentSelector, return to Editor

#### 5.6: Cancel
1. Esc → close without selecting
2. Return to calling context (Spotlight or Editor)

**Testing Checklist**:
- [ ] Open from Spotlight (Cmd+P)
- [ ] Navigate with arrows, Tab, and mouse
- [ ] Filter tree with typing
- [ ] Select parent and return to Spotlight
- [ ] Test from Editor context (reparenting)
- [ ] Verify currently selected task is disabled
- [ ] Test Esc to cancel

**Commit**: "Implement Parent Selector with keyboard and mouse navigation"

---

### Phase 6: State Machine #6 - iPhone Display Update
**Goal**: Display current task (not latest task), optimize for StandBy Mode

**Reference**: Hold State Diagrams.md lines 463-535

**Current State**: iPhone fetches "latest incomplete task"

**What's Needed**: Fetch task where `isCurrent = true`

**Tasks:**
1. Update ContentView query:
   ```swift
   // OLD:
   CloudKitManager.fetchCurrentTask() // Gets latest by timestamp

   // NEW:
   @Query(filter: #Predicate<Task> { $0.isCurrent == true })
   var currentTasks: [Task]

   var currentTask: Task? { currentTasks.first }
   ```
2. SwiftData automatically syncs via CloudKit
3. Widget updates when SwiftData detects change (2-5s lag)
4. Display optimizations:
   - Large text (48pt) readable from distance
   - Time display: elapsed since set as current
   - Clean layout for StandBy Mode
5. Empty state: "No current task"

**No WidgetKit extension needed** - full-screen view works in StandBy Mode

**Testing Checklist**:
- [ ] Set task on Mac, verify iPhone updates
- [ ] Test 2-5s sync lag acceptable
- [ ] Complete task, verify iPhone shows next
- [ ] Reach empty state, verify iPhone shows "No current task"
- [ ] Test StandBy Mode display (horizontal layout, readable)

**Commit**: "Update iPhone to display current task via SwiftData sync"

---

### Phase 7: Menu Bar App
**Goal**: NSStatusItem with menu for app access

**Tasks:**
1. Create MenuBarManager class
2. Register NSStatusItem in AppDelegate
3. Create menu bar icon (or use SF Symbol temporarily)
4. Add menu items:
   - "Show Spotlight" (Cmd+Shift+Space)
   - "Show Editor" (Cmd+Shift+\)
   - "Settings..."
   - "---" (separator)
   - "Quit Hold"
5. Remove app from Dock (LSUIElement = true in Info.plist)
6. Launch at login (optional: add login item)

**Commit**: "Add menu bar app with NSStatusItem"

---

### Phase 8: Settings Window
**Goal**: Keyboard shortcuts customization UI

**Reference**: Hold Keyboard Short Cuts UI.md (entire document)

**Tasks:**
1. Create SettingsWindow (NSWindow)
2. Create SettingsView (SwiftUI)
3. Sidebar with sections:
   - General
   - Keyboard Shortcuts
   - About
4. Keyboard Shortcuts section:
   - List all shortcuts by category (Global, Spotlight, Editor, Parent Selector)
   - Show current key combo for each
   - Click to edit (detect new key combo)
   - Conflict detection (warn if conflicts with system)
   - Lock essential shortcuts (Enter, Tab, Esc)
   - Restore Defaults button
5. Use KeyboardShortcuts package for customization
6. Save to UserDefaults
7. Add "Show Cheat Sheet" button

**Commit**: "Implement Settings window with keyboard shortcut customization"

---

### Phase 9: Cheat Sheet Overlay
**Goal**: Cmd+? shows keyboard reference

**Reference**: ui.md lines 549-632

**Tasks:**
1. Register Cmd+? hotkey
2. Create CheatSheetView (SwiftUI)
3. Modal overlay with semi-transparent backdrop
4. Display all shortcuts by category:
   - Global Shortcuts
   - Spotlight Shortcuts
   - Editor Shortcuts
   - Parent Selector Shortcuts
5. Two-column layout: Shortcut | Description
6. Buttons: "Customize Shortcuts" (opens Settings), "Print", "Close"
7. Esc or click outside to close

**Commit**: "Add Cmd+? cheat sheet overlay"

---

### Phase 10: Polish & Final Touches
**Goal**: Visual design, icons, final UX polish

**Tasks:**
1. Apply UI constants throughout (colors, fonts, spacing)
2. Add app icons (macOS and iOS)
3. Animation polish:
   - Toast fade timing (200ms/800ms/200ms)
   - State transitions (200ms ease)
   - Spotlight open/close animation
4. Accessibility:
   - VoiceOver labels
   - Keyboard navigation polish
   - High contrast support
5. Error handling edge cases
6. Performance optimization (if needed)
7. Documentation in code (comments)

**Commit**: "Polish UI and add app icons"

---

## Phase Verification Outputs

**Critical**: Each phase must produce verifiable output so you can confirm it's working correctly before moving to the next phase.

### Debug Tools (Add in Phase 0)

**Debug Menu** in menu bar with commands:
- Print Task Tree (hierarchical console output)
- Print Current Task (details of current)
- Print All Tasks (JSON format)
- Print App State (currentTaskId, window states, filter text)
- Manually Advance to Next Task (executes advancement algorithm without completing/dismissing)
- Open Logs Folder (~/Library/Containers/.../Documents/)

**Enhanced Logging** in TaskManager:
- Log all task creations with parent/child/sibling details
- Log all completions and dismissals
- Log task advancement algorithm steps
- Log errors and state changes

**Implementation note**: See "Detailed Implementation Specs" section for code examples

---

### Phase 0: Foundation - Verification

**What to verify:**
- SwiftData creates and persists tasks
- CloudKit sync working
- Task relationships stored correctly

**How to verify:**
1. Console shows "✅ SwiftData + CloudKit initialized"
2. Create test task via Spotlight
3. Check logs show task creation with all fields
4. Debug Menu → Print Task Tree shows hierarchy with ★ for current
5. CloudKit Dashboard shows CD_Task record

**Success criteria:**
- ✅ Tasks in console tree print
- ✅ Tasks persist after restart
- ✅ CloudKit sync within 5-10 seconds
- ✅ Logs show all operations

---

### Phase 1: Spotlight State Machine - Verification

**What to verify:**
- All modifier key combinations work
- Relationships (parent/child/sibling) created correctly
- Current task pointer updates
- Toasts show correct messages

**How to verify:**
1. Test each Enter variation: Enter, Option+Enter, Shift+Enter, Cmd+Enter, Cmd+Option+Enter
2. Check logs show correct parent/child/sibling relationships
3. Print Task Tree shows hierarchy with proper indentation and ★ for current
4. Test errors when no current task (Shift+Enter, Cmd+Enter should error)
5. Test Up/Down arrows (load current, clear text, idempotent)
6. Verify appropriate toasts appear for each action

**Success criteria:**
- ✅ All 5 Enter variations create correct relationships
- ✅ Tree print shows hierarchy correctly
- ✅ Current task marked with ★
- ✅ Toasts appear for all actions
- ✅ Errors shown when appropriate
- ✅ Up/Down arrows idempotent

---

### Phase 2: Task Queue - Verification

**What to verify:**
- Current task pointer maintained
- Next task algorithm works (all 5 steps)
- Queue state updates

**How to verify:**
1. Create test hierarchy: Parent → Child1 (current) → Child2, plus unrelated task
2. Debug → Print Current Task shows Child1
3. Debug → Manually Advance to Next Task (click 5 times), check logs show:
   - Step 1: Next sibling (Child2)
   - Step 2: Return to parent (Parent)
   - Step 3: Previous sibling (n/a)
   - Step 4: Next in queue (Unrelated)
   - Step 5: Empty state (nil)
4. Verify each step logged with reasoning
5. iPhone updates to show each new current task within 2-5s

**Success criteria:**
- ✅ Advancement follows algorithm exactly
- ✅ Each step logged clearly
- ✅ Empty state reached
- ✅ Current pointer accurate
- ✅ iPhone syncs to show new current task

---

### Phase 3: Global Actions - Verification

**What to verify:**
- Complete/dismiss hotkeys work
- Blocking when Editor/Spotlight open
- Task advancement works
- Toasts correct

**How to verify:**
1. Test Cmd+Shift+Enter completes task, advances to next, shows toast
2. Test Cmd+Shift+Backspace dismisses task, advances to next, shows toast
3. Open Spotlight, try Cmd+Shift+Enter → blocked with error toast
4. Open Editor, try Cmd+Shift+Backspace → blocked with error toast
5. Complete last task → empty state toast shown
6. Debug → Print Current Task confirms empty state

**Success criteria:**
- ✅ Complete/dismiss work and advance
- ✅ Blocking works for both windows
- ✅ Toasts correct
- ✅ Empty state handled

---

### Phase 4: Editor - Verification

**What to verify:**
- All 3 states transition correctly
- Filter narrows results
- Sticky filter works
- Task actions work
- Filter persists

**How to verify:**
1. Cmd+Shift+\ opens Editor showing tree (State 1)
2. Type → filter mode with blue border (State 2), shows matching tasks
3. Tab → task selected, filter dimmed (State 3)
4. Type → returns to filter mode (sticky!)
5. Space sets task as current (★ appears)
6. Backspace dismisses task
7. Close and reopen Editor → filter text persists
8. Debug → Print Task Tree matches visual display

**Success criteria:**
- ✅ All 3 states work
- ✅ Filter narrows real-time
- ✅ Sticky filter on typing
- ✅ Actions work (Space, Backspace)
- ✅ Filter persists
- ✅ Visual matches data

---

### Phase 5: Parent Selector - Verification

**What to verify:**
- Opens from Spotlight and Editor
- Parent selection works
- Returns correctly

**How to verify:**
1. Spotlight → Cmd+P → Parent Selector shows tree
2. Select parent, press Enter → returns to Spotlight showing "Task → Parent"
3. Complete task creation → Debug Tree shows task under parent
4. Editor → select task → Cmd+P → change parent → toast confirms
5. Debug Tree shows new relationship
6. Test Esc cancels selection

**Success criteria:**
- ✅ Opens from both contexts
- ✅ Selection updates correctly
- ✅ Self-parent disabled
- ✅ Returns properly
- ✅ Toast confirms
- ✅ Tree verifies relationship

---

### Phase 6: iPhone Display - Verification

**What to verify:**
- Shows current task (not latest)
- Updates within 2-5s
- Empty state works

**How to verify:**
1. Mac: Set task as current → wait 2-5s → iPhone shows it
2. Mac: Complete task → wait 2-5s → iPhone shows next task
3. Mac: Complete all → wait 2-5s → iPhone shows "No current task"
4. Mac: Create 3 tasks, set 2nd as current → iPhone shows 2nd only
5. Debug → Print Current Task confirms what iPhone should show

**Success criteria:**
- ✅ Shows isCurrent=true task
- ✅ NOT latest by timestamp
- ✅ Updates within 2-5s
- ✅ Empty state correct
- ✅ Verified by Debug menu

---

### Phase 7: Menu Bar - Verification

**What to verify:**
- Menu bar icon appears
- Menu items work
- No dock icon

**How to verify:**
1. Visual: Menu bar icon in top-right
2. Click icon → menu appears with all items
3. Test each menu item opens correct window/quits
4. Dock: No Hold icon present

**Success criteria:**
- ✅ Icon visible
- ✅ Menu functional
- ✅ All items work
- ✅ No dock icon

---

### Phase 8: Settings - Verification

**What to verify:**
- Settings window opens
- Shortcuts customizable
- Changes persist

**How to verify:**
1. Menu → Settings → window opens to Keyboard Shortcuts
2. Click shortcut → press new combo → Set → row updates
3. Test new shortcut works immediately
4. Quit and relaunch → new shortcut still works
5. Restore Defaults → shortcuts reset

**Success criteria:**
- ✅ Settings opens
- ✅ Can customize
- ✅ Works immediately
- ✅ Persists after restart
- ✅ Restore works

---

### Phase 9: Cheat Sheet - Verification

**What to verify:**
- Cmd+? opens overlay
- Shows all shortcuts
- Buttons work

**How to verify:**
1. Cmd+? → overlay appears with all shortcut categories
2. Visual check: all shortcuts from design docs present
3. Click "Customize Shortcuts" → Settings opens
4. Click "Close" or Esc → overlay closes

**Success criteria:**
- ✅ Cmd+? opens
- ✅ All shortcuts listed
- ✅ Buttons work
- ✅ Esc closes

---

### Phase 10: Polish - Verification

**What to verify:**
- Visual consistency
- Animations smooth
- Icons present
- No errors

**How to verify:**
1. Visual: All interfaces use UIConstants colors/fonts/spacing
2. Test animations: Spotlight fade, toast timing, state transitions
3. Check icons: menu bar, app icons (Mac/iOS)
4. Console: No errors, only expected logs
5. VoiceOver: Navigate all interfaces, all elements labeled

**Success criteria:**
- ✅ Visual consistency
- ✅ Animations correct
- ✅ Icons present
- ✅ No console errors
- ✅ Keyboard nav works
- ✅ VoiceOver works## Summary: Verification Strategy

**Every phase includes:**
1. ✅ **Detailed logging** - All operations logged to file and console
2. ✅ **Debug menu** - Quick access to tree prints and state dumps
3. ✅ **Visual feedback** - Toasts confirm all actions
4. ✅ **Console output** - Tree and state prints verify data matches UI
5. ✅ **Specific test cases** - Each phase has clear "how to verify" steps

**Before moving to next phase:**
- Run all verification steps
- Check logs match expected output
- Verify tree structure with Debug → Print Task Tree
- Ensure no console errors
- Test on both Mac and iPhone (where applicable)

This ensures solid foundation at each step before building on top.

---

## Detailed Implementation Specs

### Phase 0: SwiftData + CloudKit Setup

#### 1. Add KeyboardShortcuts Package

**In Xcode:**
1. File → Add Package Dependencies
2. URL: `https://github.com/sindresorhus/KeyboardShortcuts`
3. Add to HoldApp (macOS) target

**Define shortcuts in extension:**

Create `KeyboardShortcuts+Extensions.swift`:
```swift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let showSpotlight = Self("showSpotlight", default: .init(.space, modifiers: [.command, .shift]))
    static let showEditor = Self("showEditor", default: .init(.backslash, modifiers: [.command, .shift]))
    static let completeTask = Self("completeTask", default: .init(.return, modifiers: [.command, .shift]))
    static let dismissTask = Self("dismissTask", default: .init(.delete, modifiers: [.command, .shift]))
    static let showCheatSheet = Self("showCheatSheet", default: .init(.slash, modifiers: [.command, .shift]))
}
```

#### 2. Create SwiftData Task Model

Create `Models/Task.swift`:
```swift
import Foundation
import SwiftData

@Model
final class Task {
    // Identity
    @Attribute(.unique) var id: UUID

    // Content
    var text: String

    // Timestamps
    var createdAt: Date
    var timestamp: Date // For legacy compatibility with existing CloudKit records

    // Hierarchy
    var parent: Task?
    @Relationship(deleteRule: .cascade, inverse: \Task.parent)
    var children: [Task] = []
    var sortOrder: Int // For sibling ordering

    // State
    var isCurrent: Bool = false
    var isCompleted: Bool = false
    var completedAt: Date?
    var dismissedAt: Date?

    // Computed properties
    var isDismissed: Bool {
        dismissedAt != nil
    }

    var isActive: Bool {
        !isCompleted && !isDismissed
    }

    var nextSibling: Task? {
        guard let parent = parent else {
            // Top-level task: find next top-level sibling
            // Will implement in TaskManager
            return nil
        }

        return parent.children
            .filter { $0.sortOrder > self.sortOrder }
            .sorted { $0.sortOrder < $1.sortOrder }
            .first
    }

    var previousSibling: Task? {
        guard let parent = parent else { return nil }

        return parent.children
            .filter { $0.sortOrder < self.sortOrder }
            .sorted { $0.sortOrder > $1.sortOrder }
            .first
    }

    // Initializer
    init(
        text: String,
        parent: Task? = nil,
        sortOrder: Int? = nil,
        isCurrent: Bool = false
    ) {
        self.id = UUID()
        self.text = text
        self.createdAt = Date()
        self.timestamp = Date() // Legacy field
        self.parent = parent

        // Auto-calculate sortOrder if not provided
        if let sortOrder = sortOrder {
            self.sortOrder = sortOrder
        } else if let parent = parent {
            self.sortOrder = (parent.children.map(\.sortOrder).max() ?? -1) + 1
        } else {
            self.sortOrder = 0 // Will be calculated by TaskManager for top-level
        }

        self.isCurrent = isCurrent
    }
}
```

#### 3. Create ModelContainer Configuration

Update `AppDelegate.swift`:
```swift
import SwiftData

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    // SwiftData container
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize SwiftData with CloudKit sync
        do {
            let schema = Schema([Task.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.vishaljain.HoldApp")
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            modelContext = ModelContext(modelContainer)

            print("✅ SwiftData + CloudKit initialized")
        } catch {
            fatalError("Failed to initialize SwiftData: \(error)")
        }

        // Initialize other components...
    }
}
```

**Note**: SwiftData with CloudKit automatically:
- Creates CloudKit schema (CD_Task record type)
- Syncs to private database
- Handles conflict resolution
- Sends push notifications to other devices

#### 4. Migrate CloudKit from Public to Private Database

**Update CloudKitManager.swift** (or remove if using SwiftData exclusively):

Since SwiftData handles CloudKit sync automatically, you can:
- **Option A**: Delete `CloudKitManager.swift` entirely (SwiftData does it all)
- **Option B**: Keep for custom operations, but switch to private DB

**Recommendation**: Option A (delete CloudKitManager, let SwiftData handle it)

#### 5. Create AppState Manager

Create `State/AppState.swift`:
```swift
import Foundation
import Observation

@Observable
final class AppState {
    // Current task
    var currentTaskId: UUID?

    // Window states
    var isSpotlightOpen: Bool = false
    var isEditorOpen: Bool = false
    var isParentSelectorOpen: Bool = false

    // Editor state
    var filterText: String = ""
    var selectedTaskId: UUID?
    var editorMode: EditorMode = .treeView

    enum EditorMode {
        case treeView      // State 1
        case filterFocused // State 2
        case taskSelected  // State 3
    }

    // Singleton (or inject via environment)
    static let shared = AppState()
    private init() {}
}
```

#### 6. Create TaskManager

Create `Managers/TaskManager.swift`:
```swift
import Foundation
import SwiftData

@Observable
final class TaskManager {
    private let modelContext: ModelContext
    private let appState: AppState

    init(modelContext: ModelContext, appState: AppState) {
        self.modelContext = modelContext
        self.appState = appState
    }

    // MARK: - Task Creation

    func createTask(
        text: String,
        parent: Task? = nil,
        setCurrent: Bool = false
    ) -> Task {
        let task = Task(
            text: text,
            parent: parent,
            sortOrder: calculateSortOrder(parent: parent),
            isCurrent: setCurrent
        )

        modelContext.insert(task)

        if setCurrent {
            setCurrentTask(task)
        }

        try? modelContext.save()
        return task
    }

    private func calculateSortOrder(parent: Task?) -> Int {
        if let parent = parent {
            return (parent.children.map(\.sortOrder).max() ?? -1) + 1
        } else {
            // Top-level tasks
            let descriptor = FetchDescriptor<Task>(
                predicate: #Predicate { $0.parent == nil }
            )
            let topLevelTasks = (try? modelContext.fetch(descriptor)) ?? []
            return (topLevelTasks.map(\.sortOrder).max() ?? -1) + 1
        }
    }

    // MARK: - Current Task Management

    func setCurrentTask(_ task: Task) {
        // Clear old current
        if let currentId = appState.currentTaskId,
           let oldCurrent = fetchTask(id: currentId) {
            oldCurrent.isCurrent = false
        }

        // Set new current
        task.isCurrent = true
        appState.currentTaskId = task.id

        try? modelContext.save()
    }

    func getCurrentTask() -> Task? {
        guard let currentId = appState.currentTaskId else { return nil }
        return fetchTask(id: currentId)
    }

    // MARK: - Task Actions

    func completeTask(_ task: Task) {
        task.isCompleted = true
        task.completedAt = Date()

        if task.isCurrent {
            advanceToNextTask()
        }

        try? modelContext.save()
    }

    func dismissTask(_ task: Task) {
        task.dismissedAt = Date()

        if task.isCurrent {
            advanceToNextTask()
        }

        try? modelContext.save()
    }

    // MARK: - Next Task Selection Algorithm

    func advanceToNextTask() {
        guard let current = getCurrentTask() else {
            appState.currentTaskId = nil
            return
        }

        current.isCurrent = false

        // Algorithm from Hold State Diagrams.md lines 583-604

        // 1. Check for next sibling
        if let nextSibling = current.nextSibling {
            setCurrentTask(nextSibling)
            return
        }

        // 2. If no next sibling, return to parent
        if let parent = current.parent {
            setCurrentTask(parent)
            return
        }

        // 3. If no parent, check for previous sibling
        if let previousSibling = current.previousSibling {
            setCurrentTask(previousSibling)
            return
        }

        // 4. If none of above, get next from queue (oldest waiting)
        if let nextInQueue = getNextInQueue() {
            setCurrentTask(nextInQueue)
            return
        }

        // 5. Empty state
        appState.currentTaskId = nil
        try? modelContext.save()
    }

    private func getNextInQueue() -> Task? {
        let descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { task in
                task.isActive && !task.isCurrent
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Queries

    func fetchTask(id: UUID) -> Task? {
        let descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func fetchActiveTasks() -> [Task] {
        let descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func searchTasks(query: String) -> [Task] {
        let descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { task in
                task.isActive && task.text.localizedStandardContains(query)
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
```

#### 7. Create UIConstants

Create `UI/UIConstants.swift`:
```swift
import SwiftUI

enum UIConstants {
    // Colors
    static let primaryBlue = Color(hex: "#007AFF")
    static let successGreen = Color(hex: "#34C759")
    static let warningOrange = Color(hex: "#FF9500")
    static let errorRed = Color(hex: "#FF3B30")

    static let lightGray = Color(hex: "#F5F5F5")
    static let mediumGray = Color(hex: "#E5E5E5")
    static let darkGray = Color(hex: "#D1D1D6")
    static let systemGray = Color(hex: "#8E8E93")

    // Typography
    static let spotlightFontSize: CGFloat = 18
    static let editorFontSize: CGFloat = 14
    static let toastFontSize: CGFloat = 12

    // Spacing
    static let spotlightPadding: CGFloat = 16
    static let editorTaskRowHeight: CGFloat = 32
    static let hierarchyIndentation: CGFloat = 20

    // Dimensions
    static let spotlightWidth: CGFloat = 600
    static let spotlightHeight: CGFloat = 60
    static let spotlightBorderRadius: CGFloat = 10

    // Animations
    static let toastFadeIn: Double = 0.2
    static let toastHold: Double = 0.8
    static let toastFadeOut: Double = 0.2

    static let stateTransition: Double = 0.2
}

// Helper for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

#### 8. Create Debug Menu

Create `Managers/DebugMenuManager.swift`:
```swift
import SwiftUI
import AppKit

final class DebugMenuManager {
    private let taskManager: TaskManager
    private let appState: AppState

    init(taskManager: TaskManager, appState: AppState) {
        self.taskManager = taskManager
        self.appState = appState
    }

    func setupDebugMenu() {
        let mainMenu = NSApplication.shared.mainMenu!

        // Create Debug menu
        let debugMenu = NSMenu(title: "Debug")
        let debugMenuItem = NSMenuItem(title: "Debug", action: nil, keyEquivalent: "")
        debugMenuItem.submenu = debugMenu

        // Add menu items
        debugMenu.addItem(withTitle: "Print Task Tree", action: #selector(printTaskTree), keyEquivalent: "")
        debugMenu.addItem(withTitle: "Print Current Task", action: #selector(printCurrentTask), keyEquivalent: "")
        debugMenu.addItem(withTitle: "Print All Tasks", action: #selector(printAllTasks), keyEquivalent: "")
        debugMenu.addItem(withTitle: "Print App State", action: #selector(printAppState), keyEquivalent: "")
        debugMenu.addItem(NSMenuItem.separator())
        debugMenu.addItem(withTitle: "Manually Advance to Next Task", action: #selector(manuallyAdvanceTask), keyEquivalent: "")
        debugMenu.addItem(NSMenuItem.separator())
        debugMenu.addItem(withTitle: "Open Logs Folder", action: #selector(openLogsFolder), keyEquivalent: "")

        // Insert before Window menu (or append)
        mainMenu.insertItem(debugMenuItem, at: mainMenu.items.count - 1)
    }

    @objc private func printTaskTree() {
        print("\n=== TASK TREE ===")
        let allTasks = taskManager.fetchActiveTasks()
        let topLevel = allTasks.filter { $0.parent == nil }

        for task in topLevel.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            printTask(task, indent: 0)
        }
        print("=================\n")
    }

    private func printTask(_ task: Task, indent: Int) {
        let prefix = String(repeating: "  ", count: indent)
        let indicator = task.isCurrent ? "★ " : ""
        print("\(prefix)\(indicator)\(task.text)")

        for child in task.children.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            printTask(child, indent: indent + 1)
        }
    }

    @objc private func printCurrentTask() {
        print("\n=== CURRENT TASK ===")
        if let current = taskManager.getCurrentTask() {
            print("ID: \(current.id)")
            print("Text: \(current.text)")
            print("Created: \(current.createdAt)")
            print("Parent: \(current.parent?.text ?? "nil")")
            print("Children: \(current.children.count)")
            print("Sort Order: \(current.sortOrder)")
        } else {
            print("No current task")
        }
        print("====================\n")
    }

    @objc private func printAllTasks() {
        print("\n=== ALL TASKS (JSON) ===")
        let tasks = taskManager.fetchActiveTasks()
        for task in tasks {
            let json = """
            {
                "id": "\(task.id)",
                "text": "\(task.text)",
                "isCurrent": \(task.isCurrent),
                "parent": "\(task.parent?.text ?? "null")",
                "sortOrder": \(task.sortOrder)
            }
            """
            print(json)
        }
        print("========================\n")
    }

    @objc private func printAppState() {
        print("\n=== APP STATE ===")
        print("Current Task ID: \(appState.currentTaskId?.uuidString ?? "nil")")
        print("Spotlight Open: \(appState.isSpotlightOpen)")
        print("Editor Open: \(appState.isEditorOpen)")
        print("Parent Selector Open: \(appState.isParentSelectorOpen)")
        print("Filter Text: \"\(appState.filterText)\"")
        print("Editor Mode: \(appState.editorMode)")
        print("=================\n")
    }

    @objc private func manuallyAdvanceTask() {
        print("\n=== MANUALLY ADVANCING TASK ===")
        guard let current = taskManager.getCurrentTask() else {
            print("DEBUG: No current task to advance from")
            print("================================\n")
            return
        }

        print("DEBUG: Advancing from task: \"\(current.text)\"")

        if let next = taskManager.advanceToNextTask() {
            print("DEBUG: Advanced to: \"\(next.text)\"")
        } else {
            print("DEBUG: No more tasks (empty state)")
        }
        print("================================\n")
    }

    @objc private func openLogsFolder() {
        let logsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        NSWorkspace.shared.open(logsURL)
    }
}
```

**What "Manually Advance to Next Task" does:**
1. Calls `TaskManager.advanceToNextTask()` - executes the 5-step algorithm
2. Updates current task pointer (`isCurrent` flags)
3. Logs each step to console with reasoning
4. Syncs to iPhone via SwiftData/CloudKit
5. Does NOT mark old task as completed/dismissed (just moves pointer)

**Use in Phase 2:** Test task queue advancement algorithm before Complete/Dismiss hotkeys exist.

**Initialize in AppDelegate:**
```swift
let debugMenuManager = DebugMenuManager(taskManager: taskManager, appState: appState)
debugMenuManager.setupDebugMenu()
```

---

### Phase 1 Details: Spotlight State Machine

#### Replace HotkeyManager

**Delete:** `HotkeyManager.swift` (Carbon-based)

**Create:** `Managers/HotkeyManager.swift` (KeyboardShortcuts-based):
```swift
import KeyboardShortcuts

final class HotkeyManager {
    private let appState: AppState
    private var observers: [Any] = []

    init(appState: AppState) {
        self.appState = appState
        setupHotkeys()
    }

    private func setupHotkeys() {
        // Show Spotlight
        KeyboardShortcuts.onKeyUp(for: .showSpotlight) { [weak self] in
            self?.showSpotlight()
        }

        // Show Editor
        KeyboardShortcuts.onKeyUp(for: .showEditor) { [weak self] in
            self?.showEditor()
        }

        // Complete Task
        KeyboardShortcuts.onKeyUp(for: .completeTask) { [weak self] in
            self?.completeCurrentTask()
        }

        // Dismiss Task
        KeyboardShortcuts.onKeyUp(for: .dismissTask) { [weak self] in
            self?.dismissCurrentTask()
        }

        // Cheat Sheet
        KeyboardShortcuts.onKeyUp(for: .showCheatSheet) { [weak self] in
            self?.showCheatSheet()
        }
    }

    private func showSpotlight() {
        // Will implement with SpotlightPanel
        NotificationCenter.default.post(name: .showSpotlight, object: nil)
    }

    private func showEditor() {
        NotificationCenter.default.post(name: .showEditor, object: nil)
    }

    private func completeCurrentTask() {
        NotificationCenter.default.post(name: .completeCurrentTask, object: nil)
    }

    private func dismissCurrentTask() {
        NotificationCenter.default.post(name: .dismissCurrentTask, object: nil)
    }

    private func showCheatSheet() {
        NotificationCenter.default.post(name: .showCheatSheet, object: nil)
    }
}

// Notification names
extension Notification.Name {
    static let showSpotlight = Notification.Name("showSpotlight")
    static let showEditor = Notification.Name("showEditor")
    static let completeCurrentTask = Notification.Name("completeCurrentTask")
    static let dismissCurrentTask = Notification.Name("dismissCurrentTask")
    static let showCheatSheet = Notification.Name("showCheatSheet")
}
```

#### Create SpotlightView (SwiftUI)

**Delete:** `SpotlightViewController.swift` (AppKit-based)

**Create:** `Views/SpotlightView.swift`:
```swift
import SwiftUI

struct SpotlightView: View {
    @Environment(\.dismiss) var dismiss
    @State private var text: String = ""
    @State private var selectedParent: Task?
    @State private var showParentSelector: Bool = false

    let appState: AppState
    let taskManager: TaskManager
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Text input
            HStack {
                TextField("Type your task...", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: UIConstants.spotlightFontSize))
                    .onSubmit {
                        // Default: Enter key
                        handleSubmit(modifiers: [])
                    }
                    .onKeyPress(.upArrow) {
                        loadCurrentTask()
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        text = ""
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        onClose()
                        return .handled
                    }
                    // Modifier detection for Enter key
                    .onKeyPress(.return, modifiers: [.option]) {
                        handleSubmit(modifiers: [.option])
                        return .handled
                    }
                    .onKeyPress(.return, modifiers: [.shift]) {
                        handleSubmit(modifiers: [.shift])
                        return .handled
                    }
                    .onKeyPress(.return, modifiers: [.command]) {
                        handleSubmit(modifiers: [.command])
                        return .handled
                    }
                    .onKeyPress(.return, modifiers: [.command, .option]) {
                        handleSubmit(modifiers: [.command, .option])
                        return .handled
                    }
                    // Cmd+P for parent selection
                    .onKeyPress("p", modifiers: [.command]) {
                        showParentSelector = true
                        return .handled
                    }

                if let parent = selectedParent {
                    Text("→ \(parent.text)")
                        .foregroundColor(UIConstants.systemGray)
                        .font(.system(size: 16))
                }

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundColor(UIConstants.systemGray)
                }
                .buttonStyle(.plain)
            }
            .padding(UIConstants.spotlightPadding)
        }
        .frame(width: UIConstants.spotlightWidth, height: UIConstants.spotlightHeight)
        .background(Color.white.opacity(0.95))
        .cornerRadius(UIConstants.spotlightBorderRadius)
        .sheet(isPresented: $showParentSelector) {
            // ParentSelectorView will be created in Phase 5
            // ParentSelectorView(...)
        }
    }

    private func handleSubmit(modifiers: EventModifiers) {
        guard !text.isEmpty else { return }

        let setCurrent = modifiers.contains(.option)

        if modifiers.contains(.shift) {
            // Create child of current
            guard let current = taskManager.getCurrentTask() else {
                ToastManager.shared.showError("No parent task. Create a top-level task first.")
                return
            }
            let task = taskManager.createTask(text: text, parent: current, setCurrent: true)
            ToastManager.shared.showSuccess("Child created under \(current.text) (current)")

        } else if modifiers.contains(.command) && modifiers.contains(.option) {
            // Create sibling and switch
            guard let current = taskManager.getCurrentTask() else {
                ToastManager.shared.showError("No reference task. Create a task first.")
                return
            }
            let task = taskManager.createTask(text: text, parent: current.parent, setCurrent: true)
            ToastManager.shared.showSuccess("Sibling created (current)")

        } else if modifiers.contains(.command) {
            // Create sibling, don't switch
            guard let current = taskManager.getCurrentTask() else {
                ToastManager.shared.showError("No reference task. Create a task first.")
                return
            }
            let task = taskManager.createTask(text: text, parent: current.parent, setCurrent: false)
            ToastManager.shared.showSuccess("Sibling created")

        } else if let parent = selectedParent {
            // Create with selected parent
            let task = taskManager.createTask(text: text, parent: parent, setCurrent: setCurrent)
            let message = setCurrent ? "Task created under \(parent.text) (current)" : "Task created under \(parent.text)"
            ToastManager.shared.showSuccess(message)

        } else {
            // Top-level task
            let task = taskManager.createTask(text: text, parent: nil, setCurrent: setCurrent)
            let message = setCurrent ? "Task created (current)" : "Task created"
            ToastManager.shared.showSuccess(message)
        }

        text = ""
        selectedParent = nil
        onClose()
    }

    private func loadCurrentTask() {
        if let current = taskManager.getCurrentTask() {
            text = current.text
        }
    }
}
```

**Note**: `.onKeyPress` requires macOS 14+. If targeting older versions, use custom NSEvent monitoring.

#### Create ToastManager

Create `Managers/ToastManager.swift`:
```swift
import SwiftUI

@Observable
final class ToastManager {
    static let shared = ToastManager()

    var currentToast: ToastMessage?

    private init() {}

    func showSuccess(_ message: String) {
        show(.success(message))
    }

    func showError(_ message: String) {
        show(.error(message))
    }

    private func show(_ toast: ToastMessage) {
        currentToast = toast

        // Auto-dismiss after timing
        DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
            if self.currentToast == toast {
                self.currentToast = nil
            }
        }
    }

    enum ToastMessage: Equatable {
        case success(String)
        case error(String)

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }

        var iconColor: Color {
            switch self {
            case .success: return UIConstants.successGreen
            case .error: return UIConstants.warningOrange
            }
        }

        var message: String {
            switch self {
            case .success(let msg), .error(let msg): return msg
            }
        }

        var duration: Double {
            UIConstants.toastFadeIn + UIConstants.toastHold + UIConstants.toastFadeOut
        }
    }
}

// Toast View
struct ToastView: View {
    let toast: ToastManager.ToastMessage

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.icon)
                .foregroundColor(toast.iconColor)

            Text(toast.message)
                .font(.system(size: UIConstants.toastFontSize, weight: .medium))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
```

#### Update SpotlightPanel to use SwiftUI

Update `SpotlightPanel.swift`:
```swift
import AppKit
import SwiftUI

class SpotlightPanel: NSPanel {
    private var hostingView: NSHostingView<SpotlightView>?

    init(appState: AppState, taskManager: TaskManager) {
        super.init(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: UIConstants.spotlightWidth,
                height: UIConstants.spotlightHeight
            ),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true

        // Create SwiftUI view
        let spotlightView = SpotlightView(
            appState: appState,
            taskManager: taskManager,
            onClose: { [weak self] in
                self?.hide()
            }
        )

        hostingView = NSHostingView(rootView: spotlightView)
        self.contentView = hostingView

        centerOnScreen()
    }

    func show() {
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        orderOut(nil)
    }

    private func centerOnScreen() {
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - frame.width / 2
            let y = screenRect.midY + screenRect.height / 4 // Top third
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
```

**Continue this pattern for all phases...**

---

## Migration Strategy

### From Pure CloudKit to SwiftData + CloudKit

**Current CloudKit Records:**
```
Record Type: Task
Fields:
  - text: String
  - timestamp: Date
  - isCompleted: Bool
```

**New SwiftData Schema** will create:
```
Record Type: CD_Task (auto-generated by SwiftData)
Fields:
  - id: String (UUID)
  - text: String
  - createdAt: Date
  - timestamp: Date (kept for compatibility)
  - parentId: Reference
  - sortOrder: Int64
  - isCurrent: Bool
  - isCompleted: Bool
  - completedAt: Date (optional)
  - dismissedAt: Date (optional)
```

**Migration Options:**

**Option 1: Start Fresh (Recommended for MVP)**
- Delete all existing Task records from CloudKit
- Start with new schema
- Simpler, no migration code needed

**Option 2: Migrate Existing Data**
1. Fetch all existing "Task" records
2. Create SwiftData Task objects
3. Save to SwiftData (syncs to CloudKit as CD_Task)
4. Delete old "Task" records

**Recommendation**: Option 1 (start fresh). Assuming no production users yet.

---

## Testing Checklist

### Per State Machine

Extracted from Hold State Diagrams.md lines 621-670:

#### Spotlight (State Machine #1)
- [ ] Open with Cmd+Shift+Space
- [ ] Type and create with Enter
- [ ] Create with Option+Enter (switches to current)
- [ ] Create child with Shift+Enter
- [ ] Create sibling with Cmd+Enter
- [ ] Create sibling + switch with Cmd+Option+Enter
- [ ] Test Up arrow (loads current task, idempotent)
- [ ] Test Down arrow (clears text, idempotent)
- [ ] Test Cmd+P parent selection flow
- [ ] Verify error: "No parent task" when Shift+Enter with no current
- [ ] Verify error: "No reference task" when Cmd+Enter with no current
- [ ] Test Esc closes without creating

#### Task Queue (State Machine #5)
- [ ] Create tasks with Enter (not current)
- [ ] Create tasks with Option+Enter (becomes current)
- [ ] Verify queue order is chronological (createdAt)
- [ ] Complete current task, verify next task algorithm
- [ ] Dismiss current task, verify next task algorithm
- [ ] Test empty state (no tasks remaining)
- [ ] Verify current pointer syncs to iPhone

#### Global Actions (State Machine #4)
- [ ] Complete task with Cmd+Shift+Enter
- [ ] Dismiss task with Cmd+Shift+Backspace
- [ ] Verify blocking when Editor open: "Close Editor to complete"
- [ ] Verify blocking when Spotlight open: "Close Spotlight to complete"
- [ ] Test next task selection after complete
- [ ] Test next task selection after dismiss
- [ ] Verify confirmation messages display correctly
- [ ] Test empty state: "All tasks completed"

#### Editor (State Machine #3)
- [ ] Open with Cmd+Shift+\
- [ ] State 1: Tree view shows full hierarchy
- [ ] Type to enter State 2 (filter mode)
- [ ] Filter shows matching tasks (flat list)
- [ ] Backspace to empty returns to State 1
- [ ] Tab to navigate results → State 3
- [ ] State 3: Task selected, filter visible but dimmed
- [ ] Type while in State 3 → returns to State 2 (sticky!)
- [ ] Space sets selected task as current
- [ ] Backspace dismisses selected task
- [ ] Cmd+P changes parent of selected task
- [ ] Filter text persists across Editor close/reopen
- [ ] Verify filter bar always visible in all states
- [ ] Esc clears filter and returns to tree view

#### Parent Selector (State Machine #2)
- [ ] Open from Spotlight with Cmd+P
- [ ] Navigate with arrow keys
- [ ] Navigate with Tab/Shift+Tab
- [ ] Click to select (mouse)
- [ ] Type to filter tree
- [ ] Select parent, return to Spotlight with parent shown
- [ ] Open from Editor (Cmd+P with task selected)
- [ ] Change parent, verify toast confirmation
- [ ] Verify selected task is disabled (can't self-parent)
- [ ] Esc cancels and returns to calling context

#### iPhone Display (State Machine #6)
- [ ] Set task as current on Mac
- [ ] Verify iPhone updates within 2-5 seconds
- [ ] Complete task on Mac
- [ ] Verify iPhone shows next task
- [ ] Reach empty state on Mac
- [ ] Verify iPhone shows "No current task"
- [ ] Test in StandBy Mode (horizontal orientation, charging)
- [ ] Verify text is readable from across desk

### Integration Testing
- [ ] Create hierarchy: parent → child → grandchild
- [ ] Complete grandchild, verify returns to child
- [ ] Complete child, verify returns to parent
- [ ] Create siblings, verify sortOrder maintained
- [ ] Test CloudKit sync Mac ↔ iPhone
- [ ] Test offline mode (airplane mode), verify local operations work
- [ ] Return online, verify sync resumes
- [ ] Test with 100+ tasks (performance check)

---

## Commit Strategy

Commit after every milestone with descriptive messages:

```bash
# Phase 0
git add .
git commit -m "Add SwiftData + CloudKit sync foundation"

# Phase 1
git add .
git commit -m "Implement Spotlight state machine with all modifiers"

# Phase 2
git add .
git commit -m "Implement task queue and advancement logic"

# Phase 3
git add .
git commit -m "Implement global actions with context-aware blocking"

# Phase 4
git add .
git commit -m "Implement Editor with 3-state filter system"

# Phase 5
git add .
git commit -m "Implement Parent Selector with keyboard and mouse navigation"

# Phase 6
git add .
git commit -m "Update iPhone to display current task via SwiftData sync"

# Phase 7
git add .
git commit -m "Add menu bar app with NSStatusItem"

# Phase 8
git add .
git commit -m "Implement Settings window with keyboard shortcut customization"

# Phase 9
git add .
git commit -m "Add Cmd+? cheat sheet overlay"

# Phase 10
git add .
git commit -m "Polish UI and add app icons"
```

**Rules:**
- One commit per major milestone (end of each phase)
- Descriptive messages matching the phase goal
- Ensure code compiles and runs before committing
- Test checklist items for that phase before committing

---

## Open Questions & Risks

### Performance
- **Risk**: Large task counts (1000+) may slow queries
- **Mitigation**: SwiftData indexing, pagination in Editor if needed
- **Test**: Create 1000 tasks, measure Editor load time

### CloudKit Sync
- **Risk**: Conflicts if editing same task on Mac and iPhone simultaneously
- **Mitigation**: SwiftData handles conflict resolution automatically (last-write-wins)
- **Future**: Add manual conflict resolution UI in v2

### Hotkey Conflicts
- **Risk**: Chosen hotkeys may conflict with system or other apps
- **Mitigation**: KeyboardShortcuts package detects some conflicts, Settings UI allows customization
- **Fallback**: Document known conflicts, provide alternative shortcuts

### macOS Version Compatibility
- **Risk**: `.onKeyPress` requires macOS 14+
- **Mitigation**: If targeting macOS 13, use NSEvent monitoring instead
- **Decision**: Target macOS 14+ for MVP (SwiftData requires macOS 14 anyway)

### Migration from Carbon to KeyboardShortcuts
- **Risk**: New package may not work as expected
- **Mitigation**: Can rollback to Carbon commit if issues arise
- **Test**: Verify all hotkeys register and fire correctly

---

## Summary

This implementation plan provides:

✅ **Complete roadmap** from MVP to full 6 state machines
✅ **Technology decisions** locked in (SwiftData + CloudKit, KeyboardShortcuts, SwiftUI hybrid)
✅ **Phase-by-phase breakdown** with testing checklists
✅ **Detailed code examples** for foundation (Phase 0)
✅ **Migration strategy** from current pure CloudKit
✅ **Commit strategy** for incremental progress
✅ **Risk mitigation** for known challenges

**Next Steps:**
1. Review and approve this plan
2. Begin Phase 0: Foundation setup
3. Commit after each phase
4. Test against design doc checklists
5. Iterate until all 6 state machines complete

**Estimated Timeline:**
- Phase 0: 1-2 days
- Phase 1: 2-3 days
- Phase 2: 1 day
- Phase 3: 1 day
- Phase 4: 3-4 days (most complex)
- Phase 5: 2 days
- Phase 6: 0.5 days (simple query update)
- Phase 7: 0.5 days
- Phase 8: 2-3 days
- Phase 9: 1 day
- Phase 10: 1-2 days

**Total: ~15-20 days** for complete implementation

Ready to begin! 🚀
