# Hold - Keyboard Shortcuts Settings Menu

**UI Specification for Settings → Keyboard Shortcuts**

This document defines the user interface for viewing and customizing keyboard shortcuts.

---

## Settings Window Layout

```
┌──────────────────────────────────────────────────────────────────┐
│  Hold Settings                                          [× Close] │
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
│                    │  Open Editor                             │  │
│                    │  [Cmd][Shift][\]                         │  │
│                    │                                          │  │
│                    │  Complete Current Task                   │  │
│                    │  [Cmd][Shift][Enter]                     │  │
│                    │                                          │  │
│                    │  Dismiss Current Task                    │  │
│                    │  [Cmd][Shift][Backspace]                 │  │
│                    │                                          │  │
│                    │  Show Shortcuts Cheat Sheet              │  │
│                    │  [Cmd][?]                                │  │
│                    │                                          │  │
│                    │  ─────── SPOTLIGHT SHORTCUTS ───────     │  │
│                    │                                          │  │
│                    │  Create Task                             │  │
│                    │  [Enter]                                 │  │
│                    │                                          │  │
│                    │  Create Task & Switch                    │  │
│                    │  [Option][Enter]                         │  │
│                    │                                          │  │
│                    │  Create Child & Switch                   │  │
│                    │  [Shift][Enter]                          │  │
│                    │                                          │  │
│                    │  (scroll for more...)                    │  │
│                    │                                          │  │
│                    └──────────────────────────────────────────┘  │
│                                                                    │
└──────────────────────────────────────────────────────────────────┘
```

---

## Data Structure

### Shortcut Categories

```json
{
  "shortcuts": {
    "global": [
      {
        "id": "open_spotlight",
        "name": "Open Spotlight",
        "description": "Opens task capture interface",
        "default": ["Cmd", "Shift", "Space"],
        "current": ["Cmd", "Shift", "Space"],
        "customizable": true,
        "conflicts": ["system.emoji_picker"]
      },
      {
        "id": "open_editor",
        "name": "Open Editor",
        "description": "Opens task management tree view",
        "default": ["Cmd", "Shift", "\\"],
        "current": ["Cmd", "Shift", "\\"],
        "customizable": true
      },
      {
        "id": "complete_current",
        "name": "Complete Current Task",
        "description": "Marks current task done, advances to next",
        "default": ["Cmd", "Shift", "Enter"],
        "current": ["Cmd", "Shift", "Enter"],
        "customizable": true,
        "note": "Blocked when Editor/Spotlight open"
      },
      {
        "id": "dismiss_current",
        "name": "Dismiss Current Task",
        "description": "Removes current task without completing",
        "default": ["Cmd", "Shift", "Backspace"],
        "current": ["Cmd", "Shift", "Backspace"],
        "customizable": true,
        "note": "Blocked when Editor/Spotlight open"
      },
      {
        "id": "show_help",
        "name": "Show Shortcuts Cheat Sheet",
        "description": "Displays keyboard reference overlay",
        "default": ["Cmd", "?"],
        "current": ["Cmd", "?"],
        "customizable": true,
        "conflicts": ["some_apps.help_menu"]
      }
    ],
    "spotlight": [
      {
        "id": "create_task",
        "name": "Create Task",
        "description": "Creates task at root level",
        "default": ["Enter"],
        "current": ["Enter"],
        "customizable": false,
        "locked_reason": "Core creation shortcut"
      },
      {
        "id": "create_and_switch",
        "name": "Create Task & Switch",
        "description": "Creates task and makes it current",
        "default": ["Option", "Enter"],
        "current": ["Option", "Enter"],
        "customizable": false,
        "locked_reason": "Modifier combination defines behavior"
      },
      {
        "id": "create_child",
        "name": "Create Child & Switch",
        "description": "Creates child under current task",
        "default": ["Shift", "Enter"],
        "current": ["Shift", "Enter"],
        "customizable": false,
        "locked_reason": "Modifier combination defines behavior"
      },
      {
        "id": "create_sibling",
        "name": "Create Sibling",
        "description": "Creates sibling of current task",
        "default": ["Cmd", "Enter"],
        "current": ["Cmd", "Enter"],
        "customizable": false,
        "locked_reason": "Modifier combination defines behavior"
      },
      {
        "id": "create_sibling_switch",
        "name": "Create Sibling & Switch",
        "description": "Creates sibling and makes it current",
        "default": ["Cmd", "Option", "Enter"],
        "current": ["Cmd", "Option", "Enter"],
        "customizable": false,
        "locked_reason": "Modifier combination defines behavior"
      },
      {
        "id": "select_parent",
        "name": "Select Parent",
        "description": "Opens parent selector for two-step creation",
        "default": ["Cmd", "P"],
        "current": ["Cmd", "P"],
        "customizable": true,
        "conflicts": ["system.print_dialog"]
      },
      {
        "id": "load_current",
        "name": "Load Current Task",
        "description": "Fills input with current task for editing",
        "default": ["ArrowUp"],
        "current": ["ArrowUp"],
        "customizable": true
      },
      {
        "id": "clear_text",
        "name": "Clear to Blank",
        "description": "Clears input text",
        "default": ["ArrowDown"],
        "current": ["ArrowDown"],
        "customizable": true
      },
      {
        "id": "close_spotlight",
        "name": "Close Spotlight",
        "description": "Closes without action",
        "default": ["Esc"],
        "current": ["Esc"],
        "customizable": false,
        "locked_reason": "Standard macOS close pattern"
      }
    ],
    "editor": [
      {
        "id": "start_filter",
        "name": "Start Filtering",
        "description": "Type any character to filter tasks",
        "default": ["Any letter/number"],
        "current": ["Any letter/number"],
        "customizable": false,
        "locked_reason": "Context-driven behavior"
      },
      {
        "id": "navigate_tasks",
        "name": "Navigate Tasks",
        "description": "Move through tasks/results (hold Shift to reverse)",
        "default": ["Tab"],
        "current": ["Tab"],
        "customizable": false,
        "locked_reason": "Standard navigation pattern"
      },
      {
        "id": "navigate_arrows",
        "name": "Navigate Tasks (Arrows)",
        "description": "Up/down through visible tasks",
        "default": ["↑/↓"],
        "current": ["↑/↓"],
        "customizable": false,
        "locked_reason": "Standard navigation pattern"
      },
      {
        "id": "set_current",
        "name": "Set as Current",
        "description": "Makes selected task the current focus",
        "default": ["Space"],
        "current": ["Space"],
        "customizable": true
      },
      {
        "id": "dismiss_task",
        "name": "Dismiss Task",
        "description": "Removes selected task from list",
        "default": ["Backspace"],
        "current": ["Backspace"],
        "customizable": true,
        "note": "Only when task selected, not filter"
      },
      {
        "id": "change_parent",
        "name": "Change Parent",
        "description": "Opens parent selector to reparent task",
        "default": ["Cmd", "P"],
        "current": ["Cmd", "P"],
        "customizable": true,
        "conflicts": ["system.print_dialog"]
      },
      {
        "id": "clear_filter",
        "name": "Clear Filter",
        "description": "Returns to tree view",
        "default": ["Esc"],
        "current": ["Esc"],
        "customizable": false,
        "locked_reason": "Standard cancel pattern"
      }
    ],
    "parent_selector": [
      {
        "id": "ps_navigate_arrows",
        "name": "Navigate Tasks",
        "description": "Move through tree up/down",
        "default": ["↑/↓"],
        "current": ["↑/↓"],
        "customizable": false,
        "locked_reason": "Standard navigation"
      },
      {
        "id": "ps_navigate_tab",
        "name": "Navigate Tasks",
        "description": "Move through tree (hold Shift to reverse)",
        "default": ["Tab"],
        "current": ["Tab"],
        "customizable": false,
        "locked_reason": "Standard navigation"
      },
      {
        "id": "ps_filter",
        "name": "Filter Tree",
        "description": "Type to show only matching tasks",
        "default": ["Any letter/number"],
        "current": ["Any letter/number"],
        "customizable": false,
        "locked_reason": "Context-driven behavior"
      },
      {
        "id": "ps_select",
        "name": "Select Parent",
        "description": "Confirms selection",
        "default": ["Enter"],
        "current": ["Enter"],
        "customizable": false,
        "locked_reason": "Standard confirm pattern"
      },
      {
        "id": "ps_cancel",
        "name": "Cancel Selection",
        "description": "Returns without selecting",
        "default": ["Esc"],
        "current": ["Esc"],
        "customizable": false,
        "locked_reason": "Standard cancel pattern"
      }
    ]
  }
}
```

---

## UI Components

### Shortcut Row

Each shortcut displays as:

```
┌────────────────────────────────────────────────────────┐
│  Shortcut Name                      [Key][Combo][Here] │
│  Description text goes here         (Click to edit)    │
│  ⚠️ Conflicts with: System Emoji Picker                │
└────────────────────────────────────────────────────────┘
```

**States:**
- **Default:** Gray keys, white background
- **Hover:** Blue outline appears
- **Editing:** Keys highlighted, "Press keys..." prompt
- **Conflict:** Yellow warning icon and message
- **Locked:** Gray keys with lock icon, "Why?" tooltip

### Editing Mode

When user clicks a customizable shortcut:

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

**Validation:**
- Detects conflicts with system shortcuts
- Detects conflicts with other Hold shortcuts
- Shows real-time feedback as keys pressed
- "Set" button enabled only if valid

### Categories

Shortcuts grouped by context with collapsible sections:

```
▼ GLOBAL SHORTCUTS (5)
  - Open Spotlight
  - Open Editor
  - Complete Current Task
  - Dismiss Current Task
  - Show Shortcuts Cheat Sheet

▼ SPOTLIGHT SHORTCUTS (9)
  - Create Task
  - Create Task & Switch
  - Create Child & Switch
  - ...

▼ EDITOR SHORTCUTS (8)
  - Start Filtering
  - Next Task
  - Previous Task
  - ...

▼ PARENT SELECTOR SHORTCUTS (5)
  - Navigate Tasks
  - Filter Tree
  - ...
```

**Expandable/Collapsible:**
- Click header to expand/collapse
- Shows count of shortcuts in category
- Persists state between opens

---

## Special UI Elements

### Locked Shortcuts

Some shortcuts can't be customized (core behaviors):

```
┌────────────────────────────────────────────────────────┐
│  Create Task                                   [Enter] │
│  Creates task at root level                    🔒      │
│  Core creation shortcut - cannot be changed            │
└────────────────────────────────────────────────────────┘
```

**Hover tooltip on lock icon:**
"This shortcut is locked because it's a core creation pattern. Changing it would break modifier combinations (Option+Enter, Shift+Enter, etc.)"

### Conflict Warnings

When a shortcut conflicts with system or app shortcuts:

```
┌────────────────────────────────────────────────────────┐
│  Open Spotlight                [Cmd][Shift][Space]     │
│  Opens task capture interface                          │
│  ⚠️ May conflict with: System Emoji Picker             │
│  Recommendation: Use default or change one of them     │
└────────────────────────────────────────────────────────┘
```

**Severity levels:**
- 🔴 **High:** Will definitely conflict (e.g., Cmd+Q for quit)
- 🟡 **Medium:** May conflict depending on settings (e.g., Cmd+Space)
- 🟢 **Low:** Rare edge case conflict

### Context Notes

Some shortcuts have contextual behavior explained:

```
┌────────────────────────────────────────────────────────┐
│  Dismiss Task                             [Backspace]  │
│  Removes selected task from list                       │
│  ℹ️ Only when task selected, not filter bar            │
└────────────────────────────────────────────────────────┘
```

---

## Action Buttons

### Top Right Actions

```
[Restore Defaults]  [Show Cheat Sheet]
```

**Restore Defaults:**
- Confirmation dialog: "Reset all shortcuts to defaults?"
- Reverts all customizations
- Can't be undone

**Show Cheat Sheet:**
- Opens `Cmd+?` help overlay
- Shows current shortcuts (including customizations)
- Same as pressing `Cmd+?` anywhere in app

### Bottom Actions

```
                              [Cancel]  [Save Changes]
```

**Save Changes:**
- Writes new shortcuts to preferences
- Validates all shortcuts
- Shows confirmation: "Shortcuts updated"

**Cancel:**
- Discards unsaved changes
- Returns to previous settings

---

## Search & Filter

At top of shortcuts pane:

```
┌────────────────────────────────────────────────────────┐
│  🔍 Search shortcuts...                                │
└────────────────────────────────────────────────────────┘

Matching shortcuts (3):
  - Open Spotlight (Global)
  - Close Spotlight (Spotlight)
  - Load Current Task (Spotlight)
```

**Behavior:**
- Live search as you type
- Matches name, description, or keys
- Shows category for context
- Highlights matching text

---

## Keyboard Shortcuts Cheat Sheet Overlay

Accessible via `Cmd+?` from anywhere in the app.

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
│  Cmd+Enter            Create Sibling                        │
│  Cmd+Option+Enter     Create Sibling & Switch               │
│  Cmd+P                Select Parent                         │
│  ↑                    Load Current Task                     │
│  ↓                    Clear to Blank                        │
│  Esc                  Close Spotlight                       │
│                                                              │
│  (scroll for more...)                                        │
│                                                              │
│                    [Customize Shortcuts]  [Print]           │
└──────────────────────────────────────────────────────────────┘
```

**Features:**
- **Floating overlay** over current window
- **Scrollable** if many shortcuts
- **Shows current mappings** (including customizations)
- **Print button** exports to PDF
- **Customize button** opens Settings → Keyboard Shortcuts
- **Close with Esc** or click X
- **Semi-transparent backdrop** (dims background)

---

## Implementation Notes

### Conflict Detection

**System-level conflicts to check:**
- Cmd+Space (Spotlight)
- Cmd+Shift+Space (Emoji picker on some systems)
- Cmd+Tab (App switcher)
- Cmd+Q (Quit)
- Cmd+H (Hide)
- Cmd+M (Minimize)
- Cmd+W (Close window)
- Cmd+P (Print dialog)

**Algorithm:**
1. User presses new key combo
2. Check against system shortcuts list
3. Check against other Hold shortcuts
4. Show warnings if conflicts detected
5. Allow override with confirmation

### Storage

Save shortcuts to:
```
~/Library/Preferences/com.hold.app.shortcuts.plist
```

**Format:**
```xml
<dict>
  <key>open_spotlight</key>
  <array>
    <string>Cmd</string>
    <string>Shift</string>
    <string>Space</string>
  </array>
  <key>open_editor</key>
  <array>
    <string>Cmd</string>
    <string>Shift</string>
    <string>\</string>
  </array>
  <!-- ... -->
</dict>
```

### Reset Mechanism

**Per-shortcut reset:**
- Hover over shortcut → "Reset to default" icon appears
- Click to reset just that shortcut

**Global reset:**
- "Restore Defaults" button at top
- Confirmation required
- Resets ALL shortcuts

---

## Accessibility

### Keyboard Navigation

Settings window fully keyboard accessible:
- `Tab` - Move between shortcuts
- `Enter` - Start editing selected shortcut
- `Esc` - Cancel editing
- `Cmd+F` - Focus search field
- `Cmd+R` - Restore defaults (with confirmation)

### Screen Reader Support

Each shortcut announces:
- Name
- Current key combination
- Description
- Customizable status
- Conflict warnings (if any)

### Visual Indicators

- **High contrast mode** support
- **Large text** scales appropriately
- **Focus indicators** clearly visible
- **Color blind safe** (warnings use icons + color)

---

## User Flows

### Flow 1: First-Time User

1. Opens Settings → Keyboard Shortcuts
2. Sees organized list of all shortcuts with defaults
3. Reads descriptions to understand each shortcut
4. Clicks "Show Cheat Sheet" to see overlay
5. Prints cheat sheet for reference
6. Starts using app with defaults

### Flow 2: Conflict Resolution

1. User encounters conflict with Cmd+Shift+Space (emoji picker)
2. Opens Settings → Keyboard Shortcuts
3. Yellow warning already visible on "Open Spotlight" row
4. Clicks the shortcut to edit
5. Presses new combination: Cmd+Option+Space
6. No conflicts detected, warning disappears
7. Clicks "Save Changes"
8. New shortcut immediately active

### Flow 3: Power User Customization

1. Opens Settings → Keyboard Shortcuts
2. Customizes global shortcuts to match other tools
3. Changes Cmd+P to Cmd+Shift+P (avoids print dialog)
4. Changes Cmd+? to Cmd+Shift+? (avoids help menu)
5. Saves changes
6. Muscle memory now consistent across tools

---

## Visual Design Specs

### Color Palette

**Key buttons:**
- Default: `#E5E5E5` (light gray)
- Hover: `#007AFF` border (macOS blue)
- Active: `#007AFF` background, white text
- Locked: `#A0A0A0` (dimmed gray)

**Warnings:**
- High: `#FF3B30` (red)
- Medium: `#FF9500` (orange)
- Low: `#34C759` (green)

**Background:**
- Settings pane: `#FFFFFF` (white)
- Shortcuts list: `#F5F5F5` (off-white)

### Typography

- **Category headers:** SF Pro Display, 16pt, Semibold
- **Shortcut names:** SF Pro Text, 14pt, Regular
- **Descriptions:** SF Pro Text, 12pt, Regular, 70% opacity
- **Keys:** SF Mono, 13pt, Medium (monospace for consistency)

### Spacing

- **Row height:** 60px (comfortable clicking)
- **Padding:** 16px (breathing room)
- **Key spacing:** 4px between keys in combo
- **Section spacing:** 24px between categories

---

## Summary

This settings UI provides:
✅ **Complete visibility** - All shortcuts shown with descriptions  
✅ **Easy customization** - Click to edit, visual feedback  
✅ **Conflict detection** - Warns before creating problems  
✅ **Discoverability** - Search, categories, cheat sheet  
✅ **Safety** - Locked shortcuts, restore defaults, confirmation  
✅ **Accessibility** - Keyboard nav, screen reader, high contrast

**Goal:** Users can view defaults, customize what they need, and have confidence their shortcuts work perfectly with their workflow.