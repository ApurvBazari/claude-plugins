# Visual Companion — Manual End-to-End Smoke

10-minute script to walk through before tagging 3.1.0. Run from an empty directory.

## Setup

```bash
mkdir /tmp/vc-smoke && cd /tmp/vc-smoke
```

## Run

1. Trigger `/greenfield:start`. Answer the 6 Step 0 questions:
   - App type: Web app
   - Scale: Team
   - Personas: "internal back-office users"
   - Deployment: Cloud
   - Team size: 2-5
   - Stack hint: "Next.js + Postgres"
2. The browser should open to `http://localhost:38271` (or another preferred port).
3. Verify:
   - Header shows project + "0 / 6 required phases approved".
   - 4 layer panels visible.
   - Architectural Framing and CI/CD Delivery are AVAILABLE (blue border).
   - Payments and i18n are HIDDEN (not rendered).
   - All other phases are LOCKED (greyed out, low opacity).
4. Click Architectural Framing.
5. Verify: toast appears: "Back to the CLI...". CLI shows the architecturalFraming Q-bank.
6. Answer all the Qs through synthesis-review approve.
7. Verify: browser auto-refreshes within 2-3s; Architectural Framing now shows APPROVED (green border) with a "/adr/architectural-framing" link.
8. Click Data Architecture (now AVAILABLE).
9. Complete its Q-bank.
10. Repeat for: API & Integration, Privacy, Security, CI/CD Delivery.
11. Verify: header now says "6 / 6 required phases approved".
12. Verify: greenfield enters Phase 1.7 grill-spec, then proceeds to scaffold normally.

## Negative cases

13. With server running, click an APPROVED phase. Verify: opens the synthesis HTML in a new tab.
14. Click a LOCKED phase. Verify: toast shows "Locked. Requires: <prereq>".
15. Restart Claude Code mid-Phase 1 (Ctrl-D). Re-run `/greenfield:pickup`. Verify: server respawns (likely on a different port), map is in the same state.
16. Set `GREENFIELD_VISUAL_COMPANION=0`. Restart `/greenfield:start` from scratch. Verify: companion is skipped, linear wizard takes over.

## Cleanup

```bash
cd ~ && rm -rf /tmp/vc-smoke
```

## Sign-off

Tester: ________________  Date: ________  3.1.0 ready: [ ] yes [ ] no — notes:
