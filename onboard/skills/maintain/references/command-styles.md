# Command styles (D26)

How `onboard:maintain` Step 3.3 writes one script line into a fitting commands section. Examples use a new script `price:check` whose `run` is `tsx scripts/price-check.ts`.

## Which entry to copy

- The style is that of the section's **command entries**. If the section mixes styles, follow its **last** command entry.
- If the section has `###` subsections, write into the subsection that best fits the script (build, test, quality, database, …); if none fits better, the **last** subsection.

## The invocation

Copy the runner form of the entries around it:

| Entries look like | Item in the same package | Item in another package |
|---|---|---|
| `npm run dev` | `npm run price:check` | `npm run price:check -w <package>` |
| `pnpm dev` | `pnpm price:check` | `pnpm --filter <package> price:check` |
| `pnpm --filter @repo/crm test` | — | `pnpm --filter <package> price:check` (the entries' selector form) |
| `yarn dev` | `yarn price:check` | `yarn workspace <package> price:check` |
| `bun run dev` | `bun run price:check` | `bun run --filter <package> price:check` |
| bare names (`dev`, `test`) | `price:check` | `price:check` |

npm's lifecycle shortcuts — `npm test`, `npm start`, `npm stop`, `npm restart` — are not a runner form: npm runs any other script only as `npm run <name>`. When the entry you copy is one of them (a section ending in `` `npm test` `` is common), still write `npm run price:check`, never `npm price:check`. yarn, pnpm and bun have no such exception.

"Same package" means the target `CLAUDE.md` sits in the item's package directory, or the target is the root `CLAUDE.md` and the item's `file` is the root `package.json`. When the item's `package` is null, the package is named by its directory (`--filter ./apps/tool`, `-w apps/tool`). If the entries already name the item's package with a selector, reuse exactly that selector spelling.

Bare names have no runner word, so the line cannot be recognised as a mention: Step 3.4 then removes it and defers `unrecognized-style`. Write it anyway — that check, not you, decides.

## The four styles

**List** — a new list line directly after the section's (or subsection's) last list entry, copying its marker, backticks and separator (`—`, `-`, `:`). The description is the `run` command verbatim; omit it if the entries have none.

```
- `npm run dev` — Start dev server
- `npm test` — Run tests
- `npm run price:check` — tsx scripts/price-check.ts
```

**Fenced block** — a new line inside the section's last fenced block, directly before its closing fence. When the entries carry trailing `# comments`, add `# <run>` with the `#` in the same column as the line above; if the invocation is too long for that column, use two spaces before `#`. When they carry none, write the invocation alone.

```bash
pnpm --filter @repo/crm test          # Vitest unit tests
pnpm --filter @repo/crm price:check   # tsx scripts/price-check.ts
```

**Table row** — a new row directly after the last body row, same cell padding and backticks as that row: the invocation in the command column, the `run` command in the description column. Leave any other columns empty.

```
| `npm run dev` | Start dev server |
| `npm run price:check` | tsx scripts/price-check.ts |
```

**Inline `A | B`** — extend that one line in place with the same separator and backticks. There is no description slot.

```
`npm run dev` | `npm test` | `npm run price:check`
```

## Never

- Change any other line: no re-wrapping, re-aligning, re-ordering or blank-line changes.
- Add prose, a heading or a new section. No fitting section → the item is deferred `no-matching-section` before you get here.
