---
paths: ["**/*.rb", "**/*.rake", "**/Gemfile"]
---

# Comments

A comment exists to explain a **why** when the code itself cannot — never a **how**, and never a restatement of what the code already says. This bar governs all prose, from inline comments to docstrings.

- **Internal and private code** — everything in an application, plus a library's non-exported internals — is self-documenting via clear names and strong types. A comment survives only when it explains something a competent reader cannot recover from the code alone: a non-local constraint, an external-system quirk, a deliberate non-obvious tradeoff. A description of _what_ the code does, or a why that's evident from reading it, gets cut.
- **A published library's public surface** gets one verb-first sentence per exported symbol ("Serializes the definition to JSON."). An optional second sentence is reserved strictly for a why — a non-obvious constraint or rationale — never a second sentence of how. Needing more than one sentence to say _what_ it does is a smell the symbol does too much.
- **Types are not prose's job.** Parameters, return values, and field types live in the type system (TypeScript types, rbs-inline `#:` annotations) — never restated in comments that duplicate them.
- **Markers.** `TODO` / `FIXME` / `HACK` are tracked work and stay; `NOTE` / `REVIEW` meet the same why-bar as any other comment.
- **No history.** A comment describes the present, never how the code got there — no "was X, now Y", no story of the bug that revealed a constraint. State a still-true constraint in the present tense ("the API returns null for empty results — guard").
