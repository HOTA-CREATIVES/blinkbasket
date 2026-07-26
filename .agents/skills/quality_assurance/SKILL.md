---
name: Quality Assurance
description: Performs code quality checks, logic validation, exception handling checks, and security rule audits.
---

# Quality Assurance Skill Guidelines

This skill is designed to guide quality assurance and robustness testing of Dart and Flutter applications. When active, prioritize testing and verifying:

1. **Exception Handling**:
   - Verify that all repository network calls (Firebase, Cloud Functions, External REST APIs) are wrapped in `try-catch` blocks.
   - Check that failures return structured result models (e.g. `Result<T>` or `Either`) containing clear error messages instead of throwing uncaught exceptions.

2. **Null Safety & Validation**:
   - Ensure input form validations are active for user-facing data entries (e.g., pricing, phone numbers, passwords).
   - Check for risky force-unwrap operators (`!`) that could crash the application under null conditions.

3. **Security Audits**:
   - Verify Firestore rules and Storage security rules are locked down and do not allow wildcard writes.
   - Inspect Firebase Auth custom claims checks to ensure delivery/admin routes cannot be accessed by unauthorized customer tokens.

4. **Testing Coverage**:
   - Review existence of widget, unit, or integration tests in the `test/` directory.
