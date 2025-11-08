# Hold - Keyboard Shortcuts Reference (Final)

**Version:** 1.0 Final  
**Last Updated:** November 8, 2025

All keyboard shortcuts for Hold, with your current defaults. Customizable in Settings → Keyboard Shortcuts.

---

## Quick Reference Card

### Learn These First (Essential 7)
| Shortcut | Action | Context |
|----------|--------|---------|
| `Cmd+Shift+Space` | Open Spotlight | Global |
| `Cmd+Shift+\` | Open Editor | Global |
| `Enter` | Create task | Spotlight |
| `Shift+Enter` | Create child & switch | Spotlight |
| `Space` | Set as current | Editor |
| `Cmd+Shift+Enter` | Complete current | Global |
| `Esc` | Close/Cancel | Anywhere |

---

## 1. Global Shortcuts

Work **anywhere in the app**, even when other windows/interfaces are open.

| Shortcut | Action | Description | Notes |
|----------|--------|-------------|-------|
| `Cmd+Shift+Space` | **Open Spotlight** | Opens task capture interface | Brings to front if already open |
| `Cmd+Shift+\` | **Open Editor** | Opens task management tree view | Brings to front if already open |
| `Cmd+Shift+Enter` | **Complete Current Task** | Marks current task done, advances to next | Blocked if Editor/Spotlight open (close first) |
| `Cmd+Shift+Backspace` | **Dismiss Current Task** | Removes current task without completing | Blocked if Editor/Spotlight open (close first) |
| `Cmd+Shift+Z` | **Undo Last Action** | Reverses most recent operation | v2 feature - not in MVP |
| `Cmd+?` | **Show Shortcuts Cheat Sheet** | Displays keyboard reference overlay | Customizable in settings |

**Design Philosophy:**
- All global shortcuts use `Cmd+Shift+` prefix
- Muscle memory: Space (capture), \ (manage), Enter (complete)
- Global actions blocked when interfaces open to prevent accidents

---

## 2. Spotlight Context

Active when Spotlight capture interface is open (`Cmd+Shift+Space`).

### 2.1 Basic Task Creation

| Shortcut | Action | Description | Switches Focus? |
|----------|--------|-------------|-----------------|
| `Enter` | **Create Top-Level Task** | Creates task at root level, adds to queue | No |
| `Option+Enter` | **Create & Switch** | Creates top-level task and makes it current | Yes ✓ |

### 2.2 Hierarchical Task Creation

| Shortcut | Action | Description | Switches Focus? |
|----------|--------|-------------|-----------------|
| `Shift+Enter` | **Create Child & Switch** | Creates child under current task, switches to it | Yes ✓ |
| `Cmd+Enter` | **Create Sibling** | Creates sibling of current task at same level | No |
| `Cmd+Option+Enter` | **Create Sibling & Switch** | Creates sibling and makes it current | Yes ✓ |

**Sibling Logic:**
- If current is top-level → sibling is also top-level
- If current is nested → sibling is at same nesting level (shares parent)

**Error Handling:**
- `Shift+Enter` with no current task → "⚠️ No parent task. Create a top-level task first."
- `Cmd+Enter` with no current task → "⚠️ No reference task. Create a task first."

### 2.3 Advanced Creation

| Shortcut | Action | Description |
|----------|--------|-------------|
| `Cmd+P` | **Select Parent** | Opens parent selector for two-step creation |

**Two-step parent selection flow:**
1. Type task name in Spotlight
2. Press `Cmd+P` → Opens parent selector
3. Navigate and select parent with `Enter` or click
4. Returns to Spotlight showing "Task → Parent"
5. Final submission:
   - `Enter` → Create under parent, don't switch
   - `Option+Enter` → Create under parent, switch to it

### 2.4 Editing & Navigation

| Shortcut | Action | Description | Notes |
|----------|--------|-------------|-------|
| `Up Arrow` | **Load Current Task** | Fills input with current task for editing | Idempotent (does nothing if already loaded) |
| `Down Arrow` | **Clear to Blank** | Clears input text | Idempotent (does nothing if already blank) |
| `Tab` | *No action* | Reserved / does nothing | Task navigation happens in Editor only |
| `Esc` | **Close Spotlight** | Closes without action | Discards any typed text |

### 2.5 Text Editing

Standard macOS text editing applies:
- `Cmd+A` = Select all
- `Cmd+C/V` = Copy/paste
- Arrow keys = Move cursor
- `Backspace` = Delete character

---

## 3. Editor Context

Active when Editor is open (`Cmd+Shift+\`). Three modes: Tree View, Filter Mode (typing), Navigation Mode (task selected).

### 3.1 Filter Bar (Always Visible)

| Shortcut | Action | State Transition | Description |
|----------|--------|------------------|-------------|
| Type any character | **Start Filtering** | State 1 → State 2 | Creates filter, shows flat list of matches |
| Continue typing | **Refine Filter** | Stay in State 2 | Narrows results |
| `Backspace` | **Edit Filter** | Stay in State 2 | Standard text editing when filter focused |
| Backspace to empty | **Clear Filter** | State 2 → State 1 | Returns to tree view |
| `Enter` | **Select First Result** | State 2 → State 3 | Selects top filtered task |
| `Esc` | **Clear Filter** | State 2/3 → State 1 | Returns to tree view |

**State 1:** Tree view, empty filter bar visible (unfocused)  
**State 2:** Filter bar focused, cursor blinking, filtered results below  
**State 3:** Task selected, filter visible but unfocused

### 3.2 Task Navigation

| Shortcut | Action | Context | Description |
|----------|--------|---------|-------------|
| `Tab` | **Navigate Tasks** | Any state | Move through tasks/results (hold Shift to reverse direction) |
| `↑` / `↓` | **Navigate Tasks** | Any state | Up/down through visible tasks |
| `Enter` | **Select First Result** | Filter focused | Quick selection from filtered list |

**Sticky Filter Behavior:**
- When task is selected (State 3), typing ANY character returns focus to filter bar (State 3 → State 2)
- This enables rapid filter refinement without clicking back

### 3.3 Task Actions

| Shortcut | Action | Context | Description |
|----------|--------|---------|-------------|
| `Space` | **Set as Current** | Task selected | Makes selected task the current focus |
| `Backspace` | **Dismiss Task** | Task selected | Removes task from list |
| `Cmd+P` | **Change Parent** | Task selected | Opens parent selector to reparent |
| Double-click | **Set as Current** | Mouse | Same as Space (convenience) |
| Drag & Drop | **Reparent Task** | Mouse | Drag task onto new parent in tree |

**Context Sensitivity:**
- `Backspace` in State 2 (filter focused) = Edit filter text
- `Backspace` in State 3 (task selected) = Dismiss task
- `Space` in State 2 (filter focused) = Add space to filter
- `Space` in State 3 (task selected) = Set as current

### 3.4 Advanced Operations

| Shortcut | Action | Description |
|----------|--------|-------------|
| `Cmd+P` | **Change Parent** | Clears filter if active, shows full tree for parent selection |
| `Esc` | **Close Editor** | Returns to desktop, persists filter text for next open |

**Filter Persistence:**
- Filter text remembered when Editor closes
- Next time Editor opens, previous filter is active
- Allows continuation of previous work session

---

## 4. Parent Selector Context

Opened from Spotlight (`Cmd+P`) or Editor (`Cmd+P`). Displays full task hierarchy for parent selection.

### 4.1 Navigation

| Shortcut | Action | Description |
|----------|--------|-------------|
| `↑` / `↓` | **Navigate Tasks** | Move through tree (up/down) |
| `Tab` | **Navigate Tasks** | Move through tree (hold Shift to reverse direction) |
| Type | **Filter Tree** | Shows only matching tasks |

### 4.2 Selection

| Shortcut | Action | Description |
|----------|--------|-------------|
| `Enter` | **Select Parent** | Confirms selection, returns to calling context |
| Click | **Select Parent** | Immediate selection (skips Enter) |
| `Esc` | **Cancel** | Returns without selecting |

**Context-Aware Return:**
- Called from Spotlight → Returns to Spotlight with parent selected
- Called from Editor → Updates task's parent immediately in tree

**Implementation Note:**
- From Editor: Reuses Editor's tree view (switches to parent selection mode)
- From Spotlight: Opens as overlay picker

---

## 5. Confirmation Toasts

Every action shows brief confirmation feedback. No keyboard interaction needed.

**Format:** "✓ [Action description]"  
**Duration:** Fade in 200ms, hold 800ms, fade out 200ms  
**Examples:**
- "✓ Task created"
- "✓ Task created (current)" ← iPhone updates
- "✓ Child created under [Parent] (current)"
- "✓ Task updated"
- "✓ Task completed"
- "✓ Task dismissed"

**Error Messages:**
- "⚠️ No parent task. Create a top-level task first."
- "⚠️ No reference task. Create a task first."
- "⚠️ Close Editor to complete current task"
- "⚠️ Close Spotlight to dismiss current task"
- "⚠️ Cannot delete task with children"

---

## 6. iPhone Widget

**No keyboard shortcuts.** iPhone display is **passive only** - no user interaction required.

**Behavior:**
- Updates automatically via CloudKit when Mac changes current task
- Displays in StandBy Mode (horizontal charging)
- Shows: Task name + time since set
- 2-5 second sync lag is acceptable

---

## Keyboard Shortcut Principles

### Design Philosophy
1. **Consistent prefixes** - Global shortcuts use `Cmd+Shift+`
2. **Modifier meanings** - Option = "switch to it", Shift = "child", Cmd = "sibling"
3. **Muscle memory** - Common actions have memorable shortcuts
4. **Context-sensitive** - Keys behave differently based on selection/focus
5. **Standard macOS** - Follows Apple HIG where possible

### Modifier Combinations in Spotlight
| Modifier | Meaning | Example |
|----------|---------|---------|
| None | Create, don't switch | `Enter` |
| `Option` | Create & switch to it | `Option+Enter` |
| `Shift` | Create child (always switches) | `Shift+Enter` |
| `Cmd` | Create sibling | `Cmd+Enter` |
| `Cmd+Option` | Create sibling & switch | `Cmd+Option+Enter` |

### Discoverable Through Use
- Filter bar always visible in Editor (shows filtering is possible)
- Confirmation messages teach relationships ("Child created under [Parent]")
- Error messages guide correct usage
- Help overlay (`Cmd+?`) shows all shortcuts in context

---

## Customization

All shortcuts can be customized in **Settings → Keyboard Shortcuts**.

**Default mappings shown here.** Customize to match your workflow or avoid conflicts with other apps.

**Conflicts to be aware of:**
- `Cmd+Shift+Space` may conflict with some emoji pickers
- `Cmd+P` in parent selector may conflict with system print dialog
- `Cmd+?` may conflict with some apps' help menus

**Recommendation:** Start with defaults, customize only if conflicts arise.

---

## Task Navigation Hierarchy (Next Task Selection)

When current task is completed or dismissed, Hold automatically advances to the next task using this priority:

1. **Next sibling** (chronological)
2. If no sibling → **Return to parent**
3. If no parent → **Previous sibling**
4. If none → **Next in queue** (oldest waiting task)
5. If queue empty → **Empty state** (no current task)

This algorithm maintains context while keeping you moving forward through your work.

---

## Edge Cases & Limitations

### MVP Limitations
- **No undo** (coming in v2)
- **No right-click menus** (keyboard-first for MVP)
- **No task editing** (can delete & recreate)
- **Empty task names blocked** (must have text)
- **Can't delete parent with children** (delete children first)
- **Pagination at 100 tasks** (performance consideration)

### Deferred Multi-Device
- Single device only in MVP (Mac + iPhone sync)
- No conflict resolution needed
- iPhone is passive display only

---

## Troubleshooting

**Shortcut not working?**
1. Check if interface is open (global shortcuts blocked in Editor/Spotlight)
2. Check for conflicts with other apps
3. Verify customization in Settings → Keyboard Shortcuts

**Filter not responding?**
1. Check if filter bar is focused (cursor should be blinking)
2. If task is selected, type to return focus to filter
3. Press Esc to clear filter and start fresh

**Can't create child/sibling?**
1. Ensure a current task is set (error message will guide you)
2. Use Enter or Option+Enter to create first task
3. Then use Shift+Enter or Cmd+Enter for hierarchy

---

## Summary: The Essential 12

Master these 12 shortcuts for 95% of daily use:

**Capture (5):**
1. `Cmd+Shift+Space` - Open Spotlight
2. `Enter` - Create task
3. `Option+Enter` - Create & switch
4. `Shift+Enter` - Create child & switch
5. `Cmd+P` - Select parent

**Manage (4):**
6. `Cmd+Shift+\` - Open Editor
7. Type - Filter tasks
8. `Tab` - Navigate results (hold Shift to reverse)
9. `Space` - Set as current

**Complete (2):**
10. `Cmd+Shift+Enter` - Complete task
11. `Cmd+Shift+Backspace` - Dismiss task

**Universal (1):**
12. `Esc` - Close/Cancel

---

This is your complete keyboard reference. Print it, memorize it, customize it. Let your muscle memory do the rest.

**Hold holds your tasks. Your shortcuts hold your speed.**
