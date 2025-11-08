# Hold - Editor Filter Mode Implementation Spec

## Core Principle: "Filter Bar Captures Typing By Default"

The filter bar is "sticky" - it always captures keyboard input unless you explicitly navigate away from it.

**Key UX Decision:** The filter bar is **always visible** (even when empty) for discoverability. Users immediately see that filtering is possible without needing to discover a hidden keyboard shortcut.

---

## Quick Visual Overview

```
State 1: Tree View (No Active Filter)
┌─────────────────────────────┐
│ Filter:                     │ ← Empty, unfocused, dimmed
└─────────────────────────────┘
  Task A
  ├─ Subtask 1
  └─ Subtask 2
  Task B

Type any character → State 2


State 2: Filter Active, Filter Bar Focused
┌─────────────────────────────┐
│ Filter: debug|              │ ← Cursor blinking, accent color
└─────────────────────────────┘
  Debug environment setup
  Debug React component
  Create debug logs

Tab/Arrows/Enter → State 3


State 3: Filter Active, Task Selected
┌─────────────────────────────┐
│ Filter: debug               │ ← No cursor, dimmed
└─────────────────────────────┘
  Debug environment setup
▶ Debug React component        ← Selected task
  Create debug logs

Type any character → State 2 (sticky filter!)
```

---

## State Machine: Editor Focus & Filter

### State 1: Tree View (No Filter Active)

**Initial state when Editor opens**

**UI:**
- Empty filter bar visible at top: `Filter:` (unfocused, placeholder visible)
- Full task tree visible below
- No task selection

**Behavior:**
- Type any character → **Transition to State 2**, character becomes first filter character
- Tab/Arrows → Navigate tasks (stay in State 1)
- Space (on selected task) → Set as current
- Delete/Backspace (on selected task) → Dismiss task
- Cmd+P → Enter parent selection mode
- Esc → Close editor

**Key:** Any typing immediately creates filter and transitions to filtered view

---

### State 2: Filter Mode - Filter Bar Focused

**Filter bar is visible and capturing input**

**UI:**
- Filter bar visible at top with text: `Filter: search text|` (cursor blinking)
- Task list below shows only matching tasks (flat list, no hierarchy)
- Filter bar has visible focus indicator (highlight, border, etc.)

**Behavior:**
- **Type any character → Adds to filter** (stay in State 2)
- **Space → Adds space to filter** (stay in State 2)
- **Backspace → Edits filter text** (stay in State 2)
  - If filter becomes empty → **Transition to State 1** (tree view returns, filter bar disappears)
- **Tab → Move focus to first filtered task** → **Transition to State 3**
- **Shift+Tab → Move focus to last filtered task** → **Transition to State 3**
- **Arrow Down → Move focus to first filtered task** → **Transition to State 3**
- **Arrow Up → Move focus to last filtered task** → **Transition to State 3**
- **Mouse Click on task → Select that task** → **Transition to State 3**
- **Enter → Select first filtered task** → **Transition to State 3**
- **Esc → Clear filter** → **Transition to State 1**
- **Cmd+P → Clear filter first**, then enter parent selection mode (from State 1)

**Key:** Filter bar is "greedy" - captures all typing until you explicitly navigate away

---

### State 3: Filter Mode - Task Selected (Filtered Results)

**A task in the filtered list is selected, but filter bar still visible**

**UI:**
- Filter bar visible at top with filter text: `Filter: search text` (no cursor)
- Task list shows filtered results (flat list)
- One task is highlighted/selected (different visual style)
- Filter bar has NO focus indicator (dimmed/secondary appearance)

**Behavior:**
- **Type any character → Return focus to filter bar** → **Transition to State 2**, character added to filter
  - Example: Filter shows "react", user navigates to a task, types "i" → Filter becomes "reacti", focus returns to filter bar
- **Space → Set selected task as current**
  - Shows confirmation toast
  - iPhone updates
  - Stays in State 3 (filter and task list unchanged)
- **Delete/Backspace → Dismiss selected task**
  - Task removed from list
  - Selection moves to next task in filtered list
  - Stays in State 3 (or State 2 if no tasks remain?)
- **Tab → Move to next filtered task** (stay in State 3)
- **Shift+Tab → Move to previous filtered task** (stay in State 3)
- **Arrow Up/Down → Navigate filtered tasks** (stay in State 3)
- **Mouse Click on different task → Select that task** (stay in State 3)
- **Mouse Click on filter bar → Return focus to filter bar** → **Transition to State 2**
- **Cmd+P → Change parent of selected task** (auto-clears filter first)
  - **Transition to State 1** (parent selection mode from tree view)
- **Esc → Clear filter** → **Transition to State 1**

**Key:** Even with task selected, ANY typing returns to filter bar (this is the "sticky filter" behavior)

---

## Implementation Details

### Visual Design

**Filter Bar Appearance:**

**State 2 (Filter Focused):**
```
┌─────────────────────────────────────┐
│ Filter: react compon|               │ ← Cursor visible, bright/accent color
└─────────────────────────────────────┘
  React Component A
  React Component B
  Create React Forms
```

**State 3 (Task Selected):**
```
┌─────────────────────────────────────┐
│ Filter: react compon                │ ← No cursor, dimmed/secondary color
└─────────────────────────────────────┘
  React Component A
▶ React Component B                     ← Selected/highlighted
  Create React Forms
```

**State 1 (No Filter):**
```
┌─────────────────────────────────────┐
│ Filter:                             │ ← Empty, unfocused, placeholder visible
└─────────────────────────────────────┘

▶ Create embeddings script
  ├─ Debug environment setup
  └─ Write tests
  Update documentation
```

### Focus Management Rules

1. **Filter bar is always visible** (even when empty in State 1)
2. **Filter bar gains focus on first keystroke** in State 1
3. **Filter bar remains visible and focused** as long as there's filter text
4. **Filter bar returns to unfocused/empty state** when:
   - Backspace to empty (State 2 → State 1)
   - Esc pressed (State 2 or 3 → State 1)
   - Cmd+P pressed (any state → parent selection clears filter)
5. **Focus indicator clearly shows** whether filter bar or task is active
6. **Placeholder text "Filter:"** visible when empty and unfocused (State 1)

### Keyboard Navigation Flow

**Typical user flow:**
1. Open Editor (State 1)
2. Type "debug" (State 1 → State 2, filter bar appears)
3. See 3 matching tasks in flat list
4. Press Tab (State 2 → State 3, first task selected)
5. Press Space to set as current
6. Press Esc to clear filter (State 3 → State 1)

**Filter refinement flow:**
1. Type "react" (State 1 → State 2, 10 results)
2. Press Tab (State 2 → State 3, navigate results)
3. See too many results, type "i" (State 3 → State 2, filter becomes "reacti", 3 results)
4. Press Tab again (State 2 → State 3, select from refined results)

**Quick action flow:**
1. Type "test" (State 1 → State 2)
2. Press Tab to first match (State 2 → State 3)
3. Press Space to set current immediately
4. Still in filtered view, can continue working or press Esc

---

## Edge Cases & Clarifications

### Q: When clearing filter (State 2 or 3 → State 1), does task selection persist?
**A:** **No. State 1 always has no task selection.** When filter is cleared (via Backspace to empty or Esc), any task selection is also cleared. User sees clean tree view with empty filter bar.

### Q: In State 3, user presses Backspace - dismiss task or edit filter?
**A:** **Dismiss task.** Focus is on task, not filter bar. This is standard UI pattern (focus = context for actions).

### Q: In State 3, if user dismisses the last filtered task, what happens?
**A:** **Transition to State 2** (filter bar focused, empty results).
- Filter text remains (e.g., "test")
- Task list shows "No matching tasks"
- User can refine filter or press Esc to return to tree view
- This allows them to immediately adjust their search

### Q: Can user click into filter bar to edit existing text?
**A:** **Yes.** Mouse click on filter bar (from any state) → State 2, cursor positioned where clicked.

### Q: What about Cmd+F to search (standard macOS)?
**A:** 
- **Option 1:** Not needed - just start typing
- **Option 2:** Cmd+F focuses filter bar (creates it if needed)
- **Recommendation:** Option 1 (keep it simple, typing is enough)

### Q: Should Enter in State 2 (filter focused) do anything?
**A:** **Yes. Enter selects first filtered result** and transitions to State 3.
- This is faster than Tab → Space
- Common pattern: "I'm done typing, give me the top result"
- If no results, do nothing (or show subtle "No matches" feedback)

### Q: What about double-click on task?
**A:** **Double-click = Set as current** (same as Space). Standard UI shortcut.

---

## Comparison to Standard Apps

### VS Code Search Results (similar pattern):
- Search field at top captures typing
- Results below
- Tab/Click to navigate results
- Typing again returns to search field ✓ (Hold matches this)

### Finder Search (different pattern):
- Search field captures initial typing
- Results below
- Typing does incremental selection in results (not filter refinement)
- Hold does NOT match this (filter is stickier)

### Spotlight (different pattern):
- Search field captures all typing
- Cannot navigate to results with keyboard (arrow keys filter categories)
- Hold is more advanced (allows navigation)

**Hold's pattern is closest to VS Code**, which is appropriate for a developer-focused productivity tool.

---

## Implementation Checklist

### Phase 1: Basic Filter (MVP)
- [ ] State 1 → State 2 transition (typing creates filter)
- [ ] Filter text updates as user types
- [ ] Filtered results displayed (flat list)
- [ ] Backspace to empty returns to tree view
- [ ] Esc clears filter

### Phase 2: Navigation
- [ ] Tab/Arrows move from filter to tasks (State 2 → State 3)
- [ ] Tab/Arrows navigate between tasks (within State 3)
- [ ] Mouse click on task selects it (State 2 or 3)
- [ ] Space on selected task sets as current
- [ ] Delete on selected task dismisses it

### Phase 3: "Sticky Filter" Behavior
- [ ] Typing in State 3 returns to State 2 (focus to filter)
- [ ] Character is added to filter immediately
- [ ] Visual feedback for focus state (filter vs task)

### Phase 4: Polish
- [ ] Enter in State 2 selects first result (optional but useful)
- [ ] Double-click sets current (convenience)
- [ ] Smooth transitions between states
- [ ] Clear visual distinction between focused/unfocused filter

---

## Summary

**The key innovation:** Filter bar is "sticky" and always captures typing unless you explicitly navigate away. Even when a task is selected, typing returns focus to the filter bar.

**Why this works:**
1. Speed: User can rapidly refine filter without clicking back
2. Consistency: Typing always means "I'm filtering"
3. Explicit navigation: Tab/arrows/click = "I'm done filtering, let me select something"
4. No mode confusion: Focus indicator always shows what's active

This is the implementation to build. All states, transitions, and edge cases are now defined.

