# Project Planning Rules

## Plan Storage Location

**ALWAYS** store project plans in `[PROJECT ROOT]/.claude/plans/`, **NOT** `~/.claude/plans`

- Create the directory if it doesn't exist
- Prefer descriptive filenames: `feature-authentication.md`, `refactor-db-layer.md`
- One plan per file
- Include date in frontmatter or filename for chronological tracking

## Capture Architectural Decisions

- Utilize the [`capturing-decisions`](../skills/capturing-decisions/SKILL.md) AgentSkill when appropriate.

## Timeline Structure

Break down timelines as:

```
Phase → Step → Substep (if needed)
```

**NOT** as estimated human weeks/sprints. We're measuring work in logical units, not calendar time.

## Example
```markdown
### Phase 1: Database Layer
* Step 1: Schema design
  - Substep: Draft migrations
  - Substep: Review constraints
* Step 2: Repository pattern implementation
```

Keep it actionable, not inspirational.

## Why This Matters

Keeps plans version-controlled, discoverable, and separated from working files. Future you (and Claude) will appreciate the organization.

## Quick Start
```bash
mkdir -p .claude/plans
touch .claude/plans/current-work.md
```

That's it. Now go build something cool. 🚀
