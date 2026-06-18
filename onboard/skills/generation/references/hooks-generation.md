<!-- Extracted from ../SKILL.md via progressive-disclosure. Content is verbatim emission spec / templates. -->

# Hooks Generation (.claude/settings.json)

#### Quality-Gate Hooks (from `effectiveQualityGates`)

When `effectiveQualityGates` is present (from either `callerExtras.qualityGates` in programmatic mode or `detectedPlugins.qualityGates` in standalone mode with detected plugins), generate boundary-enforcement hooks that reinforce the CLAUDE.md Plugin Integration discipline. Four hook categories are supported, each driven by a field on the `qualityGates` object:

| Field | Event | Default mode | What it does |
|---|---|---|---|
| `sessionStart` | `SessionStart` | `advisory` | Emit a ≤ 3-line reminder at session start pointing to brainstorming + root CLAUDE.md § Plugin Integration |
| `preCommit` | `Stop` / `PreToolUse:Bash(git commit*)` | `blocking` | Run `code-review` / `verification-before-completion` before any commit lands; fail hard if issues found |
| `featureStart` | `PreToolUse:Write` | `advisory` | Non-blocking reminder when Claude creates a new file in a `criticalDirs` path (see O7) |
| `postFeature` | `Stop` / session-end | `advisory` | Nudge toward `claude-md-management:revise-claude-md` at phase end |

**Mode semantics**:
- `mode: "blocking"` → generated hook script exits **2** with stderr feedback. Claude sees the block as a tool error and cannot complete the action without addressing it.
- `mode: "advisory"` → generated hook script exits **0** with stdout. Claude sees the message in-transcript but continues.

**Defaults by field**: `preCommit` → `blocking`; everything else → `advisory`.

**autonomyLevel downgrade**: When the mapped `autonomyLevel` is "always-ask" (exploratory equivalent), downgrade all `preCommit[].mode` values to `advisory`. Standard/autonomous retain blocking. This downgrade is mechanical — no heuristics.

**Plugin availability check**: Before generating a hook entry for a `preCommit` / `postFeature` skill reference, verify the referenced plugin is actually in `effectivePlugins`. If missing, skip that hook entry silently and append a warning to `onboard-meta.json` under `warnings[]`. Never fail the generation.

**Merge semantics**: All quality-gate hooks merge into `.claude/settings.json` following the existing merge strategy (see `hooks-guide.md` § Settings Merge Strategy). If a hook with the same matcher/event already exists, skip don't duplicate.

**Hook Status Telemetry**: While walking through the 4 hook categories (`sessionStart`, `preCommit`, `featureStart`, `postFeature`), onboard MUST record what was planned, what was actually generated, and what was skipped (and why) into a structured `hookStatus` object. This object is:

1. Returned from `/onboard:generate` in the result summary (see `../../generate/SKILL.md` § Step 5)
2. Recorded inside `.claude/onboard-meta.json` under the top-level `hookStatus` key

This telemetry enables `/onboard:check` to report "X/Y hooks wired" and lays the foundation for future adaptive behaviors (e.g. suppress SessionStart reminder after the user dismissed it N times).

**Scope boundary** (load-bearing — read this carefully): `hookStatus` tracks **only** hooks derived from `callerExtras.qualityGates`. Pre-existing format/lint hooks (Prettier, ESLint, Black, rustfmt, etc.), evolution-internal hooks, and any other non-Plugin-Integration hooks are **out of scope** for this telemetry. They still get written to `.claude/settings.json` via the normal merge path, but they do **not** appear in `hookStatus.planned` or `hookStatus.generated`. This keeps Plugin Integration Coverage reporting clean — `/onboard:check` should never show a confusing "wired 2 hooks but planned 0" because format hooks inflated the count.

The mental model: `hookStatus` answers "how well did the Plugin Integration contract land?", not "how many shell hooks does this project have total?".

**Scope extension — advanced event hooks**: hooks emitted from the Advanced Event Hooks section (SessionEnd, UserPromptSubmit, PreCompact, SubagentStart, TaskCreated, TaskCompleted, FileChanged, ConfigChange, Elicitation) ARE counted in `hookStatus`. They are part of the Plugin Integration contract when the caller requested them via `callerExtras.qualityGates.<event>[]` OR when the wizard's `advancedHookEvents` opt-in selected them. When the inference rules fire them implicitly (see per-event triggers), they are also tracked — the scope boundary is "did a caller or wizard answer ask for this?" not "did the user type a yes". Format/lint hooks and utility hooks (WorktreeCreate init-runner) remain out of scope.

**Canonical `hookStatus` shape** (the source of truth — all downstream consumers use this exact layout):

**Key format**: `<Event>[:<Matcher>][:<Type>]` where:
- `<Event>` is the Claude Code event name (e.g., `SessionStart`, `TaskCompleted`).
- `<Matcher>` is the event's matcher value (tool name, filename glob, MCP server, etc.). Omitted for matcher-incompatible events.
- `<Type>` is the hook type (`prompt`, `agent`, or `http`). **Omitted entirely when type is `command`** — this keeps every pre-upgrade fixture byte-identical.
- When matcher is absent but type is present, the double colon is preserved: `Elicitation::http`. This is intentional — it signals "no matcher, but non-default type" unambiguously.

```jsonc
"hookStatus": {
  "planned": {
    "SessionStart":              1,  // command, no matcher, no type suffix
    "PreToolUse:Write":          1,  // command, matcher present
    "PreToolUse:Bash":           2,  // command, matcher present, 2 entries
    "Stop":                      1,  // command
    "SessionEnd":                1,  // command
    "PreCompact:auto":           1,  // command, matcher present
    "FileChanged:package-lock.json|Cargo.lock": 1,  // command with glob matcher
    // Non-command types surface the :<Type> suffix:
    "UserPromptSubmit:prompt":   1,  // prompt type, no matcher
    "TaskCompleted:agent":       1,  // agent type, no matcher
    "Elicitation::http":         1   // http type, no matcher (double colon preserves position)
    // With both matcher AND non-command type:
    // "Elicitation:vercel:http": 1
  },
  "generated": {
    // Value type varies by hook type — see § Artifact per type:
    //   command → script basename     (.claude/hooks/<name>.sh)
    //   prompt  → prompt filename     (.claude/hooks/<name>.prompt.md) OR inline-snippet fallback (first 50 chars + '…')
    //   agent   → agent name
    //   http    → URL
    "SessionStart":     ["plugin-integration-reminder.sh"],
    "PreToolUse:Write": ["feature-start-detector.sh"],
    "PreToolUse:Bash":  [
      "pre-commit-code-review.sh",
      "pre-commit-verification-before-completion.sh"
    ],
    "Stop":             ["post-feature-revise-claude-md.sh"],
    "SessionEnd":       ["session-end.sh"],
    "PreCompact:auto":  ["pre-compact-checkpoint.sh"],
    "FileChanged:package-lock.json|Cargo.lock": ["file-changed-notice.sh"],
    "UserPromptSubmit:prompt":   ["user-prompt-secret-scan.prompt.md"],
    "TaskCompleted:agent":       ["code-reviewer"],
    "Elicitation::http":         ["https://audit.internal/claude-elicitation"]
  },
  "skipped": [                       // one entry per hook that was planned but NOT generated
    {
      "event": "Stop",               // matches a key in planned{} (including any :Type suffix)
      "skill": "claude-md-management:revise-claude-md",
      "reason": "plugin-not-installed"
    },
    {
      "event": "Elicitation::http",
      "reason": "http-not-opted-in"  // callerExtras.allowHttpHooks was not true
    }
  ],
  "warnings": [                      // free-text warnings emitted during hook generation
    "featureStart.criticalDirs was empty; detector hook not generated",
    "Elicitation:http entry dropped — set callerExtras.allowHttpHooks: true to enable"
  ],
  "downgradeApplied": {              // OPTIONAL — only present when autonomyLevel forced a mode change
    "rule": "autonomyLevel=always-ask → preCommit[].mode=advisory",
    "affectedEntries": ["code-review:code-review", "superpowers:verification-before-completion"]
  }
}
```

**Counting rules**:
- `planned[key]` = **integer** — number of entries in `callerExtras.qualityGates.<field>[]` that map to that exact `<Event>[:<Matcher>][:<Type>]` key. Entries sharing an event but differing in type count as separate keys (e.g., `TaskCompleted` and `TaskCompleted:agent` are distinct). **Only counts qualityGates-derived hooks, never format/lint/evolution-internal.**
- `generated[key]` = **array** of artifact references for hooks actually written to `.claude/settings.json` from the qualityGates spec. Value semantics depend on type (see § Artifact per type under Advanced Event Hooks).
- `skipped[]` = a record for every entry in `planned` that did NOT produce a corresponding `generated` entry. The `event` field must match a `planned` key verbatim (including type suffix). Reasons include `plugin-not-installed`, `condition-unsatisfied`, `empty-critical-dirs`, plus the 11 type-validation reasons listed in § Hook Type Validation.
- `warnings[]` = operator-facing messages (not user-facing) about soft issues during generation.
- `downgradeApplied` (optional) = records the autonomyLevel-aware preCommit mode downgrade rule when it fires. Only present when the downgrade actually ran — absent means no downgrade was applied. Gives downstream tooling (status reports, adaptive suppression) provenance without re-deriving.
- **Invariant**: for every event key, `planned[key] - len(generated[key]) == (number of skipped[] entries whose `event` matches that key exactly)`. If this doesn't balance, the telemetry is broken — treat as a generation bug.
- **Backward compat**: for pre-upgrade callers (no `hookType` fields, no `allowHttpHooks`), every key in `planned` / `generated` has NO type suffix — the shape is byte-identical to pre-upgrade fixtures. Type suffixes only appear when a caller/wizard explicitly used a non-command type.

See `hooks-guide.md` for generated script templates, ShellCheck requirements, and concrete examples of sessionStart + featureStart + preCommit hooks.

#### O6 — SessionStart reminder hook

When `qualityGates.sessionStart` is non-empty AND at least one entry's `condition` resolves to `true` (e.g., `"superpowers-installed"` + superpowers is in `installedPlugins`), generate:

1. A ShellCheck-clean script at `<project>/.claude/hooks/plugin-integration-reminder.sh`:

   ```bash
   #!/usr/bin/env bash
   set -u  # no -e / -o pipefail — see "Shell options for hook scripts" below

   # Generated by onboard — plugin integration session-start reminder
   # Advisory only. Always exits 0.
   # Adaptive: suppresses to 1-line pointer after 5 fires without brainstorming.

   counter_file=".claude/session-state/plugin-integration-reminder-count"
   state_dir=".claude/session-state"

   # Ensure state directory exists
   mkdir -p "$state_dir"

   # Read current counter (0 if file missing)
   count=0
   if [ -f "$counter_file" ]; then
     count=$(cat "$counter_file" 2>/dev/null || echo 0)
     # Reset if brainstorming happened since last reminder
     if find "$state_dir" -maxdepth 1 -name 'brainstormed-*' -newer "$counter_file" -print -quit 2>/dev/null | grep -q .; then
       count=0
     fi
   fi

   # Emit reminder (full or abbreviated)
   if [ "$count" -lt 5 ]; then
     echo "Session reminder: Starting new feature work? Begin with /superpowers:brainstorming."
     echo "See root CLAUDE.md § Plugin Integration for the full workflow."
   else
     echo "See CLAUDE.md § Plugin Integration."
   fi

   # Increment and persist counter
   count=$((count + 1))
   echo "$count" > "$counter_file"
   exit 0
   ```

2. A SessionStart entry in `<project>/.claude/settings.json`:

   ```jsonc
   {
     "hooks": {
       "SessionStart": [
         {
           "hooks": [
             { "type": "command", "command": ".claude/hooks/plugin-integration-reminder.sh", "timeout": 5000 }
           ]
         }
       ]
     }
   }
   ```

**Reminder text composition**: concatenate all qualifying `sessionStart[].message` values, then truncate to ≤ 3 lines total (one greeting + one brainstorming cue + one pointer to CLAUDE.md). Never emit more than 3 lines regardless of how many entries exist (EC11). The abbreviated (suppressed) form emits exactly 1 line.

**Adaptive suppression**: the generated script tracks how many consecutive sessions the reminder has fired without the user running brainstorming. After 5 fires, it switches to a 1-line pointer (`"See CLAUDE.md § Plugin Integration."`) to reduce noise. The counter resets to 0 when a `brainstormed-*` marker file newer than the counter file is detected in `.claude/session-state/`, meaning brainstorming happened since the last reminder. This prevents fatigue while keeping the nudge alive for users who do follow it.

- **Counter file**: `.claude/session-state/plugin-integration-reminder-count` — a single integer
- **Threshold**: 5 (hardcoded — sessions 1-5 get the full reminder, session 6+ gets the abbreviated form)
- **Reset trigger**: any `brainstormed-$SESSION_ID` marker file newer than the counter file

**Skip conditions**:
- No qualifying entries → do not write the script or the settings.json entry.
- `superpowers` not installed → the default "superpowers-installed" condition fails; the entry is dropped.

**Script requirements**:
- `#!/usr/bin/env bash` + `set -u` (NOT `set -euo pipefail` — see "Shell options for hook scripts" in O7 for why)
- `shellcheck -x` must pass
- Keep under 25 lines total (excluding comments) — adaptive suppression logic requires more lines than the original static reminder
- Reference pattern: `.claude/hooks/post-edit.sh` in the repo root

#### O7 — Feature-start detector PreToolUse hook

When `qualityGates.featureStart` is non-empty AND `criticalDirs` is non-empty, generate a ShellCheck-clean script at `<project>/.claude/hooks/feature-start-detector.sh` and a matching PreToolUse:Write entry in `<project>/.claude/settings.json`.

##### Required behavioral invariants (MUST all be implemented)

The generated `feature-start-detector.sh` **MUST** satisfy every single invariant below. These are load-bearing for correctness — they are **not** suggestions, and they are **not** optional optimizations. **Do not simplify or omit them "for readability"**. If the reference implementation below feels long, the right answer is to keep it long, not to cut checks.

A generated detector script that is missing any of invariants 1-8 is a **bug** and must be regenerated.

1. **MUST parse `tool_name` and `tool_input.file_path` from stdin JSON** (PreToolUse payload contract). A `CLAUDE_TOOL_INPUT_FILE_PATH` env-var fallback is acceptable and encouraged for harness portability, but stdin parsing must work standalone. Use jq-preferred + sed/grep fallback so jq is not a hard dependency.
2. **MUST `exit 0` immediately if `tool_name != "Write"`.** This is a Write-only detector. Firing on Edit, Bash, or other tools would be a false positive.
3. **MUST `exit 0` immediately if the target file already exists on disk.** An existing file means this is an edit-in-place, not a feature-start. The hook must only fire when a genuinely new file is being created.
4. **MUST `exit 0` immediately if the target path matches any of these generated/tool-managed path patterns**:
   - `**/build/**`
   - `**/generated/**`
   - `**/.git/**`
   - `**/node_modules/**`
   - `**/.next/**`
   - `**/dist/**`
   - `**/target/**`
   - `**/.gradle/**`
   - `**/__pycache__/**`

   These paths are populated by build tools, package managers, or VCS, and can fire dozens or hundreds of times during a normal build cycle. Letting the hook fire on them would flood the transcript with meaningless reminders. This is **EC10 from the Plugin Integration spec** and is mandatory. Implement this as a `case` statement early in the script — before the critical-dir match — so the cost of the check is paid only for Write calls that aren't already filtered out.
5. **MUST `exit 0` immediately if the session marker `.claude/session-state/brainstormed-${CLAUDE_SESSION_ID}` exists.** Brainstorming has already fired in this session, so the reminder would be redundant and annoying. This is **EC8 from the Plugin Integration spec** and is mandatory.
   - If `CLAUDE_SESSION_ID` is unset, use the literal string `unknown` as the suffix. The resulting marker path `brainstormed-unknown` is unlikely to exist, so the hook fires conservatively. This false-positive cost is preferable to silently missing a reminder because the env var wasn't propagated.
   - **Do not skip this check** just because the session-state directory might not exist on first run — a missing directory means a missing marker, which correctly triggers the "hook fires" path.
6. **MUST match the target path against the critical-dir regex** constructed from `qualityGates.featureStart[].criticalDirs`. If no critical dir matches, `exit 0`. See "Regex construction" below for how to build the regex.
7. **MUST emit the reminder on stderr** (`>&2`, not stdout). Claude Code surfaces hook stderr in the transcript as a first-class signal, while stdout is appended less prominently. The reminder text must reference `/superpowers:brainstorming` and (when available) a relevant feature-dev skill.
8. **MUST `exit 0` after emitting the reminder.** This hook is **always advisory**, **never blocking**. **Never `exit 2`** from this script under any circumstance. Blocking a Write on a new file would make the hook unusable in practice and force users to bypass all hooks.

##### Reference implementation

Use this as the starting point. The `critical_regex` value and the reminder text are the only two things that should be customized per-project — everything else (all 8 invariants) must remain.

```bash
#!/usr/bin/env bash
set -u  # no -e / -o pipefail — see "Shell options for hook scripts" below

# Generated by onboard — feature-start detector
# Advisory only. Always exits 0. Non-blocking.
# Invariants: see ../SKILL.md § O7.

# Invariant 1 — parse stdin JSON with env var fallback
payload=""
if [ ! -t 0 ]; then
  payload="$(cat || true)"
fi

tool_name="${CLAUDE_TOOL_INPUT_TOOL_NAME:-}"
if [ -z "$tool_name" ] && [ -n "$payload" ]; then
  tool_name=$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null || \
              printf '%s' "$payload" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
fi

# Invariant 2 — Write-only
[ "$tool_name" != "Write" ] && exit 0

file_path="${CLAUDE_TOOL_INPUT_FILE_PATH:-}"
if [ -z "$file_path" ] && [ -n "$payload" ]; then
  file_path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null || \
              printf '%s' "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
fi
[ -z "$file_path" ] && exit 0

# Invariant 3 — new files only
[ -e "$file_path" ] && exit 0

# Invariant 4 — skip generated / build / tool-managed paths (EC10)
case "$file_path" in
  */build/*|*/generated/*|*/.git/*|*/node_modules/*|*/.next/*|*/dist/*|*/target/*|*/.gradle/*|*/__pycache__/*)
    exit 0
    ;;
esac

# Invariant 5 — skip if brainstorming already fired in this session (EC8)
marker=".claude/session-state/brainstormed-${CLAUDE_SESSION_ID:-unknown}"
[ -f "$marker" ] && exit 0

# Invariant 6 — match critical-dir regex (customize per-project from featureStart.criticalDirs)
critical_regex='(domain/parser/|ui/compose/|data/db/)'
if ! printf '%s' "$file_path" | grep -Eq "$critical_regex"; then
  exit 0
fi

# Invariants 7 + 8 — emit reminder to stderr, then exit 0 advisory
{
  echo "[onboard] New file in a domain-critical directory: $file_path"
  echo "[onboard] Consider /superpowers:brainstorming and the relevant feature-dev skill first."
} >&2

# Worktree offer (addon — fires only when brainstorm reminder also fires)
# Not a new invariant — additive output after invariant 7+8 message.
# Only generated when enableHarness is true in the generation context.
wt_pref="ask"
if [ -f ".claude/session-state/worktree-preference" ]; then
  wt_pref=$(cat ".claude/session-state/worktree-preference" 2>/dev/null || echo "ask")
fi

# Skip worktree offer if preference is "never" or already in a worktree
in_worktree=false
case "$PWD" in */.claude/worktrees/*) in_worktree=true ;; esac

if [ "$wt_pref" != "never" ] && [ "$in_worktree" = "false" ]; then
  {
    echo "[onboard] Worktree isolation recommended. Follow CLAUDE.md § Worktree Workflow to create one."
    if [ "$wt_pref" = "ask" ]; then
      echo "[onboard] Save preference: echo 'always' > .claude/session-state/worktree-preference"
    fi
  } >&2
fi

exit 0
```

##### Worktree offer addon (conditional — `enableHarness` only)

The worktree offer block (lines after invariant 7+8 in the reference implementation above) is **only generated when `enableHarness` is true** in the generation context. Non-harness projects skip this block entirely — the script ends at `exit 0` after the brainstorm reminder.

This addon is **additive to invariants 7+8**, not a replacement. The 8 invariants remain untouched and mandatory. The worktree offer fires only when all 8 invariants have already passed (i.e., the brainstorm reminder was emitted).

**Preference file contract**:
- Path: `.claude/session-state/worktree-preference`
- Values: `always` (auto-create without asking), `never` (suppress offer), `ask` (prompt each time — default if file missing)
- Written by Claude after the developer responds to the first offer, or manually via `echo "always" > .claude/session-state/worktree-preference`
- The hook only reads this file — it never writes it

**In-worktree detection**: `case "$PWD" in */.claude/worktrees/*)` detects if the session is already inside a Claude Code worktree. Claude Code stores worktrees at `.claude/worktrees/<name>/`, so this pattern is reliable. If already in a worktree, the offer is suppressed (Claude Code refuses nested worktrees anyway).

**Feature-list.json name lookup**: The hook does NOT parse `docs/feature-list.json` — that complexity belongs in the CLAUDE.md instructions, not in a shell script. The hook emits a generic "follow CLAUDE.md § Worktree Workflow" message. Claude reads the CLAUDE.md section, looks up the feature ID from `docs/feature-list.json` if it exists, constructs the name (e.g., `F001-user-dashboard`), and calls `EnterWorktree(name: "...")`.

##### PreToolUse entry in settings.json

```jsonc
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/feature-start-detector.sh", "timeout": 5000 }
        ]
      }
    ]
  }
}
```

Use `${CLAUDE_PROJECT_DIR}/.claude/hooks/...` (not bare `.claude/hooks/...`) so the hook is cwd-independent.

##### Regex construction

Escape each `criticalDirs` entry with regex-safe quoting, join with `|`, wrap in `()`.

Example: `["domain/parser/", "ui/compose/"]` → `(domain/parser/|ui/compose/)`

For paths containing regex metacharacters (unlikely in practice but possible), escape them before joining. The reference implementation uses POSIX-extended regex via `grep -Eq`.

##### Skip conditions (generator-level, not runtime)

These apply at generation time — if they're true, do not write the script or the settings.json entry at all:

- No `featureStart` entries in `qualityGates`
- `featureStart[].criticalDirs` is empty across all entries
- Plugin-availability check fails for a referenced skill → record in `hookStatus.skipped[]` (see B3 telemetry spec) and continue without generating

##### Script requirements

- `#!/usr/bin/env bash` + `set -u` (NOT `set -euo pipefail` — see "Shell options for hook scripts" below). This matches `.claude/rules/shell-scripts.md`, which already says hook scripts must not use `set -e`.
- `shellcheck -x` must pass cleanly — zero warnings, zero errors
- Never `exit 2` — this hook is always advisory. Exit code other than 0 is a bug.
- Reference patterns: `.claude/hooks/validate-bash.sh` for stdin JSON parsing, `.claude/hooks/post-edit.sh` for the advisory exit pattern

##### Shell options for hook scripts (load-bearing)

Use `set -u` alone, **not** `set -euo pipefail`. Here's why this matters:

Hook scripts use the `cat 2>/dev/null || true` pattern to drain stdin when no payload is present (harness-invoked case, or when invoked interactively with no piped input). Under `set -e`:

- If the stdin source is a closed pipe, bash can exit with SIGPIPE (exit code 141) — the hook appears to "fail" even though the drain is intentional
- Any `grep` / `sed` pipeline that returns no matches (exit 1) would abort the whole script

Under `set -o pipefail`:

- Pipe failures inside conditional logic get promoted to script failures, breaking the jq-preferred + grep/sed fallback pattern (when jq succeeds but its stdout is empty, the next stage in the pipe sees nothing and reports a failure that pipefail surfaces as the script's exit code)

Using `set -u` alone:

- Still catches undefined-variable bugs (the actual safety we want)
- Leaves error handling to explicit checks inline (`[ -z "$var" ] && exit 0`)
- Works correctly with the stdin-drain and jq-fallback patterns the hooks rely on

**Rule**: hook scripts use `set -u`. Utility scripts (`scripts/*.sh`, `install*.sh`, analysis/detection tooling) use `set -euo pipefail`. This distinction is documented in `.claude/rules/shell-scripts.md` and is authoritative — this spec section only restates it for the generation-time audience.

#### Standalone Quality-Gate Hooks (when no plugins detected)

When `effectiveQualityGates` is NOT present AND `effectivePlugins` is empty — meaning no plugins were found either from a caller or from self-detection — derive default quality-gate hooks from the `selectedPreset` (profile) and `autonomyLevel` wizard answers. These hooks are simpler than their plugin-aware counterparts: they reference project rules from `.claude/rules/` and CLAUDE.md conventions rather than plugin skills.

##### Profile determines WHICH hooks

| Profile | SessionStart | preCommit | featureStart | postFeature |
|---------|-------------|-----------|--------------|-------------|
| minimal | — | — | — | — |
| standard | Yes | — | — | — |
| comprehensive | Yes | Yes | Yes | Yes |
| custom | Follow comprehensive if autonomyLevel ≠ "always-ask"; follow standard otherwise |

##### autonomyLevel determines MODE

| autonomyLevel | SessionStart | preCommit | featureStart | postFeature |
|---------------|-------------|-----------|--------------|-------------|
| always-ask | advisory | advisory | advisory | advisory |
| balanced | advisory | **blocking** | advisory | advisory |
| autonomous | advisory | **blocking** | **blocking** | advisory |

##### Standalone hook content (no plugin references)

These hooks reference project conventions rather than installed plugins:

- **SessionStart reminder**: Echo a 1-2 line reminder: "Review CLAUDE.md conventions and .claude/rules/ for path-specific guidance before starting work." No adaptive suppression counter — keep the script simple. Always `exit 0`.
- **preCommit hook**: Run the project's test command discovered during analysis (from CLAUDE.md § Build Commands → testing). Attach to `PreToolUse:Bash(git commit*)`. In blocking mode, exit 2 with stderr feedback if the test command fails. If no test command was detected during analysis, skip preCommit generation entirely and record in `hookStatus.skipped[]` with reason `"no-test-command-detected"`.
- **featureStart reminder**: Advisory when Claude creates a new file via `PreToolUse:Write` in a critical directory. Derive `criticalDirs` from the analysis report's identified architectural boundaries (top-level source directories). Use the same stdin-parsing and new-files-only pattern from O7 but without plugin or brainstorming references. Message: "Starting a new file in a key directory. Review CLAUDE.md and .claude/rules/ for conventions in this area."
- **postFeature nudge**: Attach to `Stop` event. Message: "Consider reviewing CLAUDE.md and .claude/rules/ to capture any new conventions from this work." Always advisory, always `exit 0`.

##### Standalone script conventions

Standalone hooks follow the same shell conventions as programmatic hooks:
- `#!/usr/bin/env bash` + `set -u` (not `set -euo pipefail` — see Shell Options section above)
- ShellCheck-clean (`shellcheck -x`)
- Advisory hooks always `exit 0`, blocking hooks `exit 2` with stderr on failure
- No plugin availability checks needed — no plugins are referenced
- No adaptive suppression (SessionStart) — always show the reminder
- No brainstorming or worktree concepts — those are plugin-specific

##### hookStatus telemetry for standalone hooks

Record standalone quality-gate hooks in `onboard-meta.json` under the same `hookStatus` key used by programmatic hooks. The shape is identical — `planned`, `generated`, `skipped`, `warnings`. The `skipped[].reason` for profile-excluded hooks is `"profile-excluded"`.

##### Merge behavior

Same as programmatic mode: read existing `.claude/settings.json` first, merge hook entries, never overwrite. If a hook with the same matcher/event already exists, skip (don't duplicate). Standalone quality-gate hooks coexist with format/lint hooks from the Autonomy Cascade — they use different events/matchers and do not conflict.

#### Advanced Event Hooks (from `qualityGates.<advanced-event>` or wizard opt-in)

In addition to the four core quality-gate categories (sessionStart / preCommit / featureStart / postFeature), onboard emits hooks for nine advanced Claude Code events when the caller requests them or the wizard's advanced-hook step selects them. All templates live in `hooks-guide.md` § Advanced Event Templates — this section covers the generation contract only.

##### Input sources (in priority order)

1. **Caller-provided**: `callerExtras.qualityGates.<event>[]` where `<event>` is one of `sessionEnd`, `userPromptSubmit`, `preCompact`, `subagentStart`, `taskCreated`, `taskCompleted`, `fileChanged`, `configChange`, `elicitation`. See `../../generate/SKILL.md` § Required Context Structure for the per-field shape.
2. **Wizard opt-in**: `wizardAnswers.advancedHookEvents[]` — array of event names the developer selected in the wizard's optional advanced-hooks step. Maps 1:1 to the caller schema keys (lowercase first letter, e.g., `sessionEnd`, not `SessionEnd`).
3. **Inference**: when neither source is present, apply the per-event inference rules below. Inference runs last and never overrides an explicit empty selection.

##### Per-event inference rules

| Event | Inference trigger | Template script (in `hooks-guide.md`) |
|---|---|---|
| `SessionEnd` | Always emit (safe cleanup stub) | `session-end.sh` |
| `UserPromptSubmit` | `wizardAnswers.securitySensitivity === "high"` OR `hookify` in `effectivePlugins` | `user-prompt-preflight.sh` |
| `PreCompact` | `wizardAnswers.autonomyLevel ∈ {balanced, autonomous}` AND `analysis.complexity.fileCount > 500` — matcher `"auto"` | `pre-compact-checkpoint.sh` |
| `SubagentStart` | `enriched.enableTeams === true` | `subagent-start-audit.sh` |
| `TaskCreated` | `enriched.enableTeams === true` | `task-created-check.sh` |
| `TaskCompleted` | `enriched.enableTeams === true` AND analyzer detected a test command — replace the `__TEST_CMD__` placeholder in the template with the literal command (e.g. `npm test`, `pytest -q`). Skip this hook entirely if no test command was detected. | `task-completed-verify.sh` |
| `FileChanged` | `enriched.enableEvolution === true` — use the drift-detection matcher set from `evolution-hooks-guide.md`; fall back to the generic lockfile matcher when the caller supplies no explicit matcher | `file-changed-notice.sh` or the drift scripts from evolution-hooks-guide |
| `ConfigChange` | Analyzer detected `.claude/settings.json` OR `.claude/rules/` under git version control (`versionControlledClaude === true`) — matcher `"project_settings"` | `config-change-warn.sh` |
| `Elicitation` | `.mcp.json` present in the repo OR analyzer reports MCP servers in the stack — omit matcher unless caller names specific servers | `elicitation-audit.sh` |

##### Per-event defaults (hook type)

When neither the caller's `qualityGates.<event>[].hookType` nor `wizardAnswers.advancedHookTypes[<event>]` is set, generation applies these per-event defaults. The third column shows the inference-path upgrade — when the listed condition fires, the default type is upgraded from `command` to the listed alternative (still overridable by the caller/wizard).

| Event | Default type | Inference-path upgrade (auto-fires when silent) |
|---|---|---|
| `SessionStart` | `command` | — |
| `SessionEnd` | `command` | — |
| `UserPromptSubmit` | `command` | → `prompt` (using shipped `default-prompts/user-prompt-secret-scan.md`) when `wizardAnswers.securitySensitivity === "high"` |
| `PreToolUse` / `PostToolUse` | `command` (**locked** — `prompt`/`agent` refused with `unsupported-type-for-event`) | none |
| `Stop` | `command` | — |
| `PreCompact` | `command` | — |
| `SubagentStart` | `command` | — |
| `TaskCreated` | `command` | — (wizard offers `prompt` as manual upgrade only) |
| `TaskCompleted` | `command` | → `agent` when `enriched.enableTeams === true` AND caller supplies `qualityGates.taskCompleted[].agentRef` |
| `FileChanged` | `command` | — |
| `ConfigChange` | `command` | — |
| `Elicitation` | `command` | → `http` when caller supplies `qualityGates.elicitation[].httpUrl` AND `callerExtras.allowHttpHooks === true` |

**Inference-path safety invariants**:
- `UserPromptSubmit` → `prompt` never fires if the wizard/caller explicitly set `hookType: "command"` for that event. Explicit beats inferred.
- `TaskCompleted` → `agent` requires BOTH `enableTeams` AND an `agentRef`. Missing the ref → stay on `command` (never guess which agent to use).
- `Elicitation` → `http` requires BOTH `httpUrl` AND `allowHttpHooks`. Missing either → stay on `command`.
- No `http` path is ever emitted purely from analyzer signals — always requires explicit caller consent (`allowHttpHooks: true`).

##### Hook Type Validation

Each entry passes through this 11-rule validator before the settings.json write. Failures drop the offending entry into `hookStatus.skipped[]` with a structured reason and continue generation. They never abort the run.

| Skip reason | Condition | Remediation hint recorded in `warnings[]` |
|---|---|---|
| `missing-prompt-source` | `hookType="prompt"` but neither `promptRef` nor `promptInline` supplied | "Provide `promptRef` (path) or `promptInline` (text) for prompt-type hooks" |
| `ambiguous-prompt-source` | `hookType="prompt"` with BOTH `promptRef` AND `promptInline` | "Pick exactly one of `promptRef` / `promptInline`" |
| `prompt-file-not-found` | `hookType="prompt"` + `promptRef` points to a file that does not exist | "Create the prompt file at the supplied path or switch to `promptInline`" |
| `missing-agentRef` | `hookType="agent"` but `agentRef` is absent or empty | "Provide `agentRef` naming the agent (e.g. `code-reviewer`)" |
| `missing-httpUrl` | `hookType="http"` but `httpUrl` is absent or empty | "Provide `httpUrl` (https-only)" |
| `unsupported-type-for-event` | `hookType ∈ {prompt, agent}` on `PreToolUse` or `PostToolUse` | "Use `command` type for per-tool-call events" |
| `http-not-opted-in` | `hookType="http"` without `callerExtras.allowHttpHooks === true` | "Set `callerExtras.allowHttpHooks: true` to enable http-type hooks" |
| `insecure-http-url` | `hookType="http"` with URL not starting with `https://` | "Use https; non-https URLs are refused even for loopback" |
| `agent-not-found` | `hookType="agent"` + `agentRef` referencing an agent whose plugin is not in `effectivePlugins` | "Install the agent's plugin or switch to a `command` hook" |
| `invalid-timeout` | `timeout` field present but not a positive integer | "Timeout must be a positive integer in milliseconds" |
| `high-frequency-event-unsuitable-for-agent` | `hookType="agent"` on `UserPromptSubmit` (fires on every prompt; agent latency makes the session unusable) | "Use `prompt` type instead, or keep `command` for low-latency checks" |

**Invariant**: every `skipped[]` entry counts against the event's `planned[eventKey]` in the same way existing skips do. The `planned − len(generated) == count(skipped)` invariant still balances per key.

##### Artifact per type

| Type | `generated[<key>]` array value | Physical file | Plugin-level source of truth |
|---|---|---|---|
| `command` | script basename (e.g., `session-end.sh`) | `${project}/.claude/hooks/<name>.sh` | template in `hooks-guide.md` |
| `prompt` | prompt filename (e.g., `user-prompt-secret-scan.prompt.md`) | `${project}/.claude/hooks/<name>.prompt.md` (copied verbatim from `promptRef` file OR written from `promptInline` text if >1 line) | optional default in `references/default-prompts/` |
| `agent` | agent name (e.g., `code-reviewer`) | no new file — references existing agent via `type: "agent"` settings entry | `effectivePlugins` provides the agent |
| `http` | URL (e.g., `https://audit.internal/e`) | no new file — URL lives inline in `settings.json` | caller-supplied |

**`promptInline` special case**: if `promptInline` is 1 line AND ≤200 chars, embed directly in `settings.json` `prompt` field (no sidecar file). Otherwise always write a `.prompt.md` sidecar and reference it via file-read at generation time. `generated[<key>]` records the sidecar filename when present; else the inline text's first 50 chars followed by `…`.

##### Generation rules

1. **Matcher-incompatible events MUST NOT emit a `matcher` field** in the settings entry. Applies to: `SessionEnd`, `UserPromptSubmit`, `SubagentStart`, `TaskCompleted`. See `hooks-guide.md` § Matcher Compatibility for the authoritative table. Silently ignoring an extraneous matcher is not acceptable — the generated JSON must be honest.
2. **Matcher-capable events MUST scope narrowly**. `PreCompact` defaults to `"auto"` (manual compactions stay quiet). `FileChanged` must specify a filename glob — omitting the matcher means "watch every file" and produces avoidable noise. `ConfigChange` defaults to `"project_settings"`. `Elicitation` omits the matcher only when the caller explicitly intends to audit every MCP server.
3. **All advanced events are advisory by default** — the generated scripts always `exit 0`. The caller may upgrade `taskCreated` / `taskCompleted` to `mode: "blocking"` explicitly; all other events ignore `mode` (only advisory is supported because Claude Code does not honor `exit 2` on them).
4. **Script generation**: copy the corresponding template from `hooks-guide.md` § Advanced Event Templates into `<project>/.claude/hooks/<script-name>`, make executable (`chmod +x`), verify `shellcheck -x` passes. Do NOT re-author the templates inline — the guide is authoritative.
5. **Merge semantics**: same as quality-gate hooks — read existing `.claude/settings.json`, append the new hook entry under its event key, skip if a hook with the same matcher already exists. Never overwrite.
6. **hookStatus telemetry**: every advanced event hook that is planned, generated, or skipped MUST appear in `hookStatus` under the `<Event>[:<Matcher>][:<Type>]` key. The type suffix is **omitted when type is `command`** (backward compatible — existing fixtures are unchanged). Examples: `"PreCompact:auto"` (command, no suffix), `"UserPromptSubmit:prompt"` (no matcher → single colon before type), `"Elicitation::http"` (no matcher + non-command type → double colon preserves position), `"FileChanged:package-lock.json|Cargo.lock"` (command with matcher). The canonical-shape invariant — `planned[event] - len(generated[event]) == count(skipped where event matches)` — applies equally.
7. **Plugin availability**: when an advanced event's inference condition references an installed plugin (e.g., `hookify` for `UserPromptSubmit`), verify the plugin is in `effectivePlugins` before emitting. Missing → record in `hookStatus.skipped[]` with reason `plugin-not-installed`.
8. **Type selection**: apply the per-event default (§ Per-event defaults above) unless the caller/wizard explicitly sets `hookType`. Then run the 11-rule validator (§ Hook Type Validation). A rejected entry records `skipped[]` with the structured reason and NEVER falls back to `command` silently — the caller must see the rejection in telemetry.
9. **Prompt sidecar file**: when `hookType="prompt"` + `promptRef`, copy the source file to `${project}/.claude/hooks/<slug>.prompt.md`. When `hookType="prompt"` + `promptInline` >1 line OR >200 chars, write the inline text to the same sidecar path and reference it. When `promptInline` fits inline, embed directly in settings.json.
10. **Timeout**: if caller supplied `timeout`, use it (after positive-integer validation). Else apply the type default: command 5000, prompt 15000, agent 60000, http 5000 ms.

##### Wizard opt-in plumbing

When `wizardAnswers.advancedHookEvents` is present and non-empty, it takes priority over the inference rules for exactly the events it names. Events not in the array fall back to inference. An empty-but-present array (`[]`) means "user said no to all advanced events" — inference is suppressed entirely for that run (the one exception to rule 3 in Input sources above).

`wizardAnswers.advancedHookTypes` (optional) supplies per-event type selection from wizard Step 1. Only judgment-capable events (`userPromptSubmit`, `stop`, `taskCreated`, `taskCompleted`, `elicitation`) honor this field; other event keys are ignored silently. `wizardAnswers.advancedHookTypeExtras` supplies the auxiliary field (`agentRef`, `httpUrl`, `promptRef`, `promptInline`) required by the chosen type — same validator applies.

Mapping from wizard names (camelCase) to hookStatus keys (`Event[:Matcher][:Type]`, type suffix omitted for `command`):

| Wizard name | Default type | hookStatus key examples |
|---|---|---|
| `sessionEnd` | command | `SessionEnd` |
| `userPromptSubmit` | command (→ prompt on security-high) | `UserPromptSubmit`, `UserPromptSubmit:prompt` |
| `preCompact` | command | `PreCompact:auto` |
| `subagentStart` | command | `SubagentStart` |
| `taskCreated` | command | `TaskCreated`, `TaskCreated:prompt` (wizard upgrade), `TaskCreated:http` (wizard upgrade) |
| `taskCompleted` | command (→ agent on teams + agentRef) | `TaskCompleted`, `TaskCompleted:agent`, `TaskCompleted:prompt`, `TaskCompleted:http` |
| `fileChanged` | command | `FileChanged:<matcher>` (matcher derived from analyzer signals or defaulted to lockfiles) |
| `configChange` | command | `ConfigChange:project_settings` |
| `elicitation` | command (→ http on httpUrl + allowHttpHooks) | `Elicitation`, `Elicitation:<mcp-server>`, `Elicitation::http`, `Elicitation:<mcp>:http` |

##### Scope note

Advanced event hooks complement — they do not replace — the core four quality-gate categories. SessionStart (plugin integration reminder), preCommit (commit gating), featureStart (new-file detector), and postFeature (phase-end nudge) continue to fire under their existing rules. Advanced event hooks are additive.

#### Utility Hooks (non-telemetry)

Utility hooks are generated alongside quality-gate hooks but are **NOT** tracked in `hookStatus`. They serve infrastructure purposes. They follow the same shell conventions (`set -u`, `shellcheck -x`, always `exit 0`).

##### WorktreeCreate hook — init.sh auto-runner

When `enableHarness` is true in the generation context, generate a `WorktreeCreate` hook that runs `init.sh` when the developer enters a worktree via `EnterWorktree`.

**What to generate**: The script and settings.json entry from `hooks-guide.md` § WorktreeCreate hook (init.sh auto-runner).

**Why this is not in hookStatus**: `hookStatus` tracks only quality-gate hooks derived from `callerExtras.qualityGates` (see scope boundary above). The WorktreeCreate hook is infrastructure — it bootstraps development environments, not Plugin Integration discipline.

**Merge behavior**: Same as all hooks — merge into existing `.claude/settings.json`. If a `WorktreeCreate` hook already exists, skip (don't duplicate).
