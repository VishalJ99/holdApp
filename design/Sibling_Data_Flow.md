# Sibling System - Data Flow & Architecture

**Purpose**: Complete documentation of sibling tracking system for architectural decision-making.

**Last Updated**: 2025-11-13
**Status**: Phase 6 Implementation - Identifying Update Logic Bug

---

## Table of Contents

1. [CloudKit Schema](#cloudkit-schema)
2. [AppState (In-Memory)](#appstate-in-memory)
3. [Three Sibling Scenarios](#three-sibling-scenarios)
4. [Data Flow Diagrams](#data-flow-diagrams)
5. [Race Condition Analysis](#race-condition-analysis)
6. [Edge Cases](#edge-cases)
7. [Performance Analysis](#performance-analysis)
8. [Architectural Decisions](#architectural-decisions)

---

## CloudKit Schema

### Task Record

```
Record Type: "Task"
─────────────────────────────────────────
Field           Type      Description
─────────────────────────────────────────
text            String    Task description
timestamp       Date      Creation time (for sibling ordering)
isCompleted     Bool      Completion status
isCurrent       Bool      DEPRECATED (use pointer instead)
parent_id       String?   Parent task's record ID (nil = top-level)
root_id         String?   Root task's record ID (nil = level 1-2)
```

**Key Properties**:
- `parent_id` establishes hierarchy
- `timestamp` determines sibling ordering (ascending = oldest first)
- All siblings share same `parent_id` and `root_id`

### CurrentTaskPointer Record

```
Record Type: "CurrentTaskPointer"
Record ID: "CURRENT_TASK_POINTER" (hardcoded singleton)
─────────────────────────────────────────────────────
Field             Type      Description
─────────────────────────────────────────────────────
currentTaskId     String    Current task's record ID
currentTaskText   String    Current task text
parentId          String?   Parent task's record ID
rootId            String?   Root task's record ID
parentTaskText    String?   Parent text (for hierarchy display)
rootTaskText      String?   Root text (for hierarchy display)
showEllipsis      Int       1 if level 4+, 0 otherwise
siblingPosition   Int?      Current task's position (1-based)
siblingCount      Int?      Total number of siblings
timestamp         Date      Last update time
```

**Key Properties**:
- **Singleton**: Only ONE pointer record exists per user
- **Complete display info**: iPhone fetches this once, has everything needed
- **Update triggers push**: Any field change → notification → iPhone refetches
- **Sibling metadata**: Position and count stored here, not in Task records

---

## AppState (In-Memory)

```swift
// HoldApp/AppState.swift
class AppState {
    struct TaskReference {
        let id: String          // CloudKit record ID
        let text: String        // Task description
        let parentId: String?   // Parent's record ID
        let rootId: String?     // Root's record ID
    }

    var currentTask: TaskReference?  // The task iPhone is displaying
}
```

**What AppState DOES NOT store**:
- ❌ `parentTaskText` - Not in memory
- ❌ `rootTaskText` - Not in memory
- ❌ `showEllipsis` - Not in memory
- ❌ `siblingPosition` - Not in memory
- ❌ `siblingCount` - Not in memory

**Why this matters**: When updating pointer, we need to fetch these fields from somewhere.

---

## Three Sibling Scenarios

### Scenario 1: Create Sibling WITHOUT Switch (Cmd+Enter)

**User Action**: Creates sibling, stays on current task
**Example**: Viewing "Task A" → create "Task B" as sibling → still viewing "Task A"

**Current Implementation** (AppDelegate.swift:373-375):
```swift
} else {
    ToastManager.shared.show("✓ Sibling created", type: .success)
}
```

**Problem**: No pointer update → iPhone shows stale `siblingCount`

**Expected Behavior**:
- New Task record saved with `parent_id = current.parentId`
- **Current task stays displayed** on iPhone (Task A)
- **Sibling count increases** by 1 (iPhone shows one more dot)
- **Position unchanged** (new sibling goes to end due to later timestamp)

**CloudKit Operations Needed**:
| Operation | Type | Purpose |
|-----------|------|---------|
| Save Task record | WRITE | Create new sibling |
| Fetch CurrentTaskPointer | READ | Get existing display metadata |
| Update CurrentTaskPointer | WRITE | Increment siblingCount by 1 |

**Data Flow**:
```
User Input: Cmd+Enter
  ↓
1. Save Task record
   - parent_id: [current.parentId]
   - timestamp: [now] ← Goes to END of sibling list
   ✅ WRITE: Task record created

2. AppState.currentTask unchanged
   - Still referencing Task A

3. Fetch CurrentTaskPointer
   ✅ READ: Get existing fields
   - parentTaskText: "Parent"
   - rootTaskText: "Root"
   - showEllipsis: false
   - siblingPosition: 2
   - siblingCount: 3 ← OLD VALUE

4. Calculate changes
   - siblingCount: 3 + 1 = 4 ← NEW VALUE
   - siblingPosition: 2 ← UNCHANGED (new sibling at end)

5. Update CurrentTaskPointer
   ✅ WRITE: Same task + new count
   - currentTaskId: [Task A ID] ← UNCHANGED
   - currentTaskText: "Task A" ← UNCHANGED
   - parentId: [Parent ID] ← UNCHANGED
   - rootId: [Root ID] ← UNCHANGED
   - parentTaskText: "Parent" ← UNCHANGED (from step 3)
   - rootTaskText: "Root" ← UNCHANGED (from step 3)
   - showEllipsis: false ← UNCHANGED (from step 3)
   - siblingPosition: 2 ← UNCHANGED
   - siblingCount: 4 ← INCREMENTED
   - timestamp: [now]

6. CloudKit subscription fires
   ✅ PUSH NOTIFICATION sent to iPhone

7. iPhone receives notification
   ✅ Refetches pointer
   ✅ Updates UI: [● ● ○ ○] (position 2 of 4)
```

**Total Operations**: 1 READ + 2 WRITES (Task + Pointer)

---

### Scenario 2: Create Sibling WITH Switch (Cmd+Ctrl+Enter)

**User Action**: Creates sibling AND switches to it
**Example**: Viewing "Task A" → create "Task B" as sibling → now viewing "Task B"

**Current Implementation** (AppDelegate.swift:282-372):
```swift
if switchTo {
    AppState.shared.setCurrent(id: taskId, text: text, ...)

    // Fetch parent, root, siblings
    // Calculate display metadata
    // Update pointer with ALL fields
}
```

**Expected Behavior**:
- New Task record saved with `parent_id = current.parentId`
- **New task displayed** on iPhone (Task B)
- **Sibling count increases** by 1
- **Position changes** to last position (new sibling at end)

**CloudKit Operations Needed**:
| Operation | Type | Purpose |
|-----------|------|---------|
| Save Task record | WRITE | Create new sibling |
| Fetch parent task | READ | Get parentTaskText |
| Fetch root task | READ | Get rootTaskText (if exists) |
| Fetch siblings | READ (Query) | Calculate position/count |
| Update CurrentTaskPointer | WRITE | Set new current task + metadata |

**Data Flow**:
```
User Input: Cmd+Ctrl+Enter
  ↓
1. Save Task record
   ✅ WRITE: Task record created

2. AppState.setCurrent(Task B)

3. Parallel fetches (DispatchGroup)

   3a. Fetch parent task (if exists)
       ✅ READ: Get parent.text
       - parentTaskText: "Parent"
       - Also get parent.parent_id for ellipsis calculation

   3b. Fetch root task (if exists)
       ✅ READ: Get root.text
       - rootTaskText: "Root"

   3c. Fetch siblings (query: parent_id = [Parent ID])
       ✅ READ QUERY: Get all siblings
       - Results: [Task A, Task B, Task C, Task D (new)]
       - Sort by timestamp ascending
       - siblingCount: 4
       - siblingPosition: 4 (Task D is last)

4. Calculate ellipsis
   - Logic: parent.parent_id != nil && parent.parent_id != rootId
   - showEllipsis: false (level 3)

5. Update CurrentTaskPointer
   ✅ WRITE: New task + complete metadata
   - currentTaskId: [Task D ID] ← NEW
   - currentTaskText: "Task D" ← NEW
   - parentId: [Parent ID]
   - rootId: [Root ID]
   - parentTaskText: "Parent" ← From step 3a
   - rootTaskText: "Root" ← From step 3b
   - showEllipsis: false ← Calculated
   - siblingPosition: 4 ← From step 3c
   - siblingCount: 4 ← From step 3c
   - timestamp: [now]

6. Push notification → iPhone updates
```

**Total Operations**: 3-4 READS + 2 WRITES
**Note**: Parent/root fetches happen in parallel (DispatchGroup)

---

### Scenario 3: Select Sibling (Cmd+Shift+S)

**User Action**: Opens sibling selector, chooses different sibling
**Example**: Viewing "Task A" (position 2/4) → select "Task C" → now viewing "Task C" (position 3/4)

**Current Implementation** (AppDelegate.swift:388-561):
```swift
showSiblingSelector():
  - Fetch siblings from CloudKit
  - Display panel

handleSiblingSelection(taskId, taskText):
  - ??? (needs implementation)
```

**Expected Behavior**:
- **Selected task displayed** on iPhone (Task C)
- **Sibling count unchanged** (still 4 siblings)
- **Position changes** to selected task's position (3)
- **All hierarchy metadata unchanged** (same parent, root, ellipsis)

**CloudKit Operations Needed**:
| Operation | Type | Purpose |
|-----------|------|---------|
| Fetch siblings | READ (Query) | Populate selector panel (already done in showSiblingSelector) |
| Fetch CurrentTaskPointer | READ | Get existing display metadata |
| Update CurrentTaskPointer | WRITE | Switch to selected sibling |

**Data Flow**:
```
User Input: Cmd+Shift+S
  ↓
1. showSiblingSelector()
   ✅ READ QUERY: Fetch siblings (parent_id = current.parentId)
   - Results: [Task A, Task B, Task C, Task D]
   - Store in memory (panel has this list)

2. User navigates → selects Task C → presses Enter

3. handleSiblingSelection(taskId: [C ID], taskText: "Task C")

   3a. Calculate from in-memory list (no fetch needed!)
       - siblings: [Task A, Task B, Task C, Task D]
       - siblingCount: 4 (already know from array)
       - siblingPosition: 3 (index of Task C + 1)

   3b. Fetch CurrentTaskPointer
       ✅ READ: Get existing display metadata
       - parentTaskText: "Parent"
       - rootTaskText: "Root"
       - showEllipsis: false
       - (ignore old siblingPosition/Count - we have fresh data)

   3c. Update CurrentTaskPointer
       ✅ WRITE: Switch task + update position
       - currentTaskId: [Task C ID] ← NEW
       - currentTaskText: "Task C" ← NEW
       - parentId: [Parent ID] ← UNCHANGED (siblings share parent)
       - rootId: [Root ID] ← UNCHANGED (siblings share root)
       - parentTaskText: "Parent" ← From step 3b (UNCHANGED)
       - rootTaskText: "Root" ← From step 3b (UNCHANGED)
       - showEllipsis: false ← From step 3b (UNCHANGED)
       - siblingPosition: 3 ← Calculated in step 3a
       - siblingCount: 4 ← Calculated in step 3a
       - timestamp: [now]

4. AppState.setCurrent(Task C)

5. Push notification → iPhone updates
```

**Total Operations**: 1 READ (query, already done) + 1 READ (pointer) + 1 WRITE (pointer)

**Optimization**: Sibling list already in memory from panel, no need to refetch!

---

## Data Flow Diagrams

### Visual: Three Scenarios Side-by-Side

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SCENARIO COMPARISON                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Cmd+Enter           Cmd+Ctrl+Enter        Cmd+Shift+S                │
│  (Create, No Switch)  (Create + Switch)     (Select Sibling)           │
│                                                                         │
│  1. WRITE Task       1. WRITE Task         1. READ Query (siblings)   │
│  2. READ Pointer     2. READ Parent        2. READ Pointer            │
│  3. WRITE Pointer    3. READ Root          3. WRITE Pointer           │
│                      4. READ Query (sibs)                              │
│                      5. WRITE Pointer                                  │
│                                                                         │
│  Total: 1R + 2W      Total: 3R + 2W        Total: 2R + 1W             │
│                                                                         │
│  Changes:            Changes:              Changes:                    │
│  - siblingCount +1   - currentTaskId       - currentTaskId            │
│  - All else same     - currentTaskText     - currentTaskText          │
│                      - siblingCount +1      - siblingPosition         │
│                      - siblingPosition     - All else same            │
│                      - All metadata                                    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Detailed: Cmd+Enter (Increment Only)

```
Mac App                      CloudKit                    iPhone App
─────────────────────────────────────────────────────────────────────
1. User types "Task B"
   Presses Cmd+Enter

2. Save Task record      →   WRITE: Task
   text: "Task B"            - parent_id: [Parent ID]
   parent_id: [Parent ID]    - timestamp: 2025-11-13 10:30:15
   timestamp: [now]
                             ✅ Task saved

3. Check switchTo flag
   switchTo = false
   ⚠️  Currently: STOP HERE (BUG!)

4. Fetch CurrentTaskPointer → READ: CurrentTaskPointer
                              - currentTaskId: [Task A ID]
                              - siblingCount: 3
                              - All other fields...

                             ✅ Pointer fetched

5. Increment count
   newCount = 3 + 1 = 4

6. Update Pointer        →   WRITE: CurrentTaskPointer
   siblingCount: 4           - siblingCount: 4 (updated)
   (all else unchanged)      - timestamp: [now]

                             ✅ Pointer updated

7. Subscription fires    →   CloudKit detects pointer change
                             Looks up subscriptions
                             Finds iPhone's device token

                         →   PUSH: Silent notification

                         →                          8. iPhone receives
                                                       notification

                                                    9. Fetch pointer
                         ←   READ: CurrentTaskPointer

                             ✅ Returns all 9 fields

                                                    10. Update UI
                                                        siblingCount: 4
                                                        Render: [● ● ○ ○]
                                                        (position 2 of 4)
```

---

## Race Condition Analysis

### Concurrent Sibling Creation (Double Cmd+Enter)

**Scenario**: User rapidly creates two siblings:
1. Press Cmd+Enter → "Sibling 1"
2. Press Cmd+Enter → "Sibling 2" (before step 1 completes)

**Race Condition Flow**:

```
Timeline    Operation A (Sibling 1)          Operation B (Sibling 2)
─────────────────────────────────────────────────────────────────────
T+0ms       Save Task A
T+50ms                                        Save Task B
T+100ms     Fetch Pointer (siblingCount: 3)
T+120ms                                       Fetch Pointer (siblingCount: 3)
T+200ms     Update Pointer (siblingCount: 4)
T+220ms                                       Update Pointer (siblingCount: 4)

RESULT: siblingCount = 4 (WRONG! Should be 5)
```

**Why It Happens**:
- Both operations read `siblingCount: 3`
- Both calculate `3 + 1 = 4`
- Both write `4`
- Last write wins (both write 4)

**Likelihood**: ⚠️ Low but possible
- Requires user to press Cmd+Enter twice within ~200ms
- CloudKit operations take 100-200ms typically
- Single-user app makes this unlikely

**Consequences**: Minor
- iPhone shows `siblingCount: 4` when actual is `5`
- Missing one dot in display
- Fixes itself on next sibling operation or sibling selection

### Solutions to Race Condition

#### Option A: Do Nothing (Current Approach)
**Pros**:
- Simple, no additional complexity
- Low likelihood in single-user workflow
- Self-correcting on next operation

**Cons**:
- Potential for incorrect count (missing dots)

#### Option B: Optimistic Locking (CloudKit CKModifyRecordsOperation)
**Implementation**:
```swift
// Fetch pointer with ETag
// Update only if ETag matches
// Retry if conflict detected
```

**Pros**:
- Guaranteed consistency
- CloudKit-native solution

**Cons**:
- More complex code
- Retry logic needed
- Slower (additional round-trip on conflict)

#### Option C: Server-Side Atomic Increment (CloudKit Functions)
**Would require**: CloudKit backend function with atomic increment

**Pros**:
- True atomic operation
- No race condition possible

**Cons**:
- Requires CloudKit Functions (not in MVP)
- Additional infrastructure

#### Option D: Query Siblings on Update (Fetch Count)
**Implementation**:
```swift
// Don't increment pointer.siblingCount
// Instead: Query siblings, get actual count
CloudKitManager.shared.fetchSiblings(parentId) { siblings in
    let actualCount = siblings.count
    updatePointer(siblingCount: actualCount, ...)
}
```

**Pros**:
- Always accurate (source of truth)
- No race condition

**Cons**:
- Requires query (slower: 1 query vs 1 read)
- Query has index lag (1-30 seconds)
- Defeats pointer optimization (instant fetch)

**Comparison**:

| Solution | Accuracy | Performance | Complexity | Recommended |
|----------|----------|-------------|------------|-------------|
| **A: Do Nothing** | ⚠️ Usually correct | ✅ Fast | ✅ Simple | ✅ MVP |
| **B: Optimistic Locking** | ✅ Always correct | ⚠️ Slower on conflict | ⚠️ Moderate | Post-MVP |
| **C: Server-Side** | ✅ Always correct | ✅ Fast | ❌ Complex | Future |
| **D: Query Count** | ✅ Always correct | ❌ Slow (query lag) | ✅ Simple | ❌ No |

**Recommendation for MVP**: **Option A** - Accept rare inconsistency, self-corrects quickly.

---

## Edge Cases

### Edge Case 1: First Task Ever (No Pointer)

**Scenario**: User creates first task with Ctrl+Enter

**Current State**:
- No CurrentTaskPointer record exists

**Flow**:
```
1. Save Task A (top-level, no parent)
   ✅ WRITE: Task record

2. switchTo = true

3. Fetch CurrentTaskPointer
   ❌ Record doesn't exist
   Result: All fields = nil

4. Update CurrentTaskPointer
   ✅ WRITE: Create new pointer
   - currentTaskId: [Task A ID]
   - currentTaskText: "Task A"
   - parentId: nil
   - rootId: nil
   - parentTaskText: nil
   - rootTaskText: nil
   - showEllipsis: false
   - siblingPosition: nil
   - siblingCount: nil ← No siblings (only 1 task)
   - timestamp: [now]
```

**Handling in Code**:
```swift
let newCount = (currentPointer.siblingCount ?? 0) + 1
// If nil, 0 + 1 = 1 ✅
```

**Result**: ✅ Handled safely with `?? 0` fallback

---

### Edge Case 2: Top-Level Task (No Parent)

**Scenario**: User creates sibling of top-level task

**Problem**: Top-level tasks have `parent_id = nil`

**Current Protection**:
```swift
case .sibling:
    guard let current = AppState.shared.currentTask else {
        // Error: No current task
    }
    guard current.parentId != nil else {
        // ⚠️  This check is MISSING!
        // Should show error: "Top-level tasks have no siblings"
    }
```

**What Happens Without Check**:
1. User creates Task A (top-level) with Ctrl+Enter
2. User presses Cmd+Enter to create "sibling"
3. New task saved with `parent_id = nil`
4. Both tasks are top-level (NOT siblings!)
5. iPhone shows `siblingCount: 1` (wrong - they're not siblings)

**Fix Needed**: Add validation in `handleTaskCreation()`:
```swift
case .sibling, .siblingAndSwitch:
    guard let current = AppState.shared.currentTask else {
        ToastManager.shared.show("⚠️ No reference task.", type: .error)
        return
    }
    guard current.parentId != nil else {
        ToastManager.shared.show("⚠️ Top-level tasks have no siblings. Use Shift+Enter to create child.", type: .error)
        return
    }
    createSiblingTask(...)
```

---

### Edge Case 3: Pointer Out of Sync

**Scenario**: User creates 5 siblings rapidly, pointer shows count = 3 (race condition)

**Self-Correction Triggers**:

1. **Next sibling creation**:
   - Query siblings → get actual count (5)
   - Update pointer with correct count (5)

2. **Sibling selection (Cmd+Shift+S)**:
   - Query siblings → get actual count (5)
   - Update pointer with correct count (5)

3. **Manual fetch**: User kills/restarts app
   - Pointer still shows 3
   - ⚠️  Doesn't self-correct until next operation

**When It Matters**:
- Only affects sibling dot display
- Doesn't affect task hierarchy
- Doesn't prevent task operations

**Impact**: ⚠️ Low - cosmetic issue, self-corrects on next sibling operation

---

### Edge Case 4: Sibling Deleted Externally

**Scenario**: User has 4 siblings (A, B, C, D), viewing B (position 2/4). Another device deletes sibling C.

**What Happens**:
```
Before: [A, B (current), C, D]
        Position 2 of 4

Action: Device 2 deletes C

After (CloudKit): [A, B, D]
      Actual count: 3

After (Pointer): Still shows position 2/4
                 ⚠️  Out of sync
```

**Self-Correction**: Next sibling operation refetches and updates count

**Note**: Deletion not in MVP scope, but important for future.

---

## Performance Analysis

### Operation Costs

**CloudKit Operation Times** (typical):
- Direct read (by ID): 50-100ms
- Query (fetch siblings): 100-300ms (+ index lag)
- Write (save/update): 100-200ms

### Scenario Performance Comparison

| Scenario | Reads | Queries | Writes | Total Time | User-Perceived Latency |
|----------|-------|---------|--------|------------|------------------------|
| **Cmd+Enter** (increment) | 1 | 0 | 2 | ~300ms | ⚠️ 300ms (blocks toast) |
| **Cmd+Ctrl+Enter** (fetch all) | 2 | 1 | 2 | ~600ms | ✅ Async (toast immediate) |
| **Cmd+Shift+S** (select) | 2 | 1 | 1 | ~400ms | ✅ Panel already open |

**Notes**:
- Cmd+Enter increment is FAST (no queries)
- Parallel fetches (DispatchGroup) reduce latency
- Queries have index lag but happen in background

### Optimization: Where We Save Time

**Original Approach (Cmd+Enter with full fetch)**:
```
1. Save Task       → 150ms
2. Read Parent     → 100ms
3. Read Root       → 100ms
4. Query Siblings  → 200ms
5. Write Pointer   → 150ms
TOTAL: 700ms
```

**Optimized Approach (Cmd+Enter with increment)**:
```
1. Save Task       → 150ms
2. Read Pointer    → 100ms
3. Write Pointer   → 150ms
TOTAL: 400ms (43% faster!)
```

**Savings**: 300ms per operation

---

## Architectural Decisions

### Decision 1: Store Sibling Metadata in Pointer (Not Task Records)

**Why Not Store in Task Records?**

Option A: Add `siblingPosition` and `siblingCount` to each Task record
```
Task A: siblingPosition = 1, siblingCount = 4
Task B: siblingPosition = 2, siblingCount = 4
Task C: siblingPosition = 3, siblingCount = 4
Task D: siblingPosition = 4, siblingCount = 4
```

**Problems**:
- ❌ Denormalized data (4 records need update when count changes)
- ❌ Consistency issues (what if Task A shows count=4, Task B shows count=3?)
- ❌ More writes (4 writes vs 1 write to pointer)
- ❌ Race conditions multiply (4x more opportunities for conflict)

Option B: Store only in CurrentTaskPointer (current approach)
```
CurrentTaskPointer:
  siblingPosition = 2
  siblingCount = 4
```

**Advantages**:
- ✅ Single source of truth
- ✅ One write operation
- ✅ Only current task needs metadata (iPhone only displays one task)
- ✅ Minimal race condition surface

**Decision**: ✅ Store in pointer only

---

### Decision 2: Increment vs Query for Sibling Count

**Option A: Increment Pointer Field**
```swift
let newCount = (currentPointer.siblingCount ?? 0) + 1
updatePointer(siblingCount: newCount, ...)
```

**Pros**:
- Fast (no query)
- No index lag
- Minimal operations

**Cons**:
- Race condition possible (rare)
- Can drift from source of truth

**Option B: Always Query Siblings**
```swift
fetchSiblings(parentId) { siblings in
    let actualCount = siblings.count
    updatePointer(siblingCount: actualCount, ...)
}
```

**Pros**:
- Always accurate
- No race condition

**Cons**:
- Slower (query operation)
- Index lag (1-30 seconds)
- Defeats pointer optimization

**Decision**: ✅ **Option A for MVP** - Increment for speed, accept rare drift
- Rationale: Performance > perfect accuracy for single-user app
- Future: Implement optimistic locking if multi-user or seeing issues

---

### Decision 3: When to Fetch Full Metadata

**Three Patterns**:

1. **Full Fetch** (Cmd+Ctrl+Enter, first-time):
   - Fetch parent, root, query siblings
   - Use when: Switching to new task, need ALL fields

2. **Incremental Update** (Cmd+Enter):
   - Fetch pointer only, increment count
   - Use when: Same task, only sibling count changes

3. **Hybrid** (Cmd+Shift+S):
   - Use cached siblings from panel, fetch pointer for metadata
   - Use when: Have some data in memory, need rest

**Rule**:
- If switching task (changing currentTaskId) → Full fetch
- If same task, count change → Increment
- If have cached data → Reuse it

**Decision**: ✅ Use most efficient pattern for each scenario

---

## Summary: Implementation Checklist

### ✅ Already Implemented
- [x] CloudKit schema (Task + CurrentTaskPointer)
- [x] AppState (TaskReference)
- [x] Cmd+Ctrl+Enter (create sibling + switch with full metadata)
- [x] Sibling selector panel (Cmd+Shift+S UI)
- [x] fetchSiblings() method in CloudKitManager

### ⚠️ Needs Implementation

#### 1. Cmd+Enter (Create Sibling Without Switch)
**File**: AppDelegate.swift, line ~373-375

**Replace**:
```swift
} else {
    ToastManager.shared.show("✓ Sibling created", type: .success)
}
```

**With**:
```swift
} else {
    // Update current task's sibling count without switching
    guard let current = AppState.shared.currentTask else {
        ToastManager.shared.show("✓ Sibling created", type: .success)
        return
    }

    CloudKitManager.shared.fetchCurrentTask { result in
        switch result {
        case .success(let currentPointer):
            let newSiblingCount = (currentPointer.siblingCount ?? 0) + 1

            CloudKitManager.shared.updateCurrentTaskPointer(
                taskId: currentPointer.taskId ?? current.id,
                text: currentPointer.text ?? current.text,
                parentId: currentPointer.parentId,
                rootId: currentPointer.rootId,
                parentTaskText: currentPointer.parentTaskText,
                rootTaskText: currentPointer.rootTaskText,
                showEllipsis: currentPointer.showEllipsis,
                siblingPosition: currentPointer.siblingPosition,
                siblingCount: newSiblingCount
            ) { error in
                if let error = error {
                    print("⚠️ [AppDelegate] Pointer update failed: \(error)")
                }
            }
        case .failure(let error):
            print("⚠️ [AppDelegate] Failed to fetch pointer: \(error)")
        }
    }

    ToastManager.shared.show("✓ Sibling created", type: .success)
}
```

**Operations**: 1 READ (pointer) + 2 WRITES (Task + Pointer)

---

#### 2. Cmd+Shift+S (Select Sibling)
**File**: AppDelegate.swift, line ~420 (handleSiblingSelection)

**Current**:
```swift
private func handleSiblingSelection(taskId: String, taskText: String) {
    // ??? Needs implementation
}
```

**Implement**:
```swift
private func handleSiblingSelection(taskId: String, taskText: String, siblings: [(id: String, text: String)]) {
    guard let current = AppState.shared.currentTask else { return }

    // Calculate from cached siblings array (no fetch!)
    let siblingCount = siblings.count
    let siblingPosition = siblings.firstIndex(where: { $0.id == taskId }).map { $0 + 1 }

    // Fetch pointer for hierarchy metadata
    CloudKitManager.shared.fetchCurrentTask { result in
        switch result {
        case .success(let currentPointer):
            // Update pointer: new task + same hierarchy + new position
            CloudKitManager.shared.updateCurrentTaskPointer(
                taskId: taskId,
                text: taskText,
                parentId: current.parentId,
                rootId: current.rootId,
                parentTaskText: currentPointer.parentTaskText,
                rootTaskText: currentPointer.rootTaskText,
                showEllipsis: currentPointer.showEllipsis,
                siblingPosition: siblingPosition,
                siblingCount: siblingCount
            ) { error in
                if let error = error {
                    print("⚠️ [Sibling Selection] Pointer update failed: \(error)")
                }
            }

            // Update AppState
            AppState.shared.setCurrent(id: taskId, text: taskText,
                                      parentId: current.parentId, rootId: current.rootId)

            ToastManager.shared.show("✓ Switched to sibling", type: .success)

        case .failure(let error):
            print("⚠️ [Sibling Selection] Failed to fetch pointer: \(error)")
        }
    }

    siblingSelectorPanel.hide()
}
```

**Note**: Pass `siblings` array from panel to callback to avoid refetch.

**Operations**: 1 READ (query, already done) + 1 READ (pointer) + 1 WRITE (pointer)

---

#### 3. Top-Level Sibling Prevention
**File**: AppDelegate.swift, line ~58 (handleTaskCreation)

**Add validation**:
```swift
case .sibling, .siblingAndSwitch:
    guard let current = AppState.shared.currentTask else {
        ToastManager.shared.show("⚠️ No reference task.", type: .error)
        return
    }
    guard current.parentId != nil else {
        ToastManager.shared.show("⚠️ Top-level tasks have no siblings. Use Shift+Enter to create child.", type: .error)
        return
    }
    createSiblingTask(...)
```

---

## Testing Scenarios

### Test 1: Create Sibling Without Switch
1. Create Task A with Ctrl+Enter
2. Observe iPhone: [●] (1 dot, position 1/1)
3. Press Cmd+Enter, create Task B
4. Observe iPhone: [● ○] (2 dots, position 1/2)
5. ✅ Verify: Still showing Task A, now with 2 dots

### Test 2: Create Sibling With Switch
1. Create Task A with Ctrl+Enter
2. Press Cmd+Ctrl+Enter, create Task B
3. Observe iPhone: [○ ●] (2 dots, position 2/2)
4. ✅ Verify: Switched to Task B, showing position 2

### Test 3: Select Sibling
1. Create Task A with Ctrl+Enter
2. Create 3 more siblings (Task B, C, D)
3. Observe iPhone: [○ ○ ○ ●] (4 dots, position 4/4)
4. Press Cmd+Shift+S
5. Select Task B (position 2)
6. Observe iPhone: [○ ● ○ ○] (4 dots, position 2/4)
7. ✅ Verify: Switched to Task B

### Test 4: Race Condition (Rapid Creation)
1. Create Task A with Ctrl+Enter
2. Rapidly press Cmd+Enter 3 times (within 1 second)
3. Observe iPhone: siblingCount may be off by 1-2
4. Press Cmd+Shift+S (open selector)
5. Cancel (Escape)
6. ✅ Verify: Count corrects itself on next sibling operation

### Test 5: Top-Level Sibling Prevention
1. Create Task A with Ctrl+Enter (top-level)
2. Press Cmd+Enter (try to create sibling)
3. ✅ Verify: Error toast shown, no task created

---

**End of Document**
