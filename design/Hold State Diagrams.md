# Hold - State Diagrams (Final Implementation)

**Version:** 1.0 Final  
**Last Updated:** November 8, 2025

Complete state machine specifications with all decisions locked in. Ready for implementation.

---

## Implementation Priority

Build in this order:
1. **Spotlight (State Machine #1)** - Core capture interface
2. **Task Queue (State Machine #5)** - Current task tracking
3. **Global Actions (State Machine #4)** - Complete/dismiss with blocking
4. **Editor (State Machine #3)** - Management with filter
5. **Parent Selector (State Machine #2)** - Advanced hierarchy
6. **iPhone Display (State Machine #6)** - Passive sync

---

## 1. Spotlight (Entry Bar) State Machine

Primary task capture interface. Opens with `Cmd+Shift+Space`.

```mermaid
stateDiagram-v2
    [*] --> Closed
    
    Closed --> Open_Blank: Cmd+Shift+Space (or brings to front if open)
    
    Open_Blank --> Open_Prefilled_Current: Up Arrow
    Open_Blank --> ParentSelector: Type + Cmd+P
    Open_Blank --> Closed: Esc
    Open_Blank --> TaskCreated_TopLevel: Type + Enter
    Open_Blank --> TaskCreated_TopLevel_Switch: Type + Option+Enter
    Open_Blank --> TaskCreated_Child: Type + Shift+Enter (if current exists)
    Open_Blank --> Error_NoCurrentForChild: Shift+Enter (no current)
    Open_Blank --> TaskCreated_Sibling: Type + Cmd+Enter (if current exists)
    Open_Blank --> Error_NoCurrentForSibling: Cmd+Enter (no current)
    Open_Blank --> TaskCreated_Sibling_Switch: Type + Cmd+Option+Enter (if current exists)
    
    Open_Prefilled_Current --> Open_Prefilled_Current: Up Arrow (idempotent, do nothing)
    Open_Prefilled_Current --> Open_Blank: Down Arrow
    Open_Prefilled_Current --> Closed: Esc (no save)
    Open_Prefilled_Current --> TaskUpdated: Edit + Enter
    
    Open_Blank --> Open_Blank: Down Arrow (idempotent, do nothing)
    
    ParentSelector --> Open_With_Parent_Selected: Select parent + Enter
    ParentSelector --> Open_Blank: Esc (cancel parent selection)
    
    Open_With_Parent_Selected --> ParentSelector: Cmd+P (change parent)
    Open_With_Parent_Selected --> Open_Blank: Clear parent selection
    Open_With_Parent_Selected --> Closed: Esc
    Open_With_Parent_Selected --> TaskCreated_WithParent: Enter
    Open_With_Parent_Selected --> TaskCreated_WithParent_Switch: Option+Enter
    
    Error_NoCurrentForChild --> ShowError_Child: Display toast
    Error_NoCurrentForSibling --> ShowError_Sibling: Display toast
    
    ShowError_Child --> Open_Blank: Fade after 2s
    ShowError_Sibling --> Open_Blank: Fade after 2s
    
    TaskCreated_TopLevel --> ShowConfirmation_TopLevel: Display "✓ Task created"
    TaskCreated_TopLevel_Switch --> ShowConfirmation_TopLevel_Switch: Display "✓ Task created (current)"
    TaskCreated_Child --> ShowConfirmation_Child: Display "✓ Child created under [Current] (current)"
    TaskCreated_Sibling --> ShowConfirmation_Sibling: Display "✓ Sibling created"
    TaskCreated_Sibling_Switch --> ShowConfirmation_Sibling_Switch: Display "✓ Sibling created (current)"
    TaskCreated_WithParent --> ShowConfirmation_WithParent: Display "✓ Task created under [Parent]"
    TaskCreated_WithParent_Switch --> ShowConfirmation_WithParent_Switch: Display "✓ Task created under [Parent] (current)"
    TaskUpdated --> ShowConfirmation_Updated: Display "✓ Task updated"
    
    ShowConfirmation_TopLevel --> Closed: Fade after 1s
    ShowConfirmation_TopLevel_Switch --> Closed: Fade after 1s, iPhone updates
    ShowConfirmation_Child --> Closed: Fade after 1s, iPhone updates
    ShowConfirmation_Sibling --> Closed: Fade after 1s
    ShowConfirmation_Sibling_Switch --> Closed: Fade after 1s, iPhone updates
    ShowConfirmation_WithParent --> Closed: Fade after 1s
    ShowConfirmation_WithParent_Switch --> Closed: Fade after 1s, iPhone updates
    ShowConfirmation_Updated --> Closed: Fade after 1s, iPhone updates if current
    
    Closed --> [*]
    
    note right of Open_Blank
        Primary capture interface
        
        Up Arrow = load current task for editing (idempotent)
        Down Arrow = clear text (idempotent)
        Tab = does nothing (reserved)
        
        Cmd+P = select parent (two-step flow)
        Shift+Enter = create child of current (error if no current)
        Cmd+Enter = create sibling of current (error if no current)
        Cmd+Option+Enter = create sibling and switch
        
        Pressing Cmd+Shift+Space again brings window to front
        (doesn't close, Esc is for closing)
    end note
    
    note right of Error_NoCurrentForChild
        Toast message:
        "⚠️ No parent task. Create a top-level task first."
        
        Duration: 2s fade
        User can still type/interact
        Error doesn't close Spotlight
    end note
    
    note right of Error_NoCurrentForSibling
        Toast message:
        "⚠️ No reference task. Create a task first."
        
        Duration: 2s fade
        User can still type/interact
        Error doesn't close Spotlight
    end note
    
    note right of ParentSelector
        Opens as picker overlay (State Machine #2)
        Navigate: ↑/↓ or Tab (hold Shift to reverse), type to filter
        Enter = select parent and return to Spotlight
        Esc = cancel, return to Spotlight
        Click = select immediately
    end note
    
    note right of Open_With_Parent_Selected
        Returns to Spotlight with parent selected
        Shows: "Task name → Parent Name"
        Can edit text or change parent
        Final submission: Enter or Option+Enter
    end note
```

---

## 2. Parent Selector State Machine

Opened from Spotlight (`Cmd+P`) or Editor (`Cmd+P`). Full task hierarchy tree for parent selection.

```mermaid
stateDiagram-v2
    [*] --> Showing_Full_Tree
    
    Showing_Full_Tree --> Filtered_Tree: Type to filter
    Showing_Full_Tree --> Parent_Selected: Navigate + Enter
    Showing_Full_Tree --> Parent_Selected: Mouse click
    Showing_Full_Tree --> Cancelled: Esc
    
    Filtered_Tree --> Showing_Full_Tree: Clear filter (backspace to empty)
    Filtered_Tree --> More_Filtered: Continue typing
    Filtered_Tree --> Parent_Selected: Navigate + Enter
    Filtered_Tree --> Parent_Selected: Mouse click
    Filtered_Tree --> Cancelled: Esc
    
    More_Filtered --> Filtered_Tree: Backspace
    More_Filtered --> Parent_Selected: Navigate + Enter
    More_Filtered --> Parent_Selected: Mouse click
    More_Filtered --> Cancelled: Esc
    
    Parent_Selected --> [*]: Returns to calling context with parent set
    Cancelled --> [*]: Returns to calling context without parent
    
    note right of Showing_Full_Tree
        Display: Tree with visual hierarchy/indentation
        
        Three ways to navigate and select:
        1. Arrow keys: ↑/↓ to navigate + Enter to select
        2. Tab: Press Tab to navigate (hold Shift to reverse) + Enter to select
        3. Mouse: Click to select immediately
        
        Type to filter tree (narrows visible options)
        Shows full hierarchy for context
        
        Implementation note:
        When called from Editor, reuse Editor's tree view
        (switch to parent selection mode). Same visual,
        different interaction mode.
    end note
    
    note right of Parent_Selected
        If called from Spotlight:
          → Returns to Spotlight with parent selected
          → User sees "Task → Parent", can edit text
          → Final submission with Enter/Option+Enter
        
        If called from Editor:
          → Returns to Editor with parent changed
          → Task's parentId updated immediately
          → Dim/exclude currently selected task (can't self-parent)
          → Show confirmation: "✓ Parent changed to [Parent]"
    end note
```

---

## 3. Editor State Machine

Full task management interface. Opens with `Cmd+Shift+\`.

**Three Modes:**
1. **Tree View** (State 1) - Full hierarchy, empty filter bar visible
2. **Filter Mode** (State 2) - Filter bar focused, flat results
3. **Navigation Mode** (State 3) - Task selected, filter visible but unfocused

```mermaid
stateDiagram-v2
    [*] --> Closed
    
    Closed --> State1_TreeView: Cmd+Shift+\ (or brings to front if open)
    
    State1_TreeView --> State2_FilterFocused: Type any character
    State1_TreeView --> Closed: Esc
    
    State2_FilterFocused --> State2_FilterFocused: Continue typing
    State2_FilterFocused --> State1_TreeView: Backspace to empty
    State2_FilterFocused --> State1_TreeView: Esc
    State2_FilterFocused --> State3_TaskSelected: Tab/Shift+Tab/Arrows
    State2_FilterFocused --> State3_TaskSelected: Enter (select first result)
    State2_FilterFocused --> State1_TreeView: Cmd+P (auto-clear filter, enter parent mode)
    
    State3_TaskSelected --> State2_FilterFocused: Type any character (sticky filter!)
    State3_TaskSelected --> State3_TaskSelected: Tab/Shift+Tab/Arrows (navigate)
    State3_TaskSelected --> State3_TaskSelected: Space (set as current)
    State3_TaskSelected --> State3_TaskSelected: Backspace (dismiss task)
    State3_TaskSelected --> State3_TaskSelected: Cmd+P (change parent)
    State3_TaskSelected --> State3_TaskSelected: Drag task to new parent
    State3_TaskSelected --> State3_TaskSelected: Double-click (set as current)
    State3_TaskSelected --> State1_TreeView: Esc (clear filter)
    State3_TaskSelected --> State2_FilterFocused: Dismiss last task (returns to filter)
    
    Closed --> [*]
    
    note right of State1_TreeView
        **STATE 1: TREE VIEW**
        
        UI:
        - Empty filter bar visible at top (unfocused)
        - Full task tree with hierarchy visible
        - No task selection
        
        Behavior:
        - Type → State 2 (filter activates)
        - Esc → Close editor
        - Pressing Cmd+Shift+\ again brings to front
        
        Filter bar ALWAYS visible for discoverability.
        Even when empty, users see "Filter:" placeholder.
    end note
    
    note right of State2_FilterFocused
        **STATE 2: FILTER MODE - FILTER FOCUSED**
        
        UI:
        - Filter bar focused with cursor blinking
        - Filtered results below (flat list, no hierarchy)
        - Filter bar has accent color/border
        
        Behavior:
        - Type/Space → Add to filter (stay in State 2)
        - Backspace → Edit filter text
        - Backspace to empty → State 1 (tree returns)
        - Enter → Select first filtered task (State 3)
        - Tab (hold Shift to reverse) or Arrows → Navigate to tasks (State 3)
        - Esc → Clear filter (State 1)
        - Cmd+P → Clear filter + parent selection
        
        Filter is "greedy" - captures all typing
    end note
    
    note right of State3_TaskSelected
        **STATE 3: NAVIGATION MODE - TASK SELECTED**
        
        UI:
        - Filter bar visible but unfocused (dimmed)
        - One task highlighted/selected
        - Filter text still visible in bar
        
        Behavior:
        - Type ANY character → State 2 (sticky filter!)
        - Space → Set selected task as current
        - Backspace → Dismiss selected task
        - Delete → Also dismisses task
        - Cmd+P → Change parent of selected task
        - Tab (hold Shift to reverse) or Arrows → Navigate between tasks
        - Double-click → Set as current (same as Space)
        - Drag & Drop → Reparent task
        - Esc → Clear filter (State 1)
        
        KEY: Typing returns to filter bar instantly.
        This enables rapid filter refinement.
        
        If last task dismissed → State 2 (focus to filter)
    end note
```

**Filter Persistence:**
- Filter text persists when Editor closes
- Next open shows previous filter active
- Allows work continuation across sessions

---

## 4. Global Actions State Machine

Global shortcuts that work anywhere: Complete and Dismiss current task.

```mermaid
stateDiagram-v2
    [*] --> Monitoring
    
    Monitoring --> CheckContext_Complete: Cmd+Shift+Enter pressed
    Monitoring --> CheckContext_Dismiss: Cmd+Shift+Backspace pressed
    
    CheckContext_Complete --> BlockedError_Complete: Editor or Spotlight open
    CheckContext_Complete --> CompleteTask: No interface open
    
    CheckContext_Dismiss --> BlockedError_Dismiss: Editor or Spotlight open
    CheckContext_Dismiss --> DismissTask: No interface open
    
    BlockedError_Complete --> ShowError_CloseEditor: Display toast
    BlockedError_Dismiss --> ShowError_CloseSpotlight: Display toast
    
    ShowError_CloseEditor --> Monitoring: Fade after 2s
    ShowError_CloseSpotlight --> Monitoring: Fade after 2s
    
    CompleteTask --> DetermineNext: Mark complete, remove from queue
    DismissTask --> DetermineNext: Remove from queue
    
    DetermineNext --> SetNewCurrent: Next task determined by algorithm
    DetermineNext --> EmptyState: No tasks in queue
    
    SetNewCurrent --> ShowConfirmation: Display result, update iPhone
    EmptyState --> ShowConfirmation: Display "No tasks remaining"
    
    ShowConfirmation --> Monitoring: Fade after 1s
    
    Monitoring --> [*]
    
    note right of CheckContext_Complete
        Before executing global action,
        check if Editor or Spotlight is open.
        
        If open → Block and show error
        If closed → Execute action
        
        This prevents accidental task completion
        while user is actively managing tasks.
    end note
    
    note right of BlockedError_Complete
        Toast message:
        "⚠️ Close Editor to complete current task"
        OR
        "⚠️ Close Spotlight to complete current task"
        
        Duration: 2s fade
        Position: Center of screen
        Non-blocking: User can continue working
    end note
    
    note right of DetermineNext
        Next Task Selection Algorithm:
        
        1. Check for next sibling (chronological)
        2. If no sibling → Return to parent
        3. If no parent → Previous sibling
        4. If none → Next in queue (oldest waiting)
        5. If queue empty → Empty state
        
        This is the single source of truth for
        task advancement logic.
    end note
    
    note right of ShowConfirmation
        Confirmation format:
        Complete: "✓ Completed: [Task Name]
                   Current: [Next Task Name]"
        
        Dismiss: "✓ Dismissed: [Task Name]
                  Current: [Next Task Name]"
        
        Empty: "✓ All tasks completed"
        
        Duration: Fade in 200ms, hold 800ms, fade 200ms
        iPhone updates automatically via CloudKit
    end note
```

---

## 5. Task Queue State Machine

Manages current task pointer and chronological queue.

```mermaid
stateDiagram-v2
    [*] --> EmptyQueue
    
    EmptyQueue --> HasCurrent: Task created with Option modifier
    EmptyQueue --> HasQueue: Task created without Option modifier
    
    HasQueue --> HasCurrent: User sets task as current (Space in Editor)
    HasQueue --> HasQueue: More tasks added
    
    HasCurrent --> HasQueue_and_Current: More tasks added
    HasQueue_and_Current --> HasQueue_and_Current: Tasks added/modified
    
    HasCurrent --> TaskCompleted: Current task completed
    HasCurrent --> TaskDismissed: Current task dismissed
    HasQueue_and_Current --> TaskCompleted: Current task completed
    HasQueue_and_Current --> TaskDismissed: Current task dismissed
    
    TaskCompleted --> DetermineNext: Use next task algorithm
    TaskDismissed --> DetermineNext: Use next task algorithm
    
    DetermineNext --> HasCurrent: Next task exists
    DetermineNext --> HasQueue: Next is in queue (no current)
    DetermineNext --> EmptyQueue: No tasks remaining
    
    note right of EmptyQueue
        No tasks in system
        iPhone shows: "No current task"
        or empty state message
    end note
    
    note right of HasQueue
        Tasks exist but none set as current
        Created with Enter (not Option+Enter)
        Waiting to be addressed
        
        iPhone shows: "No current task"
        Tasks visible in Editor
    end note
    
    note right of HasCurrent
        One task is current focus
        iPhone displays: "[Task Name] | 23:45"
        
        Current pointer stored in:
        - CloudKit (syncs to iPhone)
        - Local state (Mac)
    end note
    
    note right of HasQueue_and_Current
        Standard state during active work:
        - One task is current (iPhone shows it)
        - Other tasks waiting in queue
        - Queue maintains creation order
    end note
    
    note right of DetermineNext
        References the Next Task Selection Algorithm
        from Global Actions state machine.
        
        Single source of truth for advancement logic.
        Ensures consistency across all contexts.
    end note
```

---

## 6. iPhone Display State Machine

Passive display only. No user interaction.

```mermaid
stateDiagram-v2
    [*] --> Listening
    
    Listening --> UpdateReceived: CloudKit sync notification
    Listening --> Listening: Periodic check (every 5s)
    
    UpdateReceived --> ValidateChange: Check current_task_id changed
    
    ValidateChange --> FetchTaskDetails: Current changed
    ValidateChange --> Listening: No change
    
    FetchTaskDetails --> UpdateDisplay: Got task data
    FetchTaskDetails --> ShowEmpty: Task not found or null
    
    UpdateDisplay --> DisplayCurrent: Show task + timestamp
    ShowEmpty --> DisplayEmpty: Show "No current task"
    
    DisplayCurrent --> Listening: Wait for next update
    DisplayEmpty --> Listening: Wait for next update
    
    note right of Listening
        iPhone is passive - no user actions
        
        Updates via:
        1. CloudKit push notifications (2-5s lag)
        2. Periodic polling fallback (5s)
        
        StandBy Mode widget always visible
        when iPhone charging horizontally
    end note
    
    note right of UpdateReceived
        CloudKit notification contains:
        - current_task_id (may be null)
        - last_updated timestamp
        - device_id (which Mac made change)
        
        Validate this is a new change
        (not duplicate notification)
    end note
    
    note right of DisplayCurrent
        Widget shows:
        ┌─────────────────────────┐
        │ Currently:              │
        │ Create embeddings       │
        │ script for HPC          │
        │                         │
        │ 23:45                   │
        └─────────────────────────┘
        
        Large text, readable from across desk
        Time shows "time since set as current"
        Updates every minute
    end note
    
    note right of DisplayEmpty
        Widget shows:
        ┌─────────────────────────┐
        │                         │
        │   No current task       │
        │                         │
        └─────────────────────────┘
        
        Clean, minimal
        No clutter or distractions
    end note
```

---

## State Transition Specifications

### Task Creation Modifiers

| Shortcut | Creates | Switches? | iPhone Update? |
|----------|---------|-----------|----------------|
| `Enter` | Top-level | No | No |
| `Option+Enter` | Top-level | Yes | Yes ✓ |
| `Shift+Enter` | Child | Yes | Yes ✓ |
| `Cmd+Enter` | Sibling | No | No |
| `Cmd+Option+Enter` | Sibling | Yes | Yes ✓ |

**Rule:** iPhone only updates when task becomes current (Option modifier or Shift for child).

### Confirmation Messages

Every user action shows brief toast confirmation:

**Success messages:**
- "✓ Task created"
- "✓ Task created (current)" ← iPhone updates
- "✓ Child created under [Parent] (current)"
- "✓ Sibling created"
- "✓ Sibling created (current)"
- "✓ Task created under [Parent]"
- "✓ Task updated"
- "✓ Task completed"
- "✓ Task dismissed"
- "✓ Parent changed to [Parent]"

**Error messages:**
- "⚠️ No parent task. Create a top-level task first."
- "⚠️ No reference task. Create a task first."
- "⚠️ Close Editor to complete current task"
- "⚠️ Close Spotlight to complete current task"
- "⚠️ Cannot delete task with children"
- "⚠️ Task name required"

**Format:**
- Position: Below action point (Spotlight) or center screen (global)
- Animation: Fade in 200ms, hold 800ms, fade out 200ms
- Style: White background, rounded corners, subtle shadow
- Icon: ✓ for success, ⚠️ for warnings/errors

### Next Task Selection Algorithm

**Single source of truth for task advancement:**

```
When current task is completed or dismissed:

1. Check for next sibling (chronological order)
   → If exists, make it current
   
2. If no next sibling, check for parent
   → Return focus to parent task
   
3. If no parent, check for previous sibling
   → Move back to previous sibling
   
4. If none of above, get next from queue
   → Chronological order (oldest waiting task)
   
5. If queue is empty
   → Empty state (no current task)
```

**Edge cases:**
- Dismissing a parent with children → Blocked (error shown)
- Completing last task in nested structure → Returns up tree
- Queue empty but tree has tasks → Shows empty (manual selection needed)

### Orphaned Tasks (v2)

**MVP behavior:** Block deletion of parent with children
- User must delete/dismiss children first
- Error: "⚠️ Cannot delete task with children"
- Prevents orphans from existing

**v2 consideration:** May add "cascade delete" or "promote to parent's level" options

---

## Implementation Testing Checklist

### State Machine #1: Spotlight
- [ ] Open with Cmd+Shift+Space
- [ ] Type and create with each Enter variation
- [ ] Test Up/Down arrows (idempotent behavior)
- [ ] Test Cmd+P parent selection flow
- [ ] Verify error messages for no current task
- [ ] Test Esc closes without creating

### State Machine #2: Parent Selector
- [ ] Open from Spotlight (Cmd+P)
- [ ] Navigate with arrows, Tab, and mouse
- [ ] Filter tree with typing
- [ ] Select parent and return to Spotlight
- [ ] Test from Editor context (reparenting)

### State Machine #3: Editor
- [ ] Open with Cmd+Shift+\
- [ ] Type to enter filter mode (State 1 → 2)
- [ ] Navigate filtered results (State 2 → 3)
- [ ] Type while task selected (State 3 → 2, sticky!)
- [ ] Test Space to set current
- [ ] Test Backspace to dismiss (context-sensitive)
- [ ] Test filter persistence across reopens
- [ ] Verify filter bar always visible

### State Machine #4: Global Actions
- [ ] Complete task with Cmd+Shift+Enter
- [ ] Dismiss task with Cmd+Shift+Backspace
- [ ] Test blocking when Editor open
- [ ] Test blocking when Spotlight open
- [ ] Verify next task selection algorithm
- [ ] Check confirmation messages display

### State Machine #5: Task Queue
- [ ] Create tasks with/without Option
- [ ] Verify queue order maintained
- [ ] Complete task and check advancement
- [ ] Test empty state reached correctly
- [ ] Verify current pointer syncs

### State Machine #6: iPhone Display
- [ ] Set task on Mac, verify iPhone updates
- [ ] Test 2-5s sync lag acceptable
- [ ] Complete task, verify iPhone shows next
- [ ] Reach empty state, verify iPhone shows "No current task"
- [ ] Test StandBy Mode display

---

## Edge Cases Handled

### In This Implementation
✅ **Up/Down idempotent** - Pressing twice does nothing  
✅ **No current task errors** - Clear guidance to user  
✅ **Global actions blocked** - Prevents accidents when managing tasks  
✅ **Backspace context-sensitive** - Edits filter OR dismisses task  
✅ **Sticky filter** - Typing returns to filter bar  
✅ **Filter persistence** - Remembers last filter  
✅ **Empty queue** - Graceful empty state  
✅ **Parent deletion blocked** - Can't orphan children  

### Deferred to v2
⏸️ **Undo/redo** - Full action history  
⏸️ **Multi-device sync** - Beyond Mac + iPhone  
⏸️ **Conflict resolution** - Two devices edit simultaneously  
⏸️ **Task editing** - Inline edit in Editor  
⏸️ **Right-click menus** - Context menu actions  
⏸️ **Orphan handling** - Alternative to blocking deletion  
⏸️ **Performance at scale** - Tested up to 100 tasks in MVP  

---

## Summary

These six state machines define the complete behavior of Hold:

1. **Spotlight** - Fast task capture with hierarchical creation
2. **Parent Selector** - Visual tree picker for parent selection
3. **Editor** - Three-mode interface for management and filtering
4. **Global Actions** - Complete/dismiss with context-aware blocking
5. **Task Queue** - Current task tracking and advancement
6. **iPhone Display** - Passive sync and display

**All decisions locked.** Ready for UI design phase.

**Key innovations:**
- Sticky filter bar (typing always returns to filter)
- Context-sensitive Backspace (edits OR dismisses)
- Idempotent Up/Down (no accidental triggers)
- Global action blocking (prevents accidents)
- Filter persistence (work continuation)

**Philosophy maintained:**
- Minimal complexity
- Keyboard-first
- Cognitive relief
- Apple-like polish

This is the complete specification. Build it exactly as documented.