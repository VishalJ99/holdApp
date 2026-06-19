# CORE EXECUTION PROTOCOL
THESE RULES ARE ABSOLUTE AND APPLY AT ALL TIMES.

## General

### 1. SYSTEM ARCHITECTURE DOCUMENTATION PROTOCOL
- **MANDATORY SYSTEM_ARCHITECTURE.MD MAINTENANCE**: The `.Codex/SYSTEM_ARCHITECTURE.md` file MUST be maintained and updated by EVERY agent working on the codebase.
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

### 2. POST-CHANGE LOCALIZED SURFACE REVIEW PROTOCOL
- **MANDATORY SUBAGENT REVIEW AFTER EVERY CHANGE**: After any code, configuration, project-governance, or documentation change, the top-level agent MUST spawn a review subagent before committing or claiming completion.
- **REVIEW PROMPT REQUIREMENTS**: The subagent prompt MUST include:
  - The user's stated goal for the change.
  - A concise summary of the implemented change.
  - The current diff scope or files touched.
  - An explicit request to check whether the change affected any unrelated or localized surface.
- **LOCALIZED SURFACE CHECK**: The review MUST verify that the diff stayed within the intended surface area. Examples include catching backend-only requests that accidentally modify frontend code, iOS-only requests that touch macOS behavior, release-documentation changes that alter runtime code, or selector UI changes that modify CloudKit sync.
- **REVIEW OUTPUT REQUIREMENTS**: The subagent MUST report either:
  - `Localized surface check: PASS`, with the surfaces reviewed; or
  - `Localized surface check: FAIL`, with file/line findings and why each touched surface appears unrelated to the goal.
- **ORCHESTRATOR DUTY**: The top-level agent MUST summarize the subagent result in chat or the ticket, address any valid findings before committing, and state the review outcome in the completion evidence.
- **EXCEPTION HANDLING**: If subagent tooling is unavailable, the top-level agent MUST perform the localized surface review manually, state that the required subagent was unavailable, and record that exception in the completion notes.

## Tool Usage

### Documentation Tools

**View Official Documentation** - 
`resolve-library-id` - Resolve library name to Context7 ID- `get-library-docs` - Get latest official documentation

**Search Real Code** - 
`searchGitHub` - Search actual use cases on GitHub 

## Hold App Store Release Notes

- Use `release_guide.md` as the high-level release playbook for local App Store landing-page preview, metadata validation, Xcode archive/upload, App Store Connect submission, and monitoring.
- For App Store archives/uploads, use Xcode 26 from `/Applications/Xcode.app` explicitly, for example `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild` or `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. The selected developer directory may point at an older Xcode in `~/Downloads`; that can build with an older iOS SDK and fail App Store Connect upload validation.
- For App Store review submission automation, do not create deprecated `appStoreVersionSubmissions`; App Store Connect now rejects that create call. Attach the processed build to the `appStoreVersion`, set build export compliance if needed, then use the current review submission flow: create or reuse `reviewSubmissions`, add the `appStoreVersion` through `reviewSubmissionItems`, and submit by patching the `reviewSubmission` with `submitted: true`.
