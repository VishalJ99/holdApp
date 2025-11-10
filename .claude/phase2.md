# Phase 2: Task Completion/Dismissal & Queue System

## Implementation Plan

### **Phase 1: CloudKit Schema & Pointer Enhancement**
**Files: CloudKitManager.swift**

1. Add `currentTaskId` field to CurrentTaskPointer record type
2. Update `updateCurrentTaskPointer()` to store both task ID and text
3. Update `fetchCurrentTask()` to return both ID and text (not just text)

---

### **Phase 2: CloudKit Operations (6 new methods)**
**Files: CloudKitManager.swift**

1. `fetchAllIncompleteTasks()` - Query tasks where `isCompleted == false`
2. `fetchTaskById(id:)` - Fetch specific task by record ID
3. `fetchChildTasks(parentId:)` - Fetch tasks with matching `parent_id`
4. `markTaskCompleted(id:)` - Set `isCompleted = true`, `completedAt = Date()`
5. `deleteTask(id:)` - Delete task record (for dismiss action)
6. `updateTask(id:fields:)` - Generic method to update existing task records

---

### **Phase 3: Task Queue Manager (NEW FILE)**
**Files: TaskQueueManager.swift (create new)**

1. Create singleton class that manages in-memory task queue
2. Fetch and cache all incomplete tasks on init
3. Implement **full 5-step next task selection algorithm**:
   - **Step 1:** Next sibling (same `parent_id`, closest `timestamp` AFTER current)
   - **Step 2:** Return to parent (fetch parent by ID)
   - **Step 3:** Previous sibling (same `parent_id`, closest `timestamp` BEFORE current)
   - **Step 4:** Oldest waiting task (earliest `timestamp` where `isCompleted == false`)
   - **Step 5:** Empty state (`currentTaskId = nil`)
4. Add public methods:
   - `advanceToNextTask(from: taskId)` - Run algorithm and return next task
   - `refreshQueue()` - Re-fetch all incomplete tasks from CloudKit
   - `removeTaskFromQueue(id:)` - Update cache when task completed/dismissed

---

### **Phase 4: Global Action Hotkeys**
**Files: HotkeyManager.swift, AppDelegate.swift**

1. **Register hotkeys** in HotkeyManager:
   - Cmd+Shift+Enter (keyCode: 36 = Return)
   - Cmd+Shift+Backspace (keyCode: 51 = Delete)
2. **Add callbacks** in AppDelegate:
   - `handleCompleteCurrentTask()`
   - `handleDismissCurrentTask()`
3. **Implement context-aware blocking** (Spotlight only for MVP):
   - Check `spotlightPanel.isVisible`
   - If open → Show error toast: "⚠️ Close Spotlight to complete current task"
   - If closed → Execute action
4. **Complete task logic**:
   - Get `currentTask.id` from AppState
   - Call `CloudKitManager.markTaskCompleted(id:)`
   - Call `TaskQueueManager.advanceToNextTask(from: id)`
   - Update `AppState.currentTask` and CloudKit pointer
   - Show toast: "✓ Completed: [Task Name]\nCurrent: [Next Task]"
5. **Dismiss task logic**:
   - Get `currentTask.id` from AppState
   - Call `CloudKitManager.deleteTask(id:)` (permanent deletion)
   - Call `TaskQueueManager.advanceToNextTask(from: id)`
   - Update `AppState.currentTask` and CloudKit pointer
   - Show toast: "✓ Dismissed: [Task Name]\nCurrent: [Next Task]"
6. **Empty state handling**:
   - If `advanceToNextTask()` returns `nil`
   - Clear `AppState.currentTask`
   - Clear CloudKit pointer (or set to empty)
   - Show toast: "✓ All tasks completed"

---

### **Phase 5: Toast Enhancements**
**Files: ToastManager.swift**

1. Support multi-line messages (task name + next task name)
2. Update timing: 1.2s total (200ms fade in, 800ms hold, 200ms fade out)
3. Ensure error toasts remain 2s

---

### **Phase 6: Integration & Testing**
**Files: AppState.swift, AppDelegate.swift**

1. Update AppState to reference TaskQueueManager
2. Refresh queue after every task creation (saveTask callback)
3. Test edge cases:
   - Complete when no current task → show error toast
   - Complete last task → verify empty state
   - Dismiss vs complete → verify delete vs update
4. Test algorithm scenarios:
   - Task with siblings → advances to next sibling
   - Task without siblings → returns to parent
   - Last child → falls back to oldest waiting

---

## Key Design Decisions

- ✅ **Context Blocking**: Block only if Spotlight open (Editor check deferred until Editor exists)
- ✅ **Dismissed Tasks**: Permanently deleted from CloudKit (no isDismissed field)
- ✅ **CurrentTaskPointer**: Stores both task ID and text for better data integrity
- ✅ **Next Task Algorithm**: Full 5-step implementation with sibling = closest creation time

---

## Estimated Scope

- **~300-400 lines** across 6 files (2 new, 4 modified)
- **Most complex component**: TaskQueueManager next task selection algorithm (~100 lines)
- **Easiest component**: Hotkey registration (~30 lines)

---

## Files to Modify

1. **CloudKitManager.swift** - Add 6 new methods + enhance pointer
2. **TaskQueueManager.swift** - NEW FILE - Queue management and algorithm
3. **HotkeyManager.swift** - Register 2 new hotkeys
4. **AppDelegate.swift** - Add complete/dismiss handlers
5. **ToastManager.swift** - Support multi-line messages and updated timing
6. **AppState.swift** - Reference TaskQueueManager

---

## Reference Documentation

- State Machine #4 (Global Actions): `.claude/Hold State Diagrams.md` lines 304-388
- State Machine #5 (Task Queue): `.claude/Hold State Diagrams.md` lines 392-459
