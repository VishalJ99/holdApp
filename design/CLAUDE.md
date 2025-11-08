# Hold - Design Documentation Index

**Purpose:** Quick reference guide to all design documents in this directory.

**For Agents:** Read this first to understand which documents contain what information before implementing features.

---

## Document Overview

### 1. Vision.md
**What it contains:** Product vision, philosophy, and positioning

**Key sections:**
- **One-liner & Elevator Pitch** - How to describe Hold
- **Core Problems** (4 problems) - What Hold solves and why it exists
- **The Solution** - iPhone display + Mac staging area architecture
- **Core Philosophy** - "Hold is RAM, not your hard drive"
- **User Experience** - Real-world workflows and usage patterns
- **Integration** - How Hold fits with existing task managers
- **Target User** - Who this is for (ADHD, knowledge workers)
- **Positioning Statement** - Marketing/product positioning
- **Brand Essence** - "Mental Space" - the weight metaphor

**When to reference:**
- Understanding product strategy and design decisions
- Writing marketing copy or user-facing text
- Making product direction decisions
- Understanding the "why" behind features

---

### 2. Hold State Diagrams.md
**What it contains:** Complete state machine specifications for all 6 core components

**Key sections:**
- **Implementation Priority Order** - Build sequence (Spotlight → Task Queue → Global Actions → Editor → Parent Selector → iPhone)
- **6 State Machines:**
  1. **Spotlight** - Task capture interface with all Enter variations
  2. **Parent Selector** - Tree picker for parent selection
  3. **Editor** - 3-mode interface (Tree/Filter/Navigation)
  4. **Global Actions** - Complete/Dismiss with context-aware blocking
  5. **Task Queue** - Current task tracking and advancement
  6. **iPhone Display** - Passive sync via CloudKit
- **State Transition Specifications** - Task creation modifiers table
- **Confirmation Messages** - All success/error toast messages
- **Next Task Selection Algorithm** - Single source of truth for task advancement
- **Implementation Testing Checklist** - Per-state-machine test scenarios
- **Edge Cases** - What's handled vs. deferred to v2

**When to reference:**
- Implementing any core interface logic
- Understanding state transitions and user flows
- Writing confirmation/error messages
- Implementing task advancement logic
- Creating test plans

**CRITICAL:** This is the authoritative spec for behavior. Build exactly as documented.

---

### 3. Hold Editor Filter Spec.md
**What it contains:** Detailed implementation spec for Editor's 3-state filter system

**Key sections:**
- **Core Principle** - "Filter bar captures typing by default" (sticky filter)
- **Visual Overview** - Mockups of States 1, 2, 3
- **State Machine Detail:**
  - **State 1:** Tree View (empty filter bar visible, unfocused)
  - **State 2:** Filter Mode - Filter Focused (cursor blinking, filtered results)
  - **State 3:** Navigation Mode - Task Selected (filter visible but dimmed)
- **Implementation Details** - Visual design, focus management rules
- **Keyboard Navigation Flow** - Typical user flows
- **Edge Cases & Clarifications** - Q&A format for ambiguous behaviors
- **Comparison to Standard Apps** - VS Code (similar), Finder/Spotlight (different)
- **Implementation Checklist** - 4-phase build plan

**When to reference:**
- Implementing the Editor interface
- Understanding filter bar behavior and focus management
- Clarifying "sticky filter" behavior (typing returns to filter)
- Understanding context-sensitive Backspace (edits filter OR dismisses task)

**Relationship to State Diagrams.md:**
- This is a deep-dive expansion of State Machine #3 (Editor)
- Provides visual mockups and additional UI detail
- Both docs must be consulted for Editor implementation

---

### 4. Hold Keyboard Short Cuts UI.md
**What it contains:** Settings UI specification for viewing and customizing keyboard shortcuts

**Key sections:**
- **Settings Window Layout** - Visual mockup of Settings → Keyboard Shortcuts
- **Data Structure** - JSON format for storing shortcuts, categories, conflicts
- **Shortcut Categories** - global, spotlight, editor, parent_selector with all shortcuts defined
- **UI Components:**
  - Shortcut Row (default/hover/editing/conflict/locked states)
  - Editing Mode (modal for changing shortcuts)
  - Categories (collapsible sections)
- **Special UI Elements:**
  - Locked Shortcuts (with explanations why)
  - Conflict Warnings (3 severity levels)
  - Context Notes (behavioral explanations)
- **Action Buttons** - Restore Defaults, Show Cheat Sheet, Save/Cancel
- **Search & Filter** - Live search within shortcuts list
- **Cheat Sheet Overlay** - Cmd+? floating reference (also in ui.md)
- **Implementation Notes** - Conflict detection algorithm, storage format (.plist)
- **Accessibility** - Keyboard nav, screen reader, high contrast
- **User Flows** - 3 example flows (first-time, conflict resolution, power user)
- **Visual Design Specs** - Colors, typography, spacing

**When to reference:**
- Implementing Settings window
- Building keyboard shortcut customization system
- Designing the Cmd+? cheat sheet overlay
- Understanding which shortcuts are customizable vs. locked
- Implementing conflict detection

**Note:** The actual keyboard shortcuts list is in "Keyboard Shortcuts Final.md" - this doc is about the *UI for managing* those shortcuts.

---

### 5. Keyboard Shortcuts Final.md
**What it contains:** Complete keyboard shortcuts reference guide (user-facing documentation)

**Key sections:**
- **Quick Reference Card** - Essential 7 shortcuts to learn first
- **1. Global Shortcuts** - Work anywhere (Cmd+Shift+ prefix pattern)
- **2. Spotlight Context** - All task creation variations with modifiers
  - Basic Creation (Enter, Option+Enter)
  - Hierarchical Creation (Shift+Enter, Cmd+Enter, Cmd+Option+Enter)
  - Advanced Creation (Cmd+P parent selection)
  - Editing & Navigation (Up/Down arrows, Esc)
- **3. Editor Context** - 3-mode system shortcuts
  - Filter Bar (typing, backspace, enter, esc)
  - Task Navigation (Tab, arrows)
  - Task Actions (Space, Backspace, Cmd+P, drag & drop)
- **4. Parent Selector Context** - Navigation and selection
- **5. Confirmation Toasts** - All success/error message formats
- **6. iPhone Widget** - No shortcuts (passive only)
- **Keyboard Shortcut Principles** - Design philosophy and modifier meanings
- **Customization** - How to customize, known conflicts
- **Task Navigation Hierarchy** - Next task selection algorithm
- **Edge Cases & Limitations** - MVP constraints
- **Troubleshooting** - Common issues and fixes
- **Summary: The Essential 12** - Master shortcuts for 95% of use

**When to reference:**
- Understanding the complete keyboard shortcut system
- Writing help documentation or onboarding
- Implementing keyboard event handlers
- Understanding modifier combination logic (Option = switch, Shift = child, Cmd = sibling)
- Creating printable reference cards

**Relationship to other docs:**
- Complements "Hold Keyboard Short Cuts UI.md" (which is about the *settings UI*)
- Implements the behavior defined in "Hold State Diagrams.md"
- This is user-facing reference; State Diagrams is implementation spec

---

## Quick Navigation Guide

### "I need to implement..."

| Task | Primary Doc | Secondary Docs |
|------|-------------|----------------|
| Spotlight interface | Hold State Diagrams.md (#1) | Keyboard Shortcuts Final.md (Section 2) |
| Editor interface | Hold State Diagrams.md (#3) + Hold Editor Filter Spec.md | Keyboard Shortcuts Final.md (Section 3) |
| Parent Selector | Hold State Diagrams.md (#2) | Keyboard Shortcuts Final.md (Section 4) |
| Global Complete/Dismiss | Hold State Diagrams.md (#4) | Keyboard Shortcuts Final.md (Section 1) |
| Task Queue logic | Hold State Diagrams.md (#5) | - |
| iPhone display | Hold State Diagrams.md (#6) | Vision.md (iPhone section) |
| Settings UI | Hold Keyboard Short Cuts UI.md | - |
| Cheat sheet overlay | Hold Keyboard Short Cuts UI.md | Keyboard Shortcuts Final.md |
| Confirmation toasts | Hold State Diagrams.md (State Transition Specifications) | Keyboard Shortcuts Final.md (Section 5) |
| Next task algorithm | Hold State Diagrams.md (State Transition Specifications) | Keyboard Shortcuts Final.md (Task Navigation Hierarchy) |

### "I need to understand..."

| Question | Document to Read |
|----------|------------------|
| What problem does Hold solve? | Vision.md (Core Problems) |
| Who is this for? | Vision.md (Target User) |
| How does Hold fit with existing task managers? | Vision.md (How Hold Fits Into Your Workflow) |
| What are the keyboard shortcuts? | Keyboard Shortcuts Final.md |
| How does the filter bar work? | Hold Editor Filter Spec.md |
| What are all the state machines? | Hold State Diagrams.md |
| How do I customize shortcuts? | Hold Keyboard Short Cuts UI.md |
| What's the next task selection logic? | Hold State Diagrams.md (State Transition Specifications) OR Keyboard Shortcuts Final.md (Task Navigation Hierarchy) |
| What modifiers mean what in Spotlight? | Keyboard Shortcuts Final.md (Modifier Combinations) OR Hold State Diagrams.md (#1) |

---

## Implementation Order

Build in this sequence (from Hold State Diagrams.md):

1. **Spotlight (State Machine #1)** - Core capture interface
   - Start here - this is the primary input method
   - Reference: Hold State Diagrams.md (#1), Keyboard Shortcuts Final.md (Section 2)

2. **Task Queue (State Machine #5)** - Current task tracking
   - Needed before anything can display tasks
   - Reference: Hold State Diagrams.md (#5)

3. **Global Actions (State Machine #4)** - Complete/dismiss with blocking
   - Essential workflow completion
   - Reference: Hold State Diagrams.md (#4), Keyboard Shortcuts Final.md (Section 1)

4. **Editor (State Machine #3)** - Management with filter
   - Most complex interface, build after basics working
   - Reference: Hold State Diagrams.md (#3), Hold Editor Filter Spec.md, Keyboard Shortcuts Final.md (Section 3)

5. **Parent Selector (State Machine #2)** - Advanced hierarchy
   - Optional for MVP, enables power users
   - Reference: Hold State Diagrams.md (#2), Keyboard Shortcuts Final.md (Section 4)

6. **iPhone Display (State Machine #6)** - Passive sync
   - Last because Mac functionality comes first
   - Reference: Hold State Diagrams.md (#6), existing CloudKit implementation

**Note:** Settings UI and Cheat Sheet can be built anytime after shortcuts are implemented.

---

## Document Relationships

```
Vision.md
  └─ Defines "why" and "who"
      ↓
Hold State Diagrams.md
  └─ Defines "what" (all behaviors)
      ↓
Hold Editor Filter Spec.md
  └─ Deep-dive on Editor state machine (#3)
      ↓
Keyboard Shortcuts Final.md
  └─ User-facing reference for all shortcuts
      ↓
Hold Keyboard Short Cuts UI.md
  └─ Settings UI for customizing those shortcuts
```

**UI Implementation Hierarchy:**
- Hold State Diagrams.md = Behavior (state transitions, logic)
- Hold Editor Filter Spec.md = Editor UI specifics (visual states, focus)
- ui.md (this will be created) = Visual design system (colors, typography, components)

---

## Key Design Decisions Captured

These are the "why" decisions that shouldn't be changed without careful consideration:

1. **Filter bar always visible** - For discoverability (Hold Editor Filter Spec.md)
2. **Global actions blocked when Editor/Spotlight open** - Prevents accidents (Hold State Diagrams.md #4)
3. **Sticky filter** - Typing returns to filter bar (Hold Editor Filter Spec.md)
4. **Context-sensitive Backspace** - Edits filter OR dismisses task (Hold Editor Filter Spec.md)
5. **Up/Down arrows idempotent** - Pressing twice does nothing (Hold State Diagrams.md #1)
6. **Option modifier = switch to task** - Consistent across all creation shortcuts (Keyboard Shortcuts Final.md)
7. **Shift+Enter always creates child** - Parent relationship (Keyboard Shortcuts Final.md)
8. **Cmd+Enter creates sibling** - Same-level relationship (Keyboard Shortcuts Final.md)
9. **Parent deletion blocked** - Can't orphan children (Hold State Diagrams.md, Edge Cases)
10. **iPhone is passive only** - No user interaction (Vision.md, Hold State Diagrams.md #6)

---

## Testing Reference

For implementation testing checklist, see:
- **Hold State Diagrams.md** - Section "Implementation Testing Checklist"
- **Hold Editor Filter Spec.md** - Section "Implementation Checklist"

---

## Future Features (v2)

Not in current design specs, deferred:
- Undo/redo (Cmd+Shift+Z mentioned but marked v2)
- Task editing (inline edit in Editor)
- Right-click menus
- Orphan handling (alternative to blocking deletion)
- Multi-device sync beyond Mac+iPhone
- Conflict resolution for simultaneous edits

Source: Hold State Diagrams.md (Edge Cases, Deferred to v2)

---

## Summary

These five design documents form the complete specification for Hold v1.0:

- **Vision.md** = Why and who
- **Hold State Diagrams.md** = Complete behavior specification (authoritative)
- **Hold Editor Filter Spec.md** = Editor implementation deep-dive
- **Keyboard Shortcuts Final.md** = User-facing reference
- **Hold Keyboard Short Cuts UI.md** = Settings UI specification

**For implementation:** Start with Hold State Diagrams.md, reference others as needed.

**For understanding product strategy:** Start with Vision.md.

**For UI/UX details:** See ui.md (comprehensive UI elements reference).
