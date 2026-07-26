---
name: Catalog Management
description: Enforces validations, formats, and conventions for adding, editing, and listing catalog items.
---

# Catalog Management Skill

This skill is active when reviewing catalog management workflows.

1. **Input Validations**:
   - Product name should be non-empty and limited to logical character lengths (e.g. max 100 characters).
   - Prices must be strictly positive (> 0.0). Zero or negative values must be rejected.
   - Categories must belong to a predefined set of active taxonomy categories.

2. **Asset Integrity**:
   - Image assets must utilize secure Firebase Storage paths or valid HTTPS URL formats.
   - Fallback placeholders must be provided for items lacking custom images.

3. **Metadata Fields**:
   - Product documents must contain `createdAt`, `updatedAt`, and `adminId` fields to track additions and modifications.
