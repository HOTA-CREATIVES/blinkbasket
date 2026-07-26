---
name: Code Review
description: Reviews the codebase for style consistency, clean architecture, performance optimizations, and best practices in Flutter/Dart.
---

# Code Review Skill Guidelines

This skill is designed to guide the review of Dart and Flutter code bases. When active, prioritize analyzing the following aspects of the codebase:

1. **Architecture & Separation of Concerns**:
   - Ensure clear boundary separations: `UI Layer` (screens/widgets) $\rightarrow$ `Provider/State Layer` $\rightarrow$ `Use Case/Domain Layer` $\rightarrow$ `Repository/Data Layer`.
   - Controllers/Providers should not invoke Firebase/Firestore directly. All data access must route through a defined repository interface.

2. **State Management (Provider)**:
   - Check that `notifyListeners()` is called judiciously.
   - Verify selectors (`context.select` or `Consumer`) are used where appropriate to prevent unnecessary rebuilds.

3. **Dart Best Practices**:
   - Eliminate unused imports and variables.
   - Validate proper constructor usage (prefer `const` constructors where possible).
   - Ensure proper use of `async`/`await` and avoid passing `BuildContext` across asynchronous gaps.

4. **Remediation Plan**:
   - For every issue found, provide a concrete recommendation and code snippet to fix it.
