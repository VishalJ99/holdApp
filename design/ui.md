# Hold - UI Elements Reference

**Purpose:** Comprehensive UI specification extracted from all design documents. Single source of truth for visual design implementation.

**Last Updated:** November 8, 2025
**Version:** 1.0 Final

---

## Table of Contents

1. [Core Interfaces](#core-interfaces)
2. [Secondary Interfaces](#secondary-interfaces)
3. [UI Components](#ui-components)
4. [Visual Design System](#visual-design-system)
5. [Animations & Transitions](#animations--transitions)
6. [Interaction Patterns](#interaction-patterns)
7. [Accessibility](#accessibility)

---

## Core Interfaces

### 1. Spotlight (Entry Bar)

**Purpose:** Primary task capture interface
**Trigger:** `Cmd+Shift+Space` (global hotkey)
**Platform:** macOS only

#### Visual Design

**Window Properties:**
- Floating panel, always on top
- Centered horizontally on screen
- Top third of screen vertically
- Rounded corners (macOS standard)
- Subtle shadow for depth
- Semi-transparent backdrop (dims background)

**Input Field:**
```
┌────────────────────────────────────────────────────┐
│  Type your task...                              ×  │
└────────────────────────────────────────────────────┘
```

**Dimensions:**
- Width: 600px
- Height: 60px (single line) or auto-expand for multi-line
- Border radius: 10px
- Padding: 16px horizontal, 12px vertical

**States:**

1. **Empty/Blank**
   - Placeholder text: "Type your task..." (70% opacity gray)
   - No text visible
   - Cursor blinking

2. **Typing**
   - User text visible in system font
   - Cursor position indicated
   - Character count: No limit (reasonable multi-line)

3. **Prefilled (Up Arrow Pressed)**
   - Current task text loaded
   - Entire text selected (highlight)
   - Ready to edit or replace

4. **Parent Selected (Cmd+P Flow)**
   ```
   ┌────────────────────────────────────────────────────┐
   │  Fix authentication bug → Backend Refactor      ×  │
   └────────────────────────────────────────────────────┘
   ```
   - Shows: "Task Name → Parent Name"
   - Arrow symbol: → (or similar visual separator)
   - Parent name in secondary color (dimmed)

**Confirmation/Error Toasts:**

Display below the input field, appearing temporarily:

**Success Messages:**
```
┌────────────────────────────────────────────────────┐
│  Type your task...                              ×  │
└────────────────────────────────────────────────────┘
     ✓ Task created
```

**Error Messages:**
```
┌────────────────────────────────────────────────────┐
│  Type your task...                              ×  │
└────────────────────────────────────────────────────┘
     ⚠️ No parent task. Create a top-level task first.
```

**Toast Styling:**
- Position: 8px below input field, centered
- Background: White with subtle shadow
- Padding: 8px 16px
- Border radius: 6px
- Font: SF Pro Text, 12pt
- Icon: ✓ (green) for success, ⚠️ (orange) for errors
- Animation: Fade in 200ms, hold 800ms, fade out 200ms (1s total)

#### Typography

- **Input text:** SF Pro Display, 18pt, Regular
- **Placeholder:** SF Pro Display, 18pt, Regular, 70% opacity
- **Parent name:** SF Pro Text, 16pt, Regular, 60% opacity
- **Toast messages:** SF Pro Text, 12pt, Medium

#### Colors

- **Background:** `#FFFFFF` (white) with 95% opacity
- **Text:** `#000000` (black)
- **Placeholder:** `#8E8E93` (system gray)
- **Border:** `#D1D1D6` (light gray) or `#007AFF` (blue) when active
- **Close button (×):** `#8E8E93`, hover `#FF3B30` (red)

---

### 2. Editor (Task Management)

**Purpose:** Full task management with tree view and filtering
**Trigger:** `Cmd+Shift+\` (global hotkey)
**Platform:** macOS only

#### Window Design

**Window Properties:**
- Standard macOS window (not floating)
- Resizable (minimum 400px × 600px)
- Title bar: "Hold - Editor"
- Close/minimize/maximize buttons (standard macOS)

**Layout Structure:**
```
┌──────────────────────────────────────────────────────┐
│  Hold - Editor                          [- □ ×]      │
├──────────────────────────────────────────────────────┤
│  Filter:                                             │ ← Always visible
├──────────────────────────────────────────────────────┤
│                                                      │
│  ▶ Create embeddings script                         │
│    ├─ Debug environment setup                       │
│    └─ Write tests                                   │
│  ▶ Update documentation                             │
│  ▶ Fix authentication bug                           │
│                                                      │
└──────────────────────────────────────────────────────┘
```

#### Three Visual States

**State 1: Tree View (No Filter Active)**

```
┌──────────────────────────────────────────────────────┐
│  Filter:                                             │ ← Empty, unfocused, dimmed
├──────────────────────────────────────────────────────┤
│                                                      │
│  ▶ Create embeddings script                         │
│    ├─ Debug environment setup                       │
│    └─ Write tests                                   │
│  ▶ Update documentation                             │
│  ▶ Fix authentication bug                           │
│                                                      │
└──────────────────────────────────────────────────────┘
```

**Filter Bar Styling (State 1):**
- Background: `#F5F5F5` (off-white, dimmed)
- Border: None or subtle `#E5E5E5`
- Placeholder: "Filter:" in `#8E8E93`
- No cursor visible

**State 2: Filter Mode - Filter Focused**

```
┌──────────────────────────────────────────────────────┐
│  Filter: debug|                                      │ ← Cursor blinking, accent
├──────────────────────────────────────────────────────┤
│                                                      │
│  Debug environment setup                            │
│  Debug React component                              │
│  Create debug logs                                  │
│                                                      │
└──────────────────────────────────────────────────────┘
```

**Filter Bar Styling (State 2):**
- Background: `#FFFFFF` (white, active)
- Border: `#007AFF` (blue accent, 2px)
- Text: User's filter text with cursor
- Font: SF Pro Text, 14pt

**Filtered Results:**
- Flat list (no hierarchy shown)
- Matching tasks only
- Subtle highlight on matches (if implementing substring highlighting)

**State 3: Navigation Mode - Task Selected**

```
┌──────────────────────────────────────────────────────┐
│  Filter: debug                                       │ ← No cursor, dimmed
├──────────────────────────────────────────────────────┤
│                                                      │
│  Debug environment setup                            │
│▶ Debug React component                              │ ← Selected
│  Create debug logs                                  │
│                                                      │
└──────────────────────────────────────────────────────┘
```

**Filter Bar Styling (State 3):**
- Background: `#F5F5F5` (dimmed, same as State 1)
- Border: `#E5E5E5` or none
- Text: Filter text visible but no cursor
- Font: SF Pro Text, 14pt, 70% opacity

**Selected Task Styling:**
- Background: `#007AFF` with 15% opacity (light blue highlight)
- Border left: 3px solid `#007AFF`
- Text: Bold or increased contrast

#### Task List Items

**Standard Task Row:**
```
▶ Task Name                                    23:45
```

**Components:**
- **Disclosure triangle:** ▶ (collapsed) or ▼ (expanded) if has children
- **Task name:** SF Pro Text, 14pt
- **Timestamp:** Right-aligned, SF Mono, 11pt, 60% opacity
- **Current indicator:** ★ or • symbol before name (if task is current)

**Row Styling:**
- Height: 32px (comfortable clicking/navigation)
- Padding: 8px 16px
- Hover: Background `#F5F5F5`
- Selected: Background `#007AFF` 15% opacity, left border 3px `#007AFF`
- Current task: Bold text, `#007AFF` color

**Hierarchy Visualization:**
- Indentation: 20px per level
- Connecting lines: Subtle gray lines (optional, macOS style)
- Parent/child relationship clear through indentation

**Empty State:**
```
┌──────────────────────────────────────────────────────┐
│  Filter:                                             │
├──────────────────────────────────────────────────────┤
│                                                      │
│                                                      │
│              No tasks yet                            │
│                                                      │
│         Press Cmd+Shift+Space to create one          │
│                                                      │
│                                                      │
└──────────────────────────────────────────────────────┘
```

**Filter No Results:**
```
┌──────────────────────────────────────────────────────┐
│  Filter: xyz                                         │
├──────────────────────────────────────────────────────┤
│                                                      │
│                                                      │
│              No matching tasks                       │
│                                                      │
│         Clear filter or try different search         │
│                                                      │
│                                                      │
└──────────────────────────────────────────────────────┘
```

#### Typography

- **Filter text:** SF Pro Text, 14pt
- **Task names:** SF Pro Text, 14pt
- **Timestamps:** SF Mono, 11pt
- **Empty state:** SF Pro Display, 16pt, 60% opacity
- **Section headers (if used):** SF Pro Display, 12pt, Semibold, all caps

#### Colors

- **Window background:** `#FFFFFF`
- **Task list background:** `#FAFAFA` (very light gray)
- **Filter bar (focused):** `#FFFFFF` with `#007AFF` border
- **Filter bar (unfocused):** `#F5F5F5`
- **Selected task:** `#007AFF` 15% opacity background
- **Current task:** `#007AFF` text or bold
- **Hover:** `#F5F5F5`

---

### 3. Parent Selector

**Purpose:** Visual tree picker for selecting parent task
**Trigger:** `Cmd+P` from Spotlight or Editor
**Platform:** macOS only

#### Visual Design

**Overlay Mode (from Spotlight):**
```
┌──────────────────────────────────────────────────────┐
│  Select Parent Task                         [× Close]│
├──────────────────────────────────────────────────────┤
│  Filter:                                             │
├──────────────────────────────────────────────────────┤
│                                                      │
│  ▶ Backend Refactor                                 │
│    ├─ Fix authentication                            │
│    └─ Update API docs                               │
│  ▶ Frontend Work                                    │
│▶   Mobile App                                       │ ← Selected
│                                                      │
└──────────────────────────────────────────────────────┘
```

**Dimensions:**
- Width: 500px
- Height: 400px or auto (scrollable)
- Centered on screen
- Modal overlay (dims background)

**In-Editor Mode (Cmd+P from Editor):**
- Reuses Editor's tree view
- Switches to "parent selection mode"
- Visual indicator: "Select parent for: [Task Name]" at top
- Same tree, different interaction (click selects immediately)

#### Task Display

**Selectable Task:**
- Standard task row (same as Editor)
- Hover shows selection preview
- Click or Enter confirms

**Disabled Task (Self or Children):**
- Dimmed text (40% opacity)
- Gray background
- Tooltip: "Cannot set task as its own parent"

**Filtered Tree:**
- Same filter bar as Editor (State 2 styling)
- Shows matching tasks with context (parent visible but dimmed)

#### Typography & Colors

Same as Editor (consistent experience)

---

## Secondary Interfaces

### 4. Settings Window

**Purpose:** Customize keyboard shortcuts and preferences
**Trigger:** Menu Bar → Hold → Settings
**Platform:** macOS only

#### Window Layout

```
┌──────────────────────────────────────────────────────────────────┐
│  Hold Settings                                      [× Close]    │
├──────────────────────────────────────────────────────────────────┤
│                                                                    │
│  ┌─────────────┐  ┌──────────────────────────────────────────┐  │
│  │  General    │  │                                          │  │
│  │  Appearance │  │        KEYBOARD SHORTCUTS                │  │
│  │► Keyboard   │  │                                          │  │
│  │  Shortcuts  │  │  Customize shortcuts to match your      │  │
│  │  About      │  │  workflow. Click any shortcut to edit.  │  │
│  └─────────────┘  │                                          │  │
│                    │  [Restore Defaults]  [Show Cheat Sheet] │  │
│                    │                                          │  │
│                    │  ───────── GLOBAL SHORTCUTS ────────     │  │
│                    │                                          │  │
│                    │  Open Spotlight                          │  │
│                    │  [Cmd][Shift][Space]                     │  │
│                    │                                          │  │
│                    └──────────────────────────────────────────┘  │
│                                                                    │
└──────────────────────────────────────────────────────────────────┘
```

**Dimensions:**
- Width: 800px
- Height: 600px
- Sidebar: 200px wide
- Main content: 600px wide

#### Shortcut Row Component

**Default State:**
```
┌────────────────────────────────────────────────────────┐
│  Open Spotlight                      [Cmd][Shift][Space]│
│  Opens task capture interface                          │
└────────────────────────────────────────────────────────┘
```

**Row Components:**
- **Shortcut name:** SF Pro Text, 14pt, Regular
- **Description:** SF Pro Text, 12pt, Regular, 70% opacity
- **Key buttons:** See "Key Button Component" below
- Row height: 60px
- Padding: 12px 16px

**Hover State:**
```
┌────────────────────────────────────────────────────────┐
│  Open Spotlight                      [Cmd][Shift][Space]│ ← Blue outline
│  Opens task capture interface        (Click to edit)    │
└────────────────────────────────────────────────────────┘
```
- Border: 2px `#007AFF`
- Background: `#F5F5F5`
- "Click to edit" hint appears

**Editing State:**
```
┌────────────────────────────────────────────────────────┐
│  Open Spotlight                                         │
│  Press new key combination...                          │
│  Currently: Cmd+Shift+Space                            │
│  ⚠️ Will conflict with: System Emoji Picker            │
│                                                         │
│  [Cancel]  [Clear]  [Set]                              │
└────────────────────────────────────────────────────────┘
```
- Expanded height: 140px
- Real-time key detection
- Conflict warning if detected

**Locked Shortcut:**
```
┌────────────────────────────────────────────────────────┐
│  Create Task                                   [Enter] │
│  Creates task at root level                    🔒      │
│  Core creation shortcut - cannot be changed            │
└────────────────────────────────────────────────────────┘
```
- Lock icon: 🔒 (14pt)
- Dimmed appearance (80% opacity)
- Tooltip on hover explains why

**Conflict Warning:**
```
┌────────────────────────────────────────────────────────┐
│  Open Spotlight                [Cmd][Shift][Space]     │
│  Opens task capture interface                          │
│  ⚠️ May conflict with: System Emoji Picker             │
│  Recommendation: Use default or change one of them     │
└────────────────────────────────────────────────────────┘
```
- Warning row: Height 20px, orange background `#FF9500` 10% opacity
- Icon: ⚠️ 12pt

#### Key Button Component

**Visual Design:**
```
[Cmd] [Shift] [Space]
```

**Styling:**
- Background: `#E5E5E5` (light gray)
- Border: 1px solid `#D1D1D6`
- Border radius: 4px
- Padding: 4px 8px
- Font: SF Mono, 13pt, Medium (monospace)
- Min-width: 40px (centered text)
- Spacing between keys: 4px

**States:**
- **Default:** Gray `#E5E5E5`
- **Hover:** Blue border `#007AFF`
- **Active (editing):** Blue background `#007AFF`, white text
- **Locked:** Gray `#A0A0A0`, dimmed

#### Category Headers

```
▼ GLOBAL SHORTCUTS (5)
```

**Styling:**
- Font: SF Pro Display, 16pt, Semibold
- Color: `#000000`
- Expandable/collapsible with disclosure triangle
- Padding: 16px 0 8px 0
- Border bottom: 1px solid `#E5E5E5`

#### Action Buttons

**Primary Button (Set, Save Changes):**
- Background: `#007AFF`
- Text: White, SF Pro Text, 14pt, Semibold
- Border radius: 6px
- Padding: 8px 16px
- Hover: `#0051D5` (darker blue)

**Secondary Button (Cancel, Clear):**
- Background: `#F5F5F5`
- Text: `#000000`, SF Pro Text, 14pt, Regular
- Border: 1px solid `#D1D1D6`
- Border radius: 6px
- Padding: 8px 16px
- Hover: `#E5E5E5`

**Restore Defaults Button:**
- Same as secondary
- Shows confirmation dialog on click

#### Typography

- **Section title:** SF Pro Display, 24pt, Bold
- **Description text:** SF Pro Text, 14pt, Regular, 70% opacity
- **Category headers:** SF Pro Display, 16pt, Semibold
- **Shortcut names:** SF Pro Text, 14pt, Regular
- **Shortcut descriptions:** SF Pro Text, 12pt, Regular, 70% opacity
- **Key buttons:** SF Mono, 13pt, Medium

#### Colors

- **Background:** `#FFFFFF`
- **Sidebar background:** `#F5F5F5`
- **Selected sidebar item:** `#E5E5E5` with `#007AFF` left border (3px)
- **Shortcut row hover:** `#F5F5F5`
- **Warning (low):** `#34C759` (green)
- **Warning (medium):** `#FF9500` (orange)
- **Warning (high):** `#FF3B30` (red)

---

### 5. Cheat Sheet Overlay

**Purpose:** Quick keyboard reference
**Trigger:** `Cmd+?` from anywhere
**Platform:** macOS only

#### Visual Design

```
┌──────────────────────────────────────────────────────────────┐
│                   HOLD - KEYBOARD SHORTCUTS                  │
│                                                      [× Close]│
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  GLOBAL SHORTCUTS                                            │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                                              │
│  Cmd+Shift+Space      Open Spotlight                        │
│  Cmd+Shift+\          Open Editor                           │
│  Cmd+Shift+Enter      Complete Current Task                 │
│  Cmd+Shift+Backspace  Dismiss Current Task                  │
│  Cmd+?                Show This Cheat Sheet                 │
│                                                              │
│  SPOTLIGHT SHORTCUTS                                         │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                                              │
│  Enter                Create Task                           │
│  Option+Enter         Create Task & Switch                  │
│  Shift+Enter          Create Child & Switch                 │
│  ...                                                         │
│                                                              │
│                    [Customize Shortcuts]  [Print]           │
└──────────────────────────────────────────────────────────────┘
```

**Dimensions:**
- Width: 700px
- Height: 600px (scrollable if needed)
- Centered on screen
- Modal overlay (semi-transparent backdrop)

**Backdrop:**
- Background: `#000000` with 40% opacity
- Blurs background content (macOS blur effect)

**Cheat Sheet Panel:**
- Background: `#FFFFFF`
- Border radius: 12px
- Shadow: Large, subtle shadow for depth

#### Shortcut Line Format

```
Cmd+Shift+Space      Open Spotlight
```

**Layout:**
- Two columns: Shortcut (left), Description (right)
- Shortcut column: 220px width, right-aligned
- Description column: Remaining width, left-aligned
- Row height: 28px
- Monospace for shortcuts, regular for descriptions

#### Typography

- **Title:** SF Pro Display, 20pt, Bold
- **Section headers:** SF Pro Display, 14pt, Semibold, all caps
- **Shortcuts:** SF Mono, 13pt, Medium (monospace)
- **Descriptions:** SF Pro Text, 13pt, Regular
- **Divider line:** ━ character or 1px border, `#E5E5E5`

#### Colors

- **Background:** `#FFFFFF`
- **Text:** `#000000`
- **Section dividers:** `#E5E5E5`
- **Section headers:** `#007AFF`

#### Action Buttons

- **Customize Shortcuts:** Opens Settings → Keyboard Shortcuts
- **Print:** Exports to PDF or prints
- Both use secondary button styling from Settings

---

### 6. iPhone Widget (StandBy Mode)

**Purpose:** Passive display of current task
**Trigger:** Automatic (Mac updates via CloudKit)
**Platform:** iOS only

#### Visual Design

**Horizontal Layout (StandBy Mode):**
```
┌─────────────────────────┐
│ Currently:              │
│ Create embeddings       │
│ script for HPC          │
│                         │
│ 23:45                   │
└─────────────────────────┘
```

**Dimensions:**
- Full width of StandBy widget area
- Height: Auto (based on text length)
- Padding: 20px all sides

**Components:**
- **Label:** "Currently:" (small, secondary)
- **Task text:** Large, primary, readable from distance
- **Timestamp:** Bottom-right, shows time since set (e.g., "23:45" = task set 23 mins 45 secs ago)

**Empty State:**
```
┌─────────────────────────┐
│                         │
│   No current task       │
│                         │
└─────────────────────────┘
```

#### Typography

- **"Currently:" label:** SF Pro Text, 14pt, Regular, 60% opacity
- **Task text:** SF Pro Display, 48pt, Regular (large, readable)
- **Timestamp:** SF Mono, 16pt, Regular, 60% opacity
- **Empty state:** SF Pro Display, 24pt, Regular, 40% opacity

#### Colors

**Dark Background (default for StandBy):**
- **Background:** `#000000` (pure black)
- **Task text:** `#FFFFFF` (pure white)
- **Label:** `#A8A8A8` (light gray)
- **Timestamp:** `#A8A8A8` (light gray)

**Light Background (if user preference):**
- **Background:** `#FFFFFF` (pure white)
- **Task text:** `#000000` (pure black)
- **Label:** `#8E8E93` (dark gray)
- **Timestamp:** `#8E8E93` (dark gray)

#### Behavior

- **Updates automatically** when Mac changes current task (2-5s lag)
- **No user interaction** (passive display only)
- **Readable from across desk** (large text optimized for distance)
- **Minimal design** (no clutter, just task and time)

---

## UI Components

### Toast Notifications

**Purpose:** Confirmation and error messages
**Display:** Contextual (below Spotlight, center of Editor, global center)

#### Visual Design

**Success Toast:**
```
✓ Task created
```

**Error Toast:**
```
⚠️ No parent task. Create a top-level task first.
```

**Styling:**
- Background: `#FFFFFF`
- Border: None
- Border radius: 8px
- Shadow: Subtle, medium spread
- Padding: 12px 20px
- Font: SF Pro Text, 13pt, Medium
- Icon size: 16pt
- Icon-text spacing: 8px

**Success Styling:**
- Icon: ✓ in `#34C759` (green)

**Error Styling:**
- Icon: ⚠️ in `#FF9500` (orange)

**Animation:**
- Fade in: 200ms ease-in
- Hold: 800ms
- Fade out: 200ms ease-out
- Total: 1.2s (1200ms)

**Positioning:**
- **From Spotlight:** 8px below input field, horizontally centered
- **From Editor:** Center of window, vertically centered
- **Global actions:** Center of screen

---

### Context Menus

**Status:** Deferred to v2 (MVP is keyboard-first)

**Planned for v2:**
- Right-click on task → Context menu
- Actions: Set as Current, Dismiss, Change Parent, Edit

---

### Loading Indicators

**Spinner (if needed for CloudKit operations):**
- Standard macOS spinner
- Color: `#007AFF`
- Size: 20pt
- Position: Center of relevant area (e.g., Editor while loading tasks)

**Progress Bar (if needed):**
- Not currently specified (unlikely to be needed for MVP)

---

## Visual Design System

### Color Palette

#### Primary Colors

| Name | Hex | Usage |
|------|-----|-------|
| **Primary Blue** | `#007AFF` | Accents, selected states, buttons |
| **Black** | `#000000` | Primary text, icons |
| **White** | `#FFFFFF` | Backgrounds, contrast text |

#### Secondary Colors

| Name | Hex | Usage |
|------|-----|-------|
| **Light Gray** | `#F5F5F5` | Inactive backgrounds, hover states |
| **Medium Gray** | `#E5E5E5` | Borders, dividers |
| **Dark Gray** | `#D1D1D6` | Secondary borders |
| **System Gray** | `#8E8E93` | Placeholder text, secondary text |

#### Semantic Colors

| Name | Hex | Usage |
|------|-----|-------|
| **Success Green** | `#34C759` | Success toasts, confirmations |
| **Warning Orange** | `#FF9500` | Warnings, medium conflicts |
| **Error Red** | `#FF3B30` | Errors, high conflicts, delete |

#### Key Button Colors

| Name | Hex | Usage |
|------|-----|-------|
| **Key Default** | `#E5E5E5` | Default key button background |
| **Key Border** | `#D1D1D6` | Key button border |
| **Key Active** | `#007AFF` | Active key button (editing) |
| **Key Locked** | `#A0A0A0` | Locked/disabled key buttons |

---

### Typography

#### Font Family

- **Primary:** SF Pro Display (headings, large text)
- **Secondary:** SF Pro Text (body, UI text)
- **Monospace:** SF Mono (code, shortcuts, timestamps)

#### Font Sizes & Weights

| Context | Font | Size | Weight | Usage |
|---------|------|------|--------|-------|
| **Spotlight Input** | SF Pro Display | 18pt | Regular | Task input text |
| **Spotlight Placeholder** | SF Pro Display | 18pt | Regular | Placeholder hint |
| **Spotlight Toast** | SF Pro Text | 12pt | Medium | Confirmation messages |
| **Editor Task** | SF Pro Text | 14pt | Regular | Task names in list |
| **Editor Filter** | SF Pro Text | 14pt | Regular | Filter bar text |
| **Editor Empty State** | SF Pro Display | 16pt | Regular | Empty state message |
| **Settings Title** | SF Pro Display | 24pt | Bold | Section titles |
| **Settings Category** | SF Pro Display | 16pt | Semibold | Category headers |
| **Settings Shortcut** | SF Pro Text | 14pt | Regular | Shortcut names |
| **Settings Description** | SF Pro Text | 12pt | Regular | Shortcut descriptions |
| **Key Button** | SF Mono | 13pt | Medium | Keyboard keys |
| **Cheat Sheet Title** | SF Pro Display | 20pt | Bold | Overlay title |
| **Cheat Sheet Shortcut** | SF Mono | 13pt | Medium | Shortcut notation |
| **Cheat Sheet Description** | SF Pro Text | 13pt | Regular | Shortcut descriptions |
| **iPhone Task** | SF Pro Display | 48pt | Regular | Current task (large) |
| **iPhone Label** | SF Pro Text | 14pt | Regular | "Currently:" label |
| **iPhone Timestamp** | SF Mono | 16pt | Regular | Time since set |

#### Text Opacity

| Opacity | Usage |
|---------|-------|
| **100%** | Primary text, active elements |
| **70%** | Secondary text, placeholders, descriptions |
| **60%** | Tertiary text, timestamps, parent names |
| **40%** | Disabled text, empty states |

---

### Spacing & Layout

#### Padding & Margins

| Context | Size | Usage |
|---------|------|-------|
| **Spotlight** | 16px horizontal, 12px vertical | Input field padding |
| **Editor Task Row** | 8px 16px | Task row padding |
| **Settings Row** | 12px 16px | Shortcut row padding |
| **Toast** | 12px 20px | Toast notification padding |
| **iPhone Widget** | 20px all sides | Widget padding |

#### Spacing Between Elements

| Context | Size | Usage |
|---------|------|-------|
| **Key buttons** | 4px | Space between keys in combo |
| **Toast below Spotlight** | 8px | Gap between input and toast |
| **Category sections** | 24px | Space between categories |
| **Icon-text spacing** | 8px | Space between icon and text |

#### Row Heights

| Context | Height | Usage |
|---------|--------|-------|
| **Spotlight** | 60px | Input field height (single line) |
| **Editor Task** | 32px | Task row height |
| **Settings Shortcut** | 60px | Shortcut row default height |
| **Cheat Sheet Line** | 28px | Shortcut line height |

#### Hierarchy Indentation

| Context | Size | Usage |
|---------|------|-------|
| **Editor Tree** | 20px per level | Nested task indentation |

---

### Border Radius

| Context | Radius | Usage |
|---------|--------|-------|
| **Spotlight Panel** | 10px | Main panel corners |
| **Toast** | 8px | Toast notification corners |
| **Cheat Sheet** | 12px | Overlay panel corners |
| **Key Button** | 4px | Keyboard key corners |
| **Primary Button** | 6px | Action button corners |

---

### Shadows

| Context | Shadow | Usage |
|---------|--------|-------|
| **Spotlight Panel** | 0 10px 30px rgba(0,0,0,0.3) | Floating panel depth |
| **Toast** | 0 4px 12px rgba(0,0,0,0.15) | Subtle notification depth |
| **Cheat Sheet** | 0 20px 60px rgba(0,0,0,0.4) | Modal overlay depth |
| **Settings Row (hover)** | 0 2px 8px rgba(0,0,0,0.1) | Subtle hover feedback |

---

## Animations & Transitions

### Toast Notifications

**Timing:**
- Fade in: 200ms (ease-in)
- Hold: 800ms
- Fade out: 200ms (ease-out)
- **Total:** 1.2s (1200ms)

**Effect:**
```
Opacity: 0 → 1 (200ms) → Hold (800ms) → 1 → 0 (200ms)
Transform: translateY(10px) → translateY(0) (200ms, ease-out)
```

---

### State Transitions

**Filter Bar (State 1 ↔ State 2):**
- Border color: 200ms ease
- Background color: 200ms ease
- No transform

**Task Selection (State 2 → State 3):**
- Background highlight: 150ms ease-in
- Border appears: 150ms ease-in

**Spotlight Open/Close:**
- Fade in: 200ms ease-out
- Scale: 0.95 → 1.0 (200ms, ease-out)
- Fade out: 150ms ease-in
- Scale: 1.0 → 0.95 (150ms, ease-in)

**Cheat Sheet Open/Close:**
- Backdrop fade: 250ms ease
- Panel fade + scale: 250ms ease-out (0.9 → 1.0 on open)

---

### Hover States

**All hover transitions:**
- Duration: 150ms
- Easing: ease

**Elements with hover:**
- Task rows (background change)
- Shortcut rows (background + border)
- Buttons (background change)
- Key buttons (border highlight)

---

## Interaction Patterns

### Keyboard Navigation

**Focus Indicators:**
- Blue ring: 2px solid `#007AFF`
- Offset: 2px outside element
- Border radius: Matches element + 2px

**Tab Order:**
- Follows visual hierarchy
- Logical flow (top to bottom, left to right)

---

### Mouse Interactions

**Click Targets:**
- Minimum size: 32px × 32px (comfortable clicking)
- Hover states precede clicks (visual feedback)

**Drag & Drop (Editor):**
- Drag preview: Semi-transparent task row (60% opacity)
- Drop zone: Blue highlight border on valid parent
- Invalid drop: Red border, cursor changes to ⛔

---

### Context-Sensitive Behavior

**Backspace Key:**
- State 2 (Filter focused): Edits filter text
- State 3 (Task selected): Dismisses task
- Visual feedback: Focus indicator shows active context

**Space Key:**
- State 2 (Filter focused): Adds space to filter
- State 3 (Task selected): Sets task as current
- Visual feedback: Same as Backspace

---

## Accessibility

### Keyboard Navigation

**All interfaces fully keyboard accessible:**
- Tab: Move between elements
- Shift+Tab: Reverse navigation
- Enter: Activate/confirm
- Esc: Cancel/close
- Arrow keys: Navigate lists/trees

### Screen Reader Support

**VoiceOver Labels:**
- All interactive elements labeled
- State announcements (focused, selected, disabled)
- Dynamic content changes announced (task updated, filter active)

**Semantic HTML/Accessibility Attributes:**
- Proper roles (button, textbox, list, listitem)
- Aria labels for icons
- Aria-live regions for toasts

### Visual Accessibility

**High Contrast Mode:**
- Increased contrast ratios
- Thicker borders (from 1px to 2px)
- No reliance on color alone (icons + text)

**Large Text Support:**
- All text scales with system font size
- Minimum touch targets maintained (32px)

**Color Blind Safe:**
- Success/warning/error use icons + color
- No meaning conveyed by color alone
- Sufficient contrast ratios (WCAG AA)

### Focus Management

**Visible focus indicators:**
- Blue ring always visible on keyboard focus
- Never rely solely on hover states

**Logical focus order:**
- Follows visual layout
- Doesn't skip elements
- Returns to logical point after modal close

---

## Summary

This UI specification provides:

✅ **Complete visual design** for all 6 interfaces
✅ **Reusable component library** (toasts, key buttons, task rows)
✅ **Consistent design system** (colors, typography, spacing)
✅ **Animation specifications** with precise timing
✅ **Interaction patterns** for keyboard and mouse
✅ **Accessibility guidelines** for all users

**Implementation Note:** All measurements and colors are final. Build exactly as specified for consistent, polished experience.

**Cross-Reference:**
- Behavior specification: Hold State Diagrams.md
- Filter details: Hold Editor Filter Spec.md
- Keyboard shortcuts: Keyboard Shortcuts Final.md
- Settings implementation: Hold Keyboard Short Cuts UI.md
