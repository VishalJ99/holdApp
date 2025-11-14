# Sibling Creation: Potential Index Lag Issue

## Status
**Priority**: Low (issue masked by typical index lag behavior)
**Impact**: Potential off-by-one error in sibling count when CloudKit indexes quickly

## Problem Description

When creating child or sibling tasks, we calculate sibling position/count AFTER saving the new task to CloudKit. This introduces a dependency on CloudKit index lag behavior.

### Current Flow (Problematic)

```
1. User creates new sibling/child task
2. Save task to CloudKit
3. Query siblings (fetchSiblings) ← Can have index lag
4. Calculate: siblingCount = siblings.count + 1 ← Assumes lag
5. Save CurrentTaskPointer with calculated values
6. iPhone receives notification
```

### The Bug

**Scenario 1: With index lag (common, current behavior works)**
```
Query returns: [Sibling 1, Sibling 2] (new task missing)
siblingCount = 2 + 1 = 3 ✅ Correct
iPhone displays: "3/3"
```

**Scenario 2: Without index lag (rare, causes bug)**
```
Query returns: [Sibling 1, Sibling 2, Sibling 3] (new task included!)
siblingCount = 3 + 1 = 4 ❌ Wrong
iPhone displays: "3/4"
```

## Root Cause

The `+1` hack in sibling count calculation assumes index lag always occurs. Modern CloudKit may index quickly enough to include the newly created task in query results, causing an off-by-one error.

## Proposed Solution

**Reorder operations to query BEFORE saving:**

```
1. User creates new sibling/child task
2. Query siblings FIRST ← No index lag (new task not saved yet)
3. Calculate: siblingCount = siblings.count + 1 ← Always correct
4. Calculate: siblingPosition = siblingCount (new task goes last)
5. Save task to CloudKit
6. Save CurrentTaskPointer with calculated values
7. iPhone receives notification
```

### Why This Works

- Query returns existing siblings only (all properly indexed)
- +1 accounts for the task we're about to create
- No dependency on index lag timing
- Guaranteed correct count

## Code Locations to Modify

### 1. Child Creation (AppDelegate.swift:174-282)

**Current problematic code (lines 239-252):**
```swift
// Inside saveTask completion handler
dispatchGroup.enter()
CloudKitManager.shared.fetchSiblings(parentId: parent.id) { result in
    siblingCount = siblings.count + 1  // Assumes index lag
    siblingPosition = siblingCount
}
```

**Fix:** Move sibling fetch to BEFORE line 183 (`CloudKitManager.shared.saveTask` call)

### 2. Sibling Creation (AppDelegate.swift:285-427)

**Current problematic code (lines 372-396):**
```swift
// Inside saveTask completion handler
dispatchGroup.enter()
CloudKitManager.shared.fetchSiblings(parentId: parentId) { result in
    siblingCount = siblings.count + 1  // Assumes index lag
    if switchTo {
        siblingPosition = siblingCount
    } else {
        // Find current task position...
    }
}
```

**Fix:** Move sibling fetch to BEFORE line 293 (`CloudKitManager.shared.saveTask` call)

### Implementation Notes

1. Sibling fetch becomes a prerequisite before saving
2. Need to handle fetch errors gracefully (fall back to no sibling info?)
3. Both child and sibling creation flows need modification
4. Does NOT apply to root selection (different use case)

## Why We Haven't Seen This Bug Yet

1. **Index lag is common** when querying immediately after write
2. **iPhone uses pointer data** (even if wrong, it's consistent)
3. **Off-by-one errors** are subtle and easy to miss
4. **Root selection exposed it** (querying old data, no recent writes)

## Related Fixes

Root selection (AppDelegate.swift:642-759) had similar issues:
- Fixed in commit: [to be added]
- Used "smart check" pattern instead of blind +1
- Pattern: Check if task exists in list, add if missing, then count

## Next Steps

1. Decide if optimization is worth the refactor
2. Test with artificially fast CloudKit indexing
3. Consider hybrid approach: use smart check pattern (like root selection fix) instead of reordering operations
