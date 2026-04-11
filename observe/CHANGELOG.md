# Changelog

## 0.2.0

- Add WIP notice to README clarifying that observe is still experimental
- Phase 2 cross-plugin wiring with onboard (unified tooling context)
- Phase 3 data-driven intelligence features — query + dashboard generation over collected telemetry

## 0.1.0

- Initial release — zero-infrastructure observability for Claude Code
- Hook-based telemetry collection (PreToolUse, PostToolUse, Stop, SubagentStart) via `collect.py`
- Passive analytics storage at `~/.claude/observability/` (JSONL append-only log)
- Commands: `/observe:status` (health check), `/observe:report` (summary stats),
  `/observe:pipeline` (query + visualize pipeline)
- Scripts: `collect.py` (hook ingestion), `query.py` (data extraction), `generate_dashboard.py`
  (HTML dashboard rendering), `install.sh` (one-shot setup)
- Observability analytics skill for passive usage tracking without affecting session performance
