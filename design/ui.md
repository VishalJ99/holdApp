# Hold - User Interface Documentation

**Last Updated:** November 2025  
**Version:** 1.0  
**For:** UI Designers, Frontend Developers, iOS/macOS Engineers

---

## Table of Contents

1. [Design Philosophy](#design-philosophy)
2. [Brand Identity](#brand-identity)
3. [Typography System](#typography-system)
4. [Color System](#color-system)
5. [Spacing & Layout](#spacing--layout)
6. [Component Specifications](#component-specifications)
7. [Platform Implementation](#platform-implementation)
8. [Animation & Motion](#animation--motion)
9. [Dark Mode](#dark-mode)
10. [Assets & Resources](#assets--resources)

---

## Design Philosophy

### Visual Principles

Hold's visual design follows three guiding principles derived from minimalist technology brands (Remarkable, TRMNL, Light Phone) and Apple's Human Interface Guidelines:

**1. Clarity**
- Every element has a clear purpose
- Visual hierarchy established through size and weight, not decoration
- Interface is understandable at a glance

**2. Deference**
- UI elements never compete with content (the task text)
- Interface recedes, content is primary
- Generous whitespace lets content breathe

**3. Depth**
- Subtle layering creates spatial relationships
- Translucency and blur indicate modality
- Shadows used sparingly, only for functional hierarchy

### Design Influences

**Apple HIG:**
- Native system components and behaviors
- SF Pro typography system
- System colors for semantic meaning
- Dynamic Type for accessibility

**Minimalist Tech Aesthetic:**
- Monochrome or near-monochrome palette
- Typography as primary UI element
- Generous spacing (20-32pt minimum)
- Material honesty (work with platform constraints)

### What Makes Hold Feel "Apple"

- Uses SF Pro (Apple's system font) exclusively
- Follows Apple's 8pt grid system
- Respects system appearance modes (light/dark)
- Uses system-standard controls and patterns
- Adheres to minimum touch target sizes (44x44pt)
- Supports Dynamic Type and accessibility features

---

## Brand Identity

### App Name & Positioning

**Name:** Hold  
**Tagline:** Stop holding it in your head  
**Category:** Productivity / Focus

**Brand Voice:**
- Calm and reassuring (not urgent or pushy)
- Simple and direct (no jargon or complexity)
- Supportive (helping, not commanding)

### App Icon

**Design Approach:**
- Extremely simple geometric form
- Monochrome or near-monochrome
- No gradients, no shadows, no complexity

**Concept Options:**
1. **Letter H:** Simple sans-serif capital H in rounded square
2. **Cupped Hands:** Minimal outline of hands holding something
3. **Single Square:** Solid square representing "held" space
4. **Minimal Container:** Simple open box shape

**Specifications:**
- Size: 1024x1024px (App Store requirement)
- Format: PNG with transparency
- Corner radius: 22.37% (Apple standard for rounded squares)
- Background: Solid color or subtle gradient
- Foreground: High contrast mark

**Example Mockup (Concept 1 - Letter H):**
```
Background: #2C2C2C (dark charcoal)
Foreground: #FAFAFA (off-white)
H: SF Pro Display Bold, optically centered
Border: None
Effect: None (flat design)
```

### Marketing Colors

While the app interface is monochrome, marketing materials can use a subtle accent:

**Primary Brand Color:** `#5B7C99` (muted blue-gray)  
**Use:** Website headers, App Store screenshots borders (subtle), promotional graphics

**Supporting Grays:**
- `#1A1A1A` (dark gray, almost black)
- `#FAFAFA` (light gray, almost white)
- `#8E8E93` (mid gray, system gray)

---

## Typography System

### Font Family: SF Pro

Hold uses **SF Pro** exclusively—Apple's system font designed for optimal legibility across all devices and sizes.

**Variants:**
- **SF Pro Text:** Use for sizes 19pt and below
- **SF Pro Display:** Use for sizes 20pt and above
- System automatically switches between variants at runtime

**Weights Used in Hold:**
- **Regular (400):** Body text, task display
- **Medium (500):** Secondary emphasis
- **Semibold (600):** Strong emphasis, titles
- **Bold (700):** Rare, only for critical alerts (if any)

**Why SF Pro:**
- Native to Apple platforms (no custom font loading)
- Optimized for screen legibility
- Supports Dynamic Type automatically
- Variable font with optical sizing
- Includes extensive language support

### Text Styles

Hold uses a minimal type scale aligned with Apple's built-in text styles:

| Element | Style | Size | Weight | Line Height | Usage |
|---------|-------|------|--------|-------------|-------|
| **Mac Task Display** | Body | 18pt | Regular | 24pt (1.33) | Current task in overlay |
| **Mac Input** | Body | 18pt | Regular | 24pt | Text field |
| **Mac Hint** | Footnote | 14pt | Regular | 18pt (1.29) | Placeholder text |
| **iPhone Widget Task** | Title 3 | 26pt | Medium | 34pt (1.31) | Task text in Standby |
| **iPhone Widget Timer** | Title 2 | 32pt | Semibold | 40pt (1.25) | Countdown display |
| **iPhone Widget Label** | Caption 1 | 16pt | Regular | 20pt (1.25) | "Currently:" prefix |

### Typography Implementation

**macOS (SwiftUI):**
```swift
// Task display text
Text(taskText)
    .font(.system(size: 18, weight: .regular, design: .default))
    .foregroundColor(.primary)

// Hint text
Text("What are you holding?")
    .font(.system(size: 14, weight: .regular))
    .foregroundColor(.secondary)
```

**iOS Widget (SwiftUI):**
```swift
// Widget task text
Text(taskText)
    .font(.system(size: 26, weight: .medium, design: .default))
    .foregroundColor(.primary)
    .lineLimit(3)
    .truncationMode(.tail)
```

### Dynamic Type Support

**Scaling Table (iOS):**

| User Setting | Widget Base (26pt) | Widget Timer (32pt) |
|--------------|-------------------|-------------------|
| Extra Small | 22pt | 28pt |
| Small | 24pt | 30pt |
| Medium (Default) | 26pt | 32pt |
| Large | 28pt | 35pt |
| Extra Large | 31pt | 39pt |
| XXL | 34pt | 43pt |
| XXXL | 37pt | 47pt |

**Implementation:**
```swift
// Automatically scales with user's preferred text size
.font(.system(.title3, design: .default))
```

### Tracking (Letter Spacing)

**SF Pro includes automatic tracking adjustments**—do not manually override unless absolutely necessary.

Apple's tracking values (for reference):

| Size | Tracking (1/1000em) |
|------|-------------------|
| 6pt | +41 |
| 8pt | +26 |
| 11pt | +6 |
| 14pt | 0 |
| 17pt | -8 |
| 20pt | -16 |
| 24pt | -19 |
| 28pt | -22 |
| 34pt | -20 |

**In Practice:** Let the system handle tracking. Only adjust in exceptional cases (e.g., all-caps headers, but Hold doesn't use these).

---

## Color System

### Philosophy: Monochrome with System Integration

Hold uses **semantic system colors** that automatically adapt to light/dark mode and respect user accessibility settings.

### Color Palette

**Primary Colors (Semantic):**

| Color Name | Light Mode | Dark Mode | Usage |
|------------|------------|-----------|-------|
| **Primary Text** | `#1A1A1A` | `#EBEBEB` | Task text, main content |
| **Secondary Text** | `#8E8E93` | `#98989D` | Hints, labels, metadata |
| **Background** | `#FAFAFA` | `#1C1C1E` | Overlay background, widget background |
| **Separator** | `#DEDEDE` (20% opacity) | `#404040` (20% opacity) | Borders, dividers |

**Implementation (System Colors):**
```swift
// macOS/iOS (SwiftUI)
.foregroundColor(.primary)      // Primary text
.foregroundColor(.secondary)    // Secondary text
.background(.background)        // Backgrounds
.border(Color.separator)        // Borders
```

**Why System Colors:**
- Automatically adapt to light/dark mode
- Respect Increase Contrast accessibility setting
- Maintain consistency with platform
- No manual color management needed

### Accent Color (Rare Use)

**Brand Accent:** `#5B7C99` (muted blue-gray)

**Usage:**
- Interactive state (hover on Mac, if needed)
- Focus indicators (if default system color insufficient)
- Sync status indicator (cloud icon when syncing)

**NOT used for:**
- Text (always use system colors)
- Backgrounds
- Decorative elements

### Color Contrast Standards

All text meets WCAG 2.1 standards:

| Context | Requirement | Hold's Approach |
|---------|-------------|-----------------|
| Body text | 4.5:1 minimum | 14:1 (light), 12:1 (dark) |
| Large text (18pt+) | 3:1 minimum | 14:1 (light), 12:1 (dark) |
| Widget (distance reading) | 7:1 ideal | 15:1 achieved |

### Transparency & Blur

**Mac Overlay Background:**
- Background color: System background at 95% opacity
- Blur effect: 40px blur radius (NSVisualEffectView)
- Vibrancy: Material type `.popover`

**Implementation (macOS):**
```swift
// Native blur effect
.background(.ultraThinMaterial)

// Or custom NSVisualEffectView
let blurView = NSVisualEffectView()
blurView.material = .popover
blurView.blendingMode = .behindWindow
```

**iOS Widget:**
- No transparency (widgets on solid backgrounds in Standby)
- Background adapts to system appearance
- Uses `ContainerBackground` for automatic adaptation

---

## Spacing & Layout

### Grid System: 8pt Base

Hold follows Apple's 8pt grid system for all spacing and dimensions.

**Spacing Scale:**

| Token | Value | Usage |
|-------|-------|-------|
| `xxs` | 4pt | Minimal internal padding |
| `xs` | 8pt | Tight spacing |
| `s` | 16pt | Standard spacing |
| `m` | 24pt | Comfortable spacing |
| `l` | 32pt | Generous spacing |
| `xl` | 48pt | Section separation |
| `xxl` | 64pt | Major divisions |

### Layout Principles

**1. Generous Whitespace**
- Minimum 24pt padding around primary content
- Never crowd content to fill space
- Empty space is a design element, not wasted space

**2. Optical Centering**
- Text visually centered (not mathematically)
- Account for descenders and cap height
- Test at actual display size

**3. Content-First Sizing**
- Elements sized for content, not arbitrary dimensions
- Text determines container size, not vice versa
- Avoid fixed heights when possible

### Component Dimensions

**Mac Quick Entry Overlay:**
```
Width: 640pt
Height: 200pt (minimum, expands with content)
Corner Radius: 12pt
Shadow: None (blur effect provides depth)
Padding: 32pt all sides
```

**Mac Text Field:**
```
Width: 576pt (640 - 64pt padding)
Height: 60pt
Internal Padding: 16pt horizontal, 18pt vertical
Border: 1pt solid (Separator color)
Corner Radius: 8pt
```

**iPhone Widget (Standby - Medium):**
```
Size: 364 × 382pt (system defined)
Content Area: 324 × 342pt (20pt padding)
Task Text Area: Full width, vertically centered
Timer Position: Below task text, 16pt gap
```

### Responsive Behavior

**Mac Overlay:**
- Fixed width (640pt)
- Height adjusts to content (min 200pt)
- Positioned center of active screen
- Maintains size across different displays

**iPhone Widget:**
- System-defined widget sizes (3 variants)
- We use **Medium** size (optimized for Standby)
- Content scales proportionally with widget size
- Text size remains readable at all sizes

---

## Component Specifications

### Mac Quick Entry Overlay

**Visual Structure:**
```
┌──────────────────────────────────────────┐
│                                          │  ← 32pt padding
│   [Current Task Text if exists]         │  ← 18pt Regular
│                                          │  ← 16pt gap
│   ┌──────────────────────────────────┐  │
│   │ [Text Input Field]               │  │  ← 18pt Regular
│   └──────────────────────────────────┘  │
│                                          │  ← 32pt padding
└──────────────────────────────────────────┘
```

**States:**

1. **Default (No Task Set):**
   - Placeholder: "What are you holding?"
   - Secondary text color
   - Italic style

2. **Existing Task:**
   - Current task displayed above input
   - Regular weight, primary color
   - Input field contains existing text (editable)

3. **Typing:**
   - Placeholder disappears
   - Border becomes more prominent (increase contrast)
   - Cursor visible, blinking standard rate

4. **Focus:**
   - Subtle border color change to accent
   - No dramatic visual changes
   - Shadow remains unchanged

**Backdrop:**
```
Blur: 40pt radius
Opacity: 40% black overlay
Click Outside: Dismisses overlay
ESC Key: Dismisses overlay
```

### iPhone Widget (Standby Mode)

**Layout Variants:**

**With Task Active:**
```
┌─────────────────────────────────┐
│                                 │  ← 20pt padding
│  Currently:                     │  ← 16pt Caption
│                                 │  ← 8pt gap
│  Writing proposal document      │  ← 26pt Medium
│  for Q4 planning review         │  ← (wrapped if needed)
│                                 │  ← 16pt gap
│  23:45                          │  ← 32pt Semibold
│                                 │  ← 20pt padding
└─────────────────────────────────┘
```

**No Task Active:**
```
┌─────────────────────────────────┐
│                                 │
│                                 │
│        No active task           │  ← 26pt Medium, centered
│                                 │
│                                 │
└─────────────────────────────────┘
```

**Technical Specs:**
```swift
struct HoldWidget: Widget {
    let kind: String = "HoldWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            HoldWidgetView(entry: entry)
        }
        .configurationDisplayName("Hold")
        .description("Your current task at a glance")
        .supportedFamilies([.systemMedium])  // Only medium size
    }
}
```

**Content Layout:**
```swift
VStack(alignment: .leading, spacing: 16) {
    // Label
    Text("Currently:")
        .font(.caption)
        .foregroundColor(.secondary)
    
    // Task text
    Text(entry.taskText)
        .font(.system(size: 26, weight: .medium))
        .foregroundColor(.primary)
        .lineLimit(3)
        .truncationMode(.tail)
    
    // Timer
    Text(entry.timeRemaining)
        .font(.system(size: 32, weight: .semibold))
        .foregroundColor(.primary)
        .monospacedDigit()  // Prevents reflow during countdown
}
.padding(20)
.frame(maxWidth: .infinity, maxHeight: .infinity)
.background(Color(.systemBackground))
```

### Text Input Field (Mac)

**Specifications:**
```
Width: 576pt
Height: 60pt
Background: System background
Border: 1pt solid Separator
Corner Radius: 8pt
Padding: 16pt horizontal, 18pt vertical
Font: 18pt Regular
Text Color: Primary
Placeholder Color: Secondary
Cursor: System default (blinking)
Selection Color: System accent
```

**Focus States:**
```swift
TextField("What are you holding?", text: $taskText)
    .textFieldStyle(.plain)
    .font(.system(size: 18, weight: .regular))
    .foregroundColor(.primary)
    .padding(.horizontal, 16)
    .padding(.vertical, 18)
    .background(Color(.windowBackgroundColor))
    .cornerRadius(8)
    .overlay(
        RoundedRectangle(cornerRadius: 8)
            .stroke(isFocused ? Color.accentColor : Color.separator, lineWidth: 1)
    )
```

---

## Platform Implementation

### macOS Implementation

**Window Type:** NSPanel (floating window)

**Characteristics:**
- `worksWhenModal: true` (appears over other modals)
- `level: .floating` (always on top)
- `styleMask: .nonactivatingPanel` (doesn't take focus from other apps)
- `collectionBehavior: .canJoinAllSpaces` (visible on all virtual desktops)

**Position:**
```swift
// Center on screen with cursor
let mouseLocation = NSEvent.mouseLocation
let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
let screenRect = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero

let windowRect = CGRect(
    x: screenRect.midX - 320,  // Half of 640pt width
    y: screenRect.midY - 100,  // Half of 200pt height
    width: 640,
    height: 200
)
```

**Backdrop Implementation:**
```swift
// Background dimming view
let backdropView = NSView()
backdropView.wantsLayer = true
backdropView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor

// Blur effect
let blurView = NSVisualEffectView()
blurView.material = .popover
blurView.blendingMode = .behindWindow
blurView.state = .active
```

**Keyboard Handling:**
```swift
// Global hotkey registration (requires Accessibility permission)
import Carbon

let hotKeyCenter = HotKeyCenter.shared
hotKeyCenter.registerHotKey(
    keyCode: 17,  // 'T' key
    modifierFlags: [.command, .shift]
) {
    // Show overlay
    self.showQuickEntry()
}
```

### iOS Widget Implementation

**Widget Configuration:**
```swift
@main
struct HoldWidgets: WidgetBundle {
    var body: some Widget {
        HoldWidget()
    }
}

struct HoldWidget: Widget {
    let kind: String = "HoldWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            HoldWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Hold")
        .description("Your current task at a glance")
        .supportedFamilies([.systemMedium])
    }
}
```

**Timeline Provider:**
```swift
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(date: Date(), taskText: "Writing proposal", timeRemaining: "25:00")
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> ()) {
        // Fetch current task from CloudKit
        let entry = TaskEntry(date: Date(), taskText: currentTask, timeRemaining: timeLeft)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Provide timeline with 15-minute refresh policy
        // iOS will refresh more frequently if user is looking at widget
    }
}
```

**Widget View:**
```swift
struct HoldWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        if entry.taskText.isEmpty {
            // Empty state
            VStack {
                Text("No active task")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(20)
        } else {
            // Active task
            VStack(alignment: .leading, spacing: 16) {
                Text("Currently:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(entry.taskText)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .truncationMode(.tail)
                
                Text(entry.timeRemaining)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.primary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(20)
        }
    }
}
```

---

## Animation & Motion

### Philosophy: Subtle and Purposeful

Hold uses minimal animation, following Apple's principle: "Animation should enhance the user experience, not define it."

### Animation Specifications

**Mac Overlay - Appear:**
```
Duration: 200ms
Easing: Ease out (cubic-bezier(0.0, 0.0, 0.2, 1.0))
Effect: Fade in + slight scale (0.95 → 1.0)
Backdrop: Fade in simultaneously
```

**Mac Overlay - Dismiss:**
```
Duration: 150ms
Easing: Ease in (cubic-bezier(0.4, 0.0, 1.0, 1.0))
Effect: Fade out + slight scale (1.0 → 0.95)
Backdrop: Fade out simultaneously
```

**Implementation (SwiftUI):**
```swift
.scaleEffect(isVisible ? 1.0 : 0.95)
.opacity(isVisible ? 1.0 : 0.0)
.animation(.easeOut(duration: 0.2), value: isVisible)
```

**Text Field Focus:**
```
Duration: 100ms
Easing: Linear
Effect: Border color change only
```

**Widget Updates:**
```
Duration: None
Effect: Instant update (no animation)
Rationale: Animations in widgets consume battery and distract
```

### Respecting User Preferences

**Reduce Motion:**
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

.animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isVisible)
```

When Reduce Motion is enabled:
- Overlay appears/dismisses instantly (no scale effect)
- Fade animations shortened to 50ms
- No parallax or complex motion

---

## Dark Mode

### Automatic Adaptation

Hold fully supports system appearance modes with **automatic color adaptation**—no manual dark mode toggle needed.

### Color Mapping

| Element | Light Mode | Dark Mode |
|---------|------------|-----------|
| **Background** | `#FAFAFA` | `#1C1C1E` |
| **Text Primary** | `#1A1A1A` | `#EBEBEB` |
| **Text Secondary** | `#8E8E93` | `#98989D` |
| **Borders** | `#DEDEDE` | `#404040` |
| **Blur Material** | `.popover` | `.popover` (adapts) |

**Implementation:**
```swift
// SwiftUI automatically adapts
.foregroundColor(.primary)  // Black in light, white in dark
.background(Color(.systemBackground))  // Adapts automatically

// Manual adaptation if needed
@Environment(\.colorScheme) var colorScheme

var backgroundColor: Color {
    colorScheme == .dark ? Color(#1C1C1E) : Color(#FAFAFA)
}
```

### Dark Mode Testing

**Test both modes during development:**
- Xcode: Environment Overrides → Appearance toggle
- Mac: System Preferences → Appearance
- iOS: Settings → Display & Brightness → Appearance

**Edge Cases to Test:**
- Contrast in both modes (use accessibility inspector)
- Blur effects (ensure readability in both)
- Border visibility (ensure separation maintained)
- Timer text (white on black vs. black on white)

---

## Assets & Resources

### Required Assets

**App Icon:**
- 1024×1024px PNG (App Store)
- Multiple sizes generated by Xcode (automatic)
- Alternative icon for dark mode (optional)

**Marketing Assets:**
- App Store screenshots (varies by device)
- Preview video (optional, 15-30 seconds)

### No Additional Assets

Hold requires **no custom images, illustrations, or graphics**:
- No custom icons (use SF Symbols if needed)
- No background images
- No decorative elements
- Interface is 100% code and system components

### SF Symbols (If Needed)

If status indicators needed:

| Symbol | Usage | Color |
|--------|-------|-------|
| `icloud` | Sync status | System blue |
| `icloud.slash` | Sync failed | System red (rare) |
| `checkmark.circle` | Completed (if timer feature added) | System green |

**Implementation:**
```swift
Image(systemName: "icloud")
    .foregroundColor(.blue)
    .imageScale(.small)
```

### Font Resources

**No custom fonts required**—SF Pro is system-provided.

**Developer Access:**
- Download SF Pro from: https://developer.apple.com/fonts/
- Only needed for design mockups in Figma/Sketch
- Runtime uses system font automatically

---

## Design Tools & Workflow

### Recommended Tools

**Design:**
- Figma (with SF Pro installed locally)
- Sketch (native Apple design tool)
- Apple Design Resources templates

**Development:**
- Xcode 15+ (macOS)
- Xcode 16+ (required for iOS 18 features)
- SwiftUI for all interfaces

### Design Handoff

**From Designer to Developer:**

1. Figma file includes:
   - All screens and states
   - Spacing annotations (8pt grid)
   - Text style specifications
   - Color tokens with semantic names

2. Specifications include:
   - Component dimensions (in pt, not px)
   - Animation timing (duration, easing)
   - State variations (default, focus, empty)

3. Developer references:
   - This UI.md document (source of truth)
   - UX.md for interaction patterns
   - Apple HIG for platform standards

**From Developer to Designer:**
- Implemented screens for design QA
- Dark mode screenshots
- Different text size testing
- Edge case handling verification

---

## Implementation Checklist

### macOS App

- [ ] Overlay window (NSPanel) with proper z-level
- [ ] Blur background effect (NSVisualEffectView)
- [ ] Text field with proper focus management
- [ ] Global hotkey registration (Accessibility permission)
- [ ] Menu bar icon (NSStatusItem)
- [ ] Preferences window (Settings bundle)
- [ ] CloudKit integration (save task)
- [ ] Dark mode support (automatic)
- [ ] VoiceOver labels (accessibility)
- [ ] Reduce Motion support

### iOS Widget

- [ ] Widget extension project
- [ ] Timeline provider (CloudKit fetch)
- [ ] Widget view layout (Standby optimized)
- [ ] Text truncation handling (3 lines max)
- [ ] Timer display with monospaced digits
- [ ] Empty state view
- [ ] Dark mode support (automatic)
- [ ] Dynamic Type support
- [ ] Background refresh configuration
- [ ] Widget preview provider

### Testing

- [ ] Multiple screen sizes (Mac: 13", 15", external 4K)
- [ ] Both appearance modes (light/dark)
- [ ] Dynamic Type sizes (7 steps)
- [ ] Accessibility features (VoiceOver, Increase Contrast)
- [ ] Reduce Motion preference
- [ ] CloudKit sync (online/offline)
- [ ] Widget refresh timing
- [ ] Battery impact testing

---

## Code Standards

### SwiftUI Conventions

**Naming:**
```swift
// Views: PascalCase with "View" suffix
struct QuickEntryView: View { }

// View Models: PascalCase with "ViewModel" suffix
class TaskViewModel: ObservableObject { }

// Constants: camelCase
let overlayWidth: CGFloat = 640
let overlayPadding: CGFloat = 32
```

**Spacing Values:**
```swift
// Define in constants file
struct Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 16
    static let m: CGFloat = 24
    static let l: CGFloat = 32
    static let xl: CGFloat = 48
    static let xxl: CGFloat = 64
}

// Usage
.padding(Spacing.m)
```

**Colors:**
```swift
// Use system colors
.foregroundColor(.primary)  // NOT Color(#1A1A1A)
.background(Color(.systemBackground))  // NOT Color(#FAFAFA)

// Only define custom colors if absolutely necessary
extension Color {
    static let holdAccent = Color(red: 0.36, green: 0.49, blue: 0.60)
}
```

### AppKit Conventions (macOS)

```swift
// Window configuration
panel.styleMask = [.titled, .closable, .nonactivatingPanel]
panel.level = .floating
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

// Colors
let backgroundColor = NSColor.windowBackgroundColor
let textColor = NSColor.labelColor
let secondaryTextColor = NSColor.secondaryLabelColor
```

---

## Performance Guidelines

### Rendering Performance

**Mac Overlay:**
- Target: 60fps during animation
- Avoid: Heavy shadows, complex gradients
- Use: Native blur effects (hardware accelerated)

**iOS Widget:**
- Target: Instant rendering (<100ms)
- Avoid: Complex layouts, multiple image assets
- Use: Simple views, system colors, text-only

### Memory Management

**Mac App:**
- Overlay should allocate <5MB
- No image caching (no images to cache)
- Release overlay view when dismissed

**iOS Widget:**
- Widget extension limit: ~30MB
- Hold target: <2MB
- Minimal CloudKit cache (single record)

### Battery Optimization

**iOS Widget:**
- Avoid frequent updates (15-minute minimum refresh)
- Use background refresh efficiently
- No continuous timers in widget (use TimerWidget timeline)
- Estimated impact: <1% battery per day

---

## Conclusion

Hold's UI is defined by its adherence to Apple's platform conventions and minimalist design principles. The interface should feel:

- **Native:** Indistinguishable from Apple-designed apps
- **Minimal:** Only essential elements, generous whitespace
- **Clear:** Purpose immediately evident, no visual clutter
- **Respectful:** Adapts to user preferences and accessibility needs

**Implementation Philosophy:**
- When in doubt, use system defaults
- Respect platform conventions over custom design
- Test with real users at real distances (especially widgets)
- Simplify rather than embellish

**For Developers:**
This document is the source of truth for all visual specifications. When conflicts arise between design files and this document, this document takes precedence. When specifications are unclear, reference Apple's HIG and favor native system behavior.
