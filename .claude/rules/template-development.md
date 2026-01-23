# Template Development Rules

## The Cardinal Rule

**copier.yaml variables are user-facing prompts.** Every variable you add will be shown to developers creating new projects. If they would say "why are you asking me this?", it doesn't belong there.

## Separation of Concerns

| Belongs in copier.yaml | Does NOT belong in copier.yaml |
|------------------------|--------------------------------|
| Project name, description | Test fixtures |
| Feature flags (logging, config, etc.) | CI/CD configuration for the template |
| License, author info | Development tool settings |
| Preset selection | Grafana/monitoring credentials |
| Things every generated project needs | Things only template maintainers need |

## Before Modifying copier.yaml

1. **Ask:** "Is this something a user generating a project needs to configure?"
2. **Ask:** "Would this prompt make sense to someone who's never seen this template?"
3. **Ask:** "Does this follow the existing variable naming pattern?"
4. If any answer is "no" or "I'm not sure" → **stop and discuss with the user**

## Structural Changes Require Discussion

These changes are **never** okay to make unilaterally:

- Moving copier.yaml (it lives at repo root, period)
- Splitting config files
- Changing the template/ directory structure
- Adding new top-level directories
- Renaming existing variables
- Changing how presets work

## Testing Infrastructure

Template testing lives in `scripts/`, not in the template itself.

- Test data files: `scripts/*.yml`
- Test runner: `scripts/test-template.sh`
- Test output: `target/template-tests/`

If you need to test OTEL, Grafana, or other integrations, the test harness goes in `scripts/` and uses environment variables or test data files. It does NOT become a copier.yaml variable.

## The "Would This Surprise Someone" Test

Before completing any change, ask: "If the user reviewed this PR without context, would anything make them say 'why did you do it this way?'"

If yes → discuss before proceeding.
