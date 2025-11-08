# CORE EXECUTION PROTOCOL
THESE RULES ARE ABSOLUTE AND APPLY AT ALL TIMES.

## General

### 1. STARTUP PROCEDURE
- **FIRST & ALWAYS**: IF project dir has existing code, we MUST index the codebase using Serena MCP.
  `uvx --from git+https://github.com/oraios/serena index-project`

### 2. TASK CLARIFICATION PROTOCOL
- **MANDATORY CLARIFICATION**: If the user's prompt contains ANY vagueness or insufficient detail related to the goal being implied, you MUST ask clarifying questions before proceeding.

### 3. SYSTEM ARCHITECTURE DOCUMENTATION PROTOCOL
- **MANDATORY SYSTEM_ARCHITECTURE.MD MAINTENANCE**: The `.claude/SYSTEM_ARCHITECTURE.md` file MUST be maintained and updated by EVERY agent working on the codebase.
- **PURPOSE**: `SYSTEM_ARCHITECTURE.md` is the high-level map that agents use to understand:
  - **WHAT LIVES WHERE**: Clear mapping of all files, modules, and their locations in the project structure
  - **FILE RESPONSIBILITIES**: What each file is responsible for and what logic it contains
  - **KEY LOGIC FLOWS**: Core workflows broken down into key functions with their inputs and outputs
  - **SCRIPT LOCATIONS**: Where each script/component lives and how they interact
- **UPDATE FREQUENCY**: 
  - **IMMEDIATE**: Update `SYSTEM_ARCHITECTURE.md` whenever new files are created or removed
  - **AFTER LOGIC CHANGES**: Update whenever core logic in existing files is modified, especially:
    - Changes to function signatures (inputs/outputs)
    - Changes to data flow between components
    - Changes to component responsibilities
  - **BEFORE COMMITS**: Ensure `SYSTEM_ARCHITECTURE.md` is current before any commit
- **CONTENT REQUIREMENTS**: The document MUST accurately reflect:
  - Current file structure and target memberships
  - Component responsibilities and key logic locations
  - Data flow diagrams and synchronization patterns
  - Critical code paths with line number references
  - Technical decisions and their rationale
- **NO EXCEPTIONS**: This file is CRITICAL for maintaining agent productivity and MUST be kept current. It serves as the primary reference for understanding the codebase architecture.

## Tool Usage

### Documentation Tools

**View Official Documentation** - 
`resolve-library-id` - Resolve library name to Context7 ID- `get-library-docs` - Get latest official documentation

**Search Real Code** - 
`searchGitHub` - Search actual use cases on GitHub 
