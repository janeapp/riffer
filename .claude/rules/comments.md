---
paths: ["**/*.rb", "**/*.rake", "**/Gemfile"]
---

# Comments

A comment exists to explain a **why** when the code itself cannot — never a **how**, and never a restatement of what the code already says. This bar governs all prose, from inline comments to docstrings.

- **The default is no comment.** Names, types, and structure carry the meaning; when they don't, fix them rather than explain them. Delete the comment and read the code cold: if the intent is still recoverable, it stays deleted. Keep only a _why_ the code can't show — a non-local constraint, an external quirk, a deliberate tradeoff, a safety invariant — and put it at the line it explains, not in a header.

- **No history.** A comment describes the present, never how the code got there — no "was X, now Y", no story of the bug that revealed a constraint. State a still-true constraint in the present tense ("the API returns null for empty results — guard").
