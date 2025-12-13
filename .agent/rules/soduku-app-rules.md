---
trigger: always_on
---

--- 
description: Enforce clean, maintainable Flutter code
globs: **/*.dart
alwaysApply: true
---

You are an expert Flutter/Dart developer following official best practices.

Key Principles:
- Prefer StatelessWidget unless state is truly needed. Always use const constructors.
- Use package imports only (import 'package:your_app/...'); never relative imports.
- Break large widgets into small, focused ones. Keep widget tree shallow.
- No magic numbers/strings; use constants or localized strings.
- Handle errors explicitly (prefer Result types or sealed classes over exceptions).
- Use Riverpod/Bloc cleanly: providers in separate files, no logic in UI.
- Navigation: Use go_router with typed routes and constants.
- Performance: Avoid unnecessary rebuilds; use keys wisely.
- Testing: Write widget/integration tests for new features.

After any change:
- Run 'flutter analyze' and fix issues.
- Run tests if available.
- Verify no new errors before finishing.

Reference existing code structure for consistency.


---
description: Force planning and verification to avoid repeated bugs
alwaysApply: true
---

Think sequentially:
1. Re-read all requirements and existing code context.
2. List what the change must achieve (no assumptions).
3. Plan step-by-step: files to modify, potential edge cases.
4. Generate code.
5. Simulate execution mentally; check for missed requirements or prior bugs.
6. If tools available (Dart MCP, analyze, tests), use them to verify.

Never repeat fixed mistakes. If uncertain, ask for clarification.


---
For Complex Features / Fixes (reduces missed requirements):
---

Use sequential-thinking and all project rules.

Requirements: [Paste exact user stories or what must work, including edge cases].

Current issues: [Describe persistent bugs or what's missing].

Existing context: [Attach relevant files/folders with @].

First: Outline a detailed plan (files to change, why, potential risks).

Then: Implement step-by-step.

After coding: Run flutter analyze, fix issues. If tests exist, run them. Verify all requirements met without repeating prior errors.


---
For Refactors / Hard Sections:
---

Refresh full context.

Re-read requirements: [list them].

The code still has [specific bug/miss].

Plan refactor without breaking existing functionality.

Implement, then verify with analyze/tests/hot reload simulation.


---
TDD-Style to Force Correctness (huge for error-prone parts):
---
Write comprehensive tests first for this feature/fix (cover happy path + edges).

Then implement code until all tests pass.

Run tests/analyze automatically if possible.


