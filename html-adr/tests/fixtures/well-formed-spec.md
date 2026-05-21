---
adr:
  status: accepted
  drivers: [d1, d2]
---

# Well-formed test ADR

## Context

We need to decide between three approaches for a thing.

## Considered options

### Approach A — fast (Recommended)

Use the fast option.

**Pros:**
- quick
- simple

**Cons:**
- limited

### Approach B — flexible

The flexible option.

### Approach C — heavy

The heavy option.

## Consequences

### Positive
- ships sooner

### Negative
- harder later

## Affected Files

- src/fast.js — new
- src/old.js — deleted

## Data Flow

- input
- parse
- output

## Edge Cases

- empty input
  - handle gracefully
- malformed input
  - fail loud

## Dependencies & Risks

- lodash@4.17.21
- node:fs

## Rollback Path

1. Revert the merge commit
2. Re-deploy

## Testing

### Unit
- test fast path
- test edge case
