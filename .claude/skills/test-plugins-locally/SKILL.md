---
description: Set up, reset, or run a local testbed for the plugins in this repo. Use whenever you want to dogfood a plugin from this working copy (any branch) against a clean sibling sandbox project — covers marketplace registration, install/update, per-plugin smoke recipes.
user-invocable: true
---

# /test-plugins-locally — Local Plugin Testbed

Spin up (or reset) a sibling sandbox project, point Claude Code at this repo's plugins via the local marketplace, and run a smoke recipe for the plugin under test.

## What this skill does

The three plugins in this repo (`onboard`, `notify`, `handoff`) ship through the `apurvbazari-plugins` local marketplace which points at this directory. Plugins are **copied** into `~/.claude/plugins/cache/apurvbazari-plugins/<plugin>/<version>/` on install, so source edits don't reach the running session until the cache is refreshed.

**Gotcha**: `claude plugin update` is version-gated — it compares the `plugin.json` `version` field and is a **no-op when versions match** (which they almost always do during in-branch dev, since you rarely bump version per edit). The Reset step in this skill therefore mirrors source → cache via `rsync` directly. `claude plugin update` is still useful when you've actually bumped the version, but it cannot be relied on for live-edit dogfooding.

```
~/Desktop/projects/
├── claude-plugins/           ← THIS repo (plugin source)
└── claude-plugins-testbed/   ← sibling sandbox (created by this skill)
    └── <plugin>-test/        ← one fresh subdir per smoke recipe
```

## Guard

Run only from inside the `claude-plugins` repo root (the directory containing `.claude-plugin/marketplace.json`). If you can't see that file, stop and tell the user where they actually are — running this skill from anywhere else would silently set up the wrong testbed.

## Step 1: Ask what to do

Use `AskUserQuestion` (single-select) with these options:

- **Setup** — first-time wiring: register marketplace if missing, install all 3 plugins, create the sibling testbed dir
- **Reset (Recommended)** — mirror source → plugin cache via `rsync` (bypasses the version-gated `claude plugin update`), nuke the testbed contents, recreate empty subdirs
- **Run plugin recipe** — pick a plugin and walk its smoke recipe in a fresh sandbox subdir
- **Status** — read-only: report marketplace + plugin + testbed state, then stop

Dispatch on the answer to the matching step below.

## Step 2: Status (read-only)

Run these probes and report what you find — do not modify anything.

```bash
# Marketplace
claude plugin marketplace list 2>&1 | grep -A1 'apurvbazari-plugins' || echo "NOT REGISTERED"

# Installed plugins from this marketplace
claude plugin list 2>&1 | grep -B1 -A2 '@apurvbazari-plugins'

# Source branch + dirty state
git -C "$(pwd)" rev-parse --abbrev-ref HEAD
git -C "$(pwd)" status --short | head -10

# Testbed
TESTBED="$(cd .. && pwd)/claude-plugins-testbed"
if [ -d "$TESTBED" ]; then
  echo "Testbed: $TESTBED"
  ls "$TESTBED"
else
  echo "Testbed not yet created at $TESTBED"
fi

# Cache freshness — for each plugin compare source vs the version-pinned cache dir
# Layout: ~/.claude/plugins/cache/apurvbazari-plugins/<plugin>/<version>/...
for p in onboard notify handoff; do
  if [ ! -f "$p/.claude-plugin/plugin.json" ]; then continue; fi
  VER=$(grep -m1 '"version"' "$p/.claude-plugin/plugin.json" | sed -E 's/.*"version": *"([^"]+)".*/\1/')
  CACHE="$HOME/.claude/plugins/cache/apurvbazari-plugins/$p/$VER"
  if [ ! -d "$CACHE" ]; then
    echo "$p@$VER: cache missing — Reset needed"
    continue
  fi
  DRIFT=$(diff -rq "$p" "$CACHE" 2>&1 \
    | grep -v '\.orphaned_at\|\.bak-\|\.in_use\|CHANGELOG\|tests/' \
    | head -3)
  if [ -n "$DRIFT" ]; then
    echo "$p@$VER: cache STALE vs source —"
    echo "$DRIFT"
  else
    echo "$p@$VER: cache matches source"
  fi
done
```

Surface anything noteworthy: stale cache, orphan plugin entries (plugins installed from this marketplace that no longer exist in the source — suggest `claude plugin uninstall <name>@apurvbazari-plugins` if found), uncommitted source changes that won't be visible until reset.

## Step 3: Setup

Execute in order. Each command is idempotent — re-running is safe.

```bash
REPO_ROOT="$(pwd)"
TESTBED="$(cd .. && pwd)/claude-plugins-testbed"

# 1. Register the local marketplace if missing (--scope user makes it global)
if ! claude plugin marketplace list 2>&1 | grep -q 'apurvbazari-plugins'; then
  claude plugin marketplace add "$REPO_ROOT" --scope user
else
  echo "marketplace apurvbazari-plugins already registered"
fi

# 2. Install all 3 plugins (skip already-installed)
for p in onboard notify handoff; do
  if claude plugin list 2>&1 | grep -q "^  ❯ ${p}@apurvbazari-plugins"; then
    echo "$p already installed — skipping (use Reset to refresh)"
  else
    claude plugin install "${p}@apurvbazari-plugins"
  fi
done

# 3. Create sibling testbed
mkdir -p "$TESTBED"
echo "Testbed at: $TESTBED"
```

After install, tell the user: **a Claude Code restart is required for newly installed plugins to load** — surface this explicitly, don't assume they'll know.

## Step 4: Reset

Three actions: refresh cache from source, clean the sandbox, recreate the sandbox shell.

```bash
REPO_ROOT="$(pwd)"
TESTBED="$(cd .. && pwd)/claude-plugins-testbed"

# 1. Mirror source → cache via rsync.
#    Why not `claude plugin update`: it is version-gated, so when plugin.json
#    version hasn't bumped (typical during in-branch dev) it's a no-op and
#    your edits never reach the cache. rsync forces the cache to match source
#    byte-for-byte (minus VCS and ephemeral metadata).
for p in onboard notify handoff; do
  if [ ! -f "$p/.claude-plugin/plugin.json" ]; then continue; fi
  VER=$(grep -m1 '"version"' "$p/.claude-plugin/plugin.json" | sed -E 's/.*"version": *"([^"]+)".*/\1/')
  CACHE="$HOME/.claude/plugins/cache/apurvbazari-plugins/$p/$VER"
  if [ ! -d "$CACHE" ]; then
    echo "$p@$VER: cache missing — run Setup first"
    continue
  fi
  rsync -a --delete \
    --exclude='.git' --exclude='.orphaned_at' --exclude='tests/' \
    "$p/" "$CACHE/"
  echo "$p@$VER: synced source → cache"
done

# 2. Wipe the testbed (ask before rm -rf if anything is in it)
if [ -d "$TESTBED" ] && [ -n "$(ls -A "$TESTBED" 2>/dev/null)" ]; then
  echo "Testbed contains:"
  ls "$TESTBED"
  # Use AskUserQuestion to confirm deletion before proceeding
fi
rm -rf "$TESTBED"
mkdir -p "$TESTBED"
echo "Testbed reset: $TESTBED"
```

After rsync, verify zero drift with the Status step's `diff -rq` block — it should print "(empty = match)" for the plugin(s) you just synced.

Before `rm -rf`, confirm with `AskUserQuestion` if the testbed has contents — never delete without an explicit yes, per the executing-actions-with-care guidance.

Tell the user: **restart Claude Code so the updated plugin cache loads**. Without restart, the running session still has the pre-update copies in memory.

## Step 5: Per-plugin run recipes

Ask which plugin to smoke-test (single-select). Each recipe creates a fresh `<plugin>-test/` subdir inside the testbed so runs don't contaminate each other.

### onboard

Onboard targets an existing codebase, so the sandbox needs something to analyze. Two options — ask which:

- **Empty repo path** (tests stub-empty-repo mode): `cd "$SANDBOX" && git init && claude` → `/onboard:start`
- **Existing project path**: copy a small project (or `git clone <some-repo>`) into the sandbox, then `claude` + `/onboard:start`

Smoke checklist:
- Codebase analysis completes
- Wizard runs to end without crashing on a single-option `AskUserQuestion` (the known guard case)
- `.claude/`, `CLAUDE.md`, `.claude/forge-state.json` materialize

### notify

```bash
SANDBOX="$TESTBED/notify-test"
mkdir -p "$SANDBOX"
echo "cd $SANDBOX && claude"
echo "then run: /notify:setup, then test with: /notify:check"
```

Smoke checklist:
- `/notify:setup` walks the platform detection (terminal-notifier on macOS / notify-send on Linux)
- macOS: a test notification appears
- `.claude/settings.json` in the sandbox gets the hook entries
- `/notify:check` reports healthy

### handoff

```bash
SANDBOX="$TESTBED/handoff-test"
mkdir -p "$SANDBOX"
echo "cd $SANDBOX && claude"
```

Smoke flow:
1. In the sandbox session, do some work (touch a file or two)
2. Trigger `/handoff:save` — confirm via AskUserQuestion prompt
3. Exit the session, start a fresh one in the same dir
4. SessionStart should surface the handoff; the pickup skill should auto-route
5. Confirm `.claude/handoff.md` exists between save and pickup

## Notes on the live-edit loop

This is the friction the skill exists to manage:

1. Edit plugin source in this repo
2. Run `/test-plugins-locally` → Reset (rsyncs source → cache, bypassing the version-gated `claude plugin update`)
3. **Restart Claude Code** (mandatory — running session has cached the pre-sync copy)
4. `cd <sandbox> && claude` and invoke the plugin
5. Iterate

Markdown-only edits (skill content, prompts) require the same sync + restart cycle — the cache is a literal copy, not a symlink.

## Anti-patterns

- **Don't `cd` into the testbed from this session.** This Claude session is anchored to the plugin source. To test a plugin you need a *new* Claude session whose working directory is the sandbox.
- **Don't rely on `claude plugin update` alone for live-edit dev.** It is version-gated; if `plugin.json.version` is unchanged it's a no-op and your edits never reach the cache. Reset uses `rsync` to bypass this.
- **Don't skip the cache sync.** Without it, you'll be testing the previously-installed version while believing you're testing your branch. Verify zero drift via the Status step's `diff -rq` block after a sync.
- **Don't delete the testbed without confirming.** If a previous test left useful state, the user wants a chance to inspect it first.
- **Don't try to install plugins by symlinking** into `~/.claude/plugins/cache/`. The marketplace flow is canonical and the symlink will be silently overwritten on the next `claude plugin update` or reinstall.

## Key rules

- Skill MUST run from the `claude-plugins` repo root — guard on `.claude-plugin/marketplace.json`.
- Setup is idempotent; re-running never destroys state.
- Reset is the only destructive path and MUST confirm before `rm -rf` on a non-empty testbed.
- Every recipe instructs the user to `cd` + run `claude` in a fresh shell — never inline-execute the plugin from this session.
- After install or update, surface the **restart Claude Code** requirement explicitly.
