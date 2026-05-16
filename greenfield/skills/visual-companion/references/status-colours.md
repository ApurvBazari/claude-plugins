# Phase status colours

Mirrors `greenfield/scripts/visual-companion-assets/styles.css`. Change both in lockstep.

| Status      | Colour     | Hex       | Meaning                                                              |
|-------------|------------|-----------|----------------------------------------------------------------------|
| APPROVED    | green      | `#3fb950` | synthesis-review approved this phase; click opens the ADR doc.       |
| IN_PROGRESS | amber      | `#d29922` | currently being asked about in the CLI.                              |
| AVAILABLE   | blue       | `#58a6ff` | all prerequisites approved; click to start it.                       |
| LOCKED      | grey       | `#6e7681` | prerequisites unmet; hover shows the blocking phase.                 |
| PARKED      | purple     | `#bc8cff` | flagged via Phase 1.5 Park escape; resumable.                        |
| HIDDEN      | dark grey  | `#30363d` | pruned by Step 0 answers; not rendered on the map.                   |

## Accessibility

- Contrast ratio against `#0f1419` background is >= 4.5:1 for APPROVED, IN_PROGRESS, AVAILABLE, PARKED text.
- Status is also encoded as text in the card-status badge, not colour alone.
- LOCKED state additionally reduces opacity to 0.5 so colour-blind users get a non-colour signal.

## Modifying the palette

When polishing via `frontend-design`, keep the semantic mapping (status to meaning) stable. The skill's logic does not depend on colour; it depends on the `status` enum value passed via `/state.json`.
