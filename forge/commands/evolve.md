# /forge:evolve — Apply Pending Tooling Updates

You are running the Forge evolve command. This reads accumulated drift from `.claude/forge-drift.json` and applies targeted updates to keep AI tooling in sync with your codebase.

## Guard

Read `.claude/forge-drift.json` in the project root. If not found or has no entries:

> No pending drift detected. Your AI tooling is in sync with your codebase.
>
> Drift is logged automatically by FileChanged hooks when dependencies, configs, or project structure change. Check back after making changes to your project.

Stop and do not proceed.

---

## Run Evolve

Use the `evolve` skill to process the drift entries. The skill:
1. Reads and categorizes drift entries (dependencies, configs, structure)
2. Presents a summary of what changed
3. Applies targeted updates to CLAUDE.md, rules, and skills
4. Shows what was changed (diff)
5. Clears processed entries from the drift file
6. Asks for confirmation on structural changes (new CLAUDE.md files)

---

## After Evolve

> Tooling updated. Run `/forge:evolve` again after your next batch of changes, or check `/forge:status` for an overview.
