# Hold - Project Vision

## One-Liner
Hold: Stop holding tasks in your head—let your devices hold them for you.

## Elevator Pitch (30 seconds)
Hold is a minimalist productivity app that frees up mental capacity by holding your current task so your brain doesn't have to.

Set your task with a single hotkey on Mac, and it displays passively on your iPhone in Standby Mode. No lists, no notifications, no complexity—just one task, clearly held, always visible when you need it.

It's cognitive relief technology designed for people who want to focus on doing the work, not managing it.

---

## The Core Problems

### Everyone Already Has a Task Manager
Your TODO list exists somewhere—Trello, Obsidian, Notion, Things, Reminders, Todoist, or a bullet journal. You've chosen a system that works for your planning and organization.

**Hold doesn't replace that. Hold solves different problems.**

### Problem 1: Out of Sight, Out of Mind
For ADHD folks (and anyone who gets easily distracted), what you're working on needs to be visible. Constantly.

Switching between tabs or windows—which accumulate at the speed of light—creates cognitive burden. It's clutter. It's chaos. Having to open your task manager, find the right project, and locate your current task just to remind yourself what you're doing is exhausting.

**A simple display whose sole purpose is to always reflect what the current task is provides relief.**

Your iPhone, sitting horizontally in Standby Mode, becomes a perfect mirror for what needs your attention. Always live. Always visible. No switching, no searching, no cognitive cost.

### Problem 2: Tasks Become Stale Instantly
Even when you have a task displayed, two things happen:

**Either the task is too vague to be useful:**
- "Do frontend work" ← Okay, but *what specifically* right now?

**Or it's too specific and becomes outdated within minutes:**
- "Solve the JSON parsing error when user does XYZ" 
- → Actually, now I need to check the API docs
- → Wait, now I'm reading Stack Overflow about async handling
- → Hmm, need to review the error logging implementation first

**By the time you glance at your task, it no longer reflects what you're actually doing.** Looking at it doesn't help—you're already lost again.

### Problem 3: Rapid Capture Is Painful Everywhere Else
To keep that display accurate, you need rapid-fire capture. As your actual current task evolves ("Check API docs" → "Review async patterns" → "Update error handler"), you need to update it *instantly*.

Traditional task managers require:
- Opening the app
- Finding the right place
- Deciding on categorization
- Typing with proper formatting
- Closing and returning to work

**That's too slow. By the time you've done this, you've lost your train of thought.**

### Problem 4: The Apple Notes Phenomenon
Many ADHD folks default to Apple Notes because **it's safe to be messy there**. No structure required. No system to maintain. No categories to manage.

It's the only thing that's stood the test of time because novelty wears off, and structure becomes painful. Every other system—Notion, Obsidian, elaborate Trello boards—eventually feels like a burden.

But Apple Notes has its own problems:
- A million notes named "TODO"
- Finding the right note requires searching
- Capturing parent-child task relationships is clunky
- No way to display the current task externally

**What if you had Apple Notes' speed and messiness, but with:**
- Hierarchical relationships when you need them
- A permanent external display of your current focus
- No ongoing maintenance or organization required

---

## The Solution

Hold provides two missing pieces in your productivity stack:

### iPhone: Your Current Objective Display
- Shows what you're focused on **right now**
- No lists, no options, no decisions—just your singular objective
- Readable from across your desk in Standby Mode
- **Always live**—updates as your actual work evolves
- Works with ANY task management system (Things, Todoist, your bullet journal, etc.)
- Zero interaction required—it's a mirror, not an app

### Mac: Your Staging Area
- **Instant capture** at speed of thought—hotkey opens, type, done
- Update your current task as fast as your work evolves
- **Safe to be messy**—no forced organization, no maintenance
- Hierarchical brain dumps preserve context without requiring structure
- Parent/child/sibling relationships mimic how tasks pop up in your head (cause and effect)
- Process into your real task manager later, or let completed tasks naturally fade

### How It Works Together

**The iPhone solves focus:**
"What should I be doing right now?" → Look at your phone → See exactly what → Return to work

**The Mac solves capture:**
Work is evolving → Hit `Cmd+Shift+Space` → Update in 2 seconds → Display updates instantly

**Together:** Your current objective is always visible and always accurate. You never have to remember. You never have to search.

---

## Core Philosophy

### Hold is RAM, Not Your Hard Drive

Most task managers are designed for comprehensive planning and organization. Hold is designed for two specific moments:

1. **Mid-flow capture**: When a thought strikes and you need to capture it *instantly* without breaking concentration
2. **Singular focus**: When you need to know what to work on without opening apps or scanning lists

By being excellent at these two things—and nothing else—Hold complements your existing workflow rather than replacing it.

**The Mac is your staging area:** Fast, hierarchical when needed, temporary, safe to be messy.  
**The iPhone is your focus anchor:** One task, always visible, zero decisions.

Process staged tasks into your main system whenever it makes sense. Or don't—completed tasks disappear, and Hold never nags you to organize them.

### Intentional Limitation as Liberation

By splitting the interface into two distinct modes—capture (Mac) and focus (iPhone)—Hold eliminates the complexity that makes most productivity tools exhausting to use.

The Mac is where complexity lives: fast keyboard shortcuts, tree views, hierarchical capture. But it's **optional complexity**—you only engage with it when brain-dumping or orienting yourself.

The iPhone is where simplicity lives: one task, passively displayed, zero decisions.

Inspired by minimalist tech like Remarkable, TRMNL, and Light Phone, combined with Apple's design language for a native, polished experience.

---

## User Experience

### Basic Flow

1. **Working on Mac** → Think "I should focus on X" → Hit `Cmd+Shift+Space` → Type task → Press `Enter`
2. **iPhone charging horizontally nearby** → Widget shows "Currently: Writing proposal | 23:45"
3. **Glance at widget** → Reminded of focus without breaking flow → Return to work
4. **Work evolves** → Hit hotkey → Type new task → 2 seconds → iPhone updates

### Real ADHD Workflow

1. Working on "Create embeddings script"
2. Hit a wall, need to debug environment
3. `Cmd+Shift+Space` → "Debug environment setup" → `Shift+Enter` (creates child, switches to it)
4. iPhone now shows "Debug environment setup"
5. While debugging, realize you need to check the Stack Overflow docs
6. `Cmd+Shift+Space` → "Review async error handling patterns" → `Option+Enter`
7. iPhone updates instantly
8. Complete that → `Cmd+Shift+Enter` → Auto-advances to next task
9. Back to debugging, which leads back to original embedding work
10. **Never lost context, never had to remember the chain, never opened your task manager**

### Brain Dump Session

1. Hit `Cmd+Shift+Space` → "Fix React bug" → `Shift+Enter` (create child)
2. "Check colleague's work" → `Cmd+Option+Enter` (create sibling, switch to it)
3. "Update tests" → `Cmd+Option+Enter` (another sibling)
4. "Research animation library" → `Cmd+Enter` (sibling, don't switch)
5. **Four subtasks captured in seconds, all properly organized, no friction**

### Quick Actions Anywhere

- `Cmd+Shift+Enter` → Complete current task (auto-advance to next)
- `Cmd+Shift+Backspace` → Dismiss current task (remove it)
- `Cmd+Shift+Z` → Undo last action
- `Cmd+Shift+\` → Open tree view to see everything

**No setup. Minimal learning curve. No ongoing maintenance.**

---

## How Hold Fits Into Your Workflow

```
Existing task manager (Things, Todoist, Notion, etc.)
    ↓
  [Planned work, organized projects, long-term goals]
    ↓
Hold Mac (Staging Area)
    ↓
  [Quick captures, brain dumps, active working memory]
    ↓
Hold iPhone (Focus Display)
    ↓
  [Current objective only - always live, always visible]
```

### Example Workflow

**Morning planning in your main system:**
- Open Things/Todoist/your bullet journal
- Review today's work: "Build user authentication feature"
- Set that in Hold → iPhone now displays it

**During deep work:**
- Realize you need to "Check JWT library docs" → `Cmd+Shift+Space` → Done in 2 seconds
- Now iPhone shows "Check JWT library docs" while you read
- Finish reading, need to "Install JWT package" → Update in Hold → iPhone updates instantly
- Complete installation → Return to "Build authentication"

**Throughout the day:**
- Random thought: "Email Sarah about deployment" → Quick capture in Hold
- It's not part of your current focus, just captured as a sibling for later
- Eventually process these into your main task manager, or mark complete and they fade

**Hold doesn't care if you organize tasks. It just holds them until you're ready.**

---

## What Makes It Different

- **Not a replacement task manager** - Works alongside Things, Todoist, OmniFocus, Notion, Obsidian, bullet journals, etc.
- **Staging area philosophy** - Hold tasks temporarily while in flow, process them properly later
- **RAM for your brain** - Fast capture → temporary storage → clear when complete
- **Focus display, not task list** - iPhone shows your current objective, not everything you need to do
- **Always live** - Updates as your work evolves, stays accurate without effort
- **Safe to be messy** - Like Apple Notes, but with external display and optional structure
- **No forced organization** - Capture hierarchies if helpful, flat if not; process or ignore as needed
- **Zero maintenance** - Completed tasks fade naturally; no ongoing tidying required
- **Two-interface design** - Capture lives on Mac, focus lives on iPhone
- **Out of sight is no longer out of mind** - Your current task is always visible from across your desk

---

## Target User

Anyone who:

- Already uses a task manager but needs faster capture during flow state
- Has ADHD or ADHD-like working style (gets distracted easily, out of sight = out of mind)
- Needs to see what they're working on without tab-switching
- Finds their tasks become stale quickly as work evolves
- Values Apple Notes' speed and messiness but wants optional structure
- Works on Mac with iPhone nearby
- Wants tools that help rather than demand attention
- Needs rapid-fire capture without breaking concentration
- Benefits from always-visible focus reminders

---

## Positioning Statement

**For** knowledge workers who already have a task management system

**Who** need faster capture during flow state and constant visibility of their current objective

**Hold** is a staging area and focus display

**That** captures speed-of-thought tasks before they're lost and displays your singular objective without distraction

**Unlike** comprehensive task managers that require proper organization upfront and live inside apps you have to open

**Hold** acts as RAM for your productivity system—temporary, fast, messy-friendly, and always showing what matters right now on a device you can see

---

## Brand Essence

**Hold = Mental Space**

The weight in the name reflects the mental weight you're releasing. When you set a task in Hold, you're not just logging it—you're letting go of the responsibility to remember it.

The iPhone holds your attention on one thing.  
The Mac holds your working memory.  
Together, they hold space in your mind for actual work.