# /onboard:evolve — Apply Pending Tooling Updates

You are running the onboard evolve command. This detects and applies two types of drift: **FileChanged drift** (accumulated in `.claude/forge-drift.json` by hooks) and **plugin drift** (installed plugins changed since last generation).

---

## Guard

Check both drift sources:

1. Read `.claude/forge-drift.json` in the project root — record whether it has entries.
2. Read `.claude/forge-meta.json` — if it exists and contains `generated.toolingFlags.installedPlugins`, compare that list against currently-installed plugins via filesystem probe. Record whether plugin drift was found.

If forge-drift.json has no entries (or is missing) AND no plugin drift is detected:

> No pending drift detected. Your AI tooling is in sync with your codebase.
>
> FileChanged drift is logged automatically when dependencies, configs, or structure change. Plugin drift is detected by comparing installed plugins against forge-meta.json. Check back after making changes to your project.

Stop and do not proceed.

---

## Run Evolve

Use the `evolve` skill to process both drift sources. The skill:

1. Detects plugin drift (new/removed plugins vs forge-meta.json baseline)
2. Reads and categorizes FileChanged drift entries (dependencies, configs, structure)
3. Presents a summary of all detected drift
4. Applies targeted updates:
   - CLAUDE.md (including Plugin Integration section via marker-delimited surgery)
   - Path-scoped rules and skills
   - Quality-gate hook scripts and settings.json entries
   - forge-meta.json (installedPlugins, coveredCapabilities, hookStatus)
5. Shows what was changed (diff)
6. Clears processed FileChanged entries from the drift file
7. Asks for confirmation on structural changes (new CLAUDE.md files)

---

## After Evolve

> Tooling updated. Run `/onboard:evolve` again after your next batch of changes, or check `/onboard:status` (or `/forge:status` for Plugin Integration coverage) for an overview.
