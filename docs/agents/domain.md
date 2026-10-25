# Domain docs

This project uses a single-context layout: `GLOSSARY.md` at the repository root and architecture decisions in `docs/adr/`.

## Before exploring

- Read `GLOSSARY.md` for the project's vocabulary.
- Read ADRs in `docs/adr/` relevant to the area being explored.
- If a referenced document is absent, proceed silently. Domain documents are created lazily by the `domain-modeling` skill as terms or decisions are resolved.

## Use the glossary's vocabulary

Use defined domain terms in issue titles, proposals, hypotheses, and tests. Respect the glossary's avoided synonyms.
If a needed term is missing, reconsider whether it belongs to the project or note a real vocabulary gap for `domain-modeling`.

## Flag ADR conflicts

Explicitly identify any existing ADR contradicted by a proposal and explain why the decision should be reopened.
