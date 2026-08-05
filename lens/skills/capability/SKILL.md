---
name: capability
description: Internal capability-declaration surface for a programmatic caller's compatibility gate — answers "which lens is installed, and does it support X?" before any review is sent. Returns the manifest version, the advertised capability tokens, and the input keys and resolution rules a caller may rely on; a requested token lens does not advertise comes back as a named error instead of a silent partial run.
user-invocable: false
---

# Capability — What This lens Advertises to a Programmatic Caller

You are invoked by an **orchestrator** (not a human), ahead of any call to `lens:engine`. You answer
one question: *what does this installation of lens support?* You read one file, compare one list, and
return one object. You dispatch no agent, read no diff, judge nothing, and write nothing at all.

The **shape** of both returns is declared in `../engine/references/engine-api.md`
**§ lens:capability**. The advertised **set** — the tokens, the input keys, the resolution rules —
lives here, because it is the answer rather than the shape.

## Your input (supplied in context by the caller)

- `require` — an optional array of capability tokens the caller needs. **`require` absent ⇒ a pure report**: you return the advertised set and can never return a capability error, because nothing was asked for that could be unsatisfied. Present and empty is the same pure report, for the same reason. A manifest that cannot be read still fails the call — that is an install-integrity failure rather than a capability miss, and it carries its own code (Step 1).
- `require` present must be an **array of strings**. A bare string, an object, or an array holding a non-string is a caller shape bug, not a capability miss: return `E_INVALID_INPUT` (declared in `../engine/references/engine-api.md` § Errors) before Step 2 runs. Never iterate a bare string — its characters are not tokens, and matching them would answer a question the caller never asked.

## Step 1: Read the version from the manifest

Read `.version` from `"${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"` — the double-quoted,
plugin-root form — and report the filter's output **verbatim**:

```bash
jq -e -r 'if (.version|type) == "string" and (.version|test("\\S")) then (.version|sub("^\\s+";"")|sub("\\s+$";"")) else null end' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"
```

Keep the double quotes. Unquoted, an unset or space-bearing `${CLAUDE_PLUGIN_ROOT}` word-splits and
the read dies as a command-not-found rather than as the file failure it actually is.

**The type test lives inside `jq`, not after it.** `-r` prints a JSON string without its quotes — which
also erases the only evidence that the value *was* a string. `{"version": 143}` and `{"version": "143"}`
both exit `0` and both print the same three bytes, so **no inspection of the output can tell them
apart**, and a plausible manifest typo — an unquoted version — would be reported verbatim to a caller's
compatibility gate as if it were real. The filter above asks `.version|type` while the type still
exists, and collapses every value that is not a string with content — a number, a bool, a float, an
object, an array, `""`, a whitespace-only string, `null`, an absent key — to `null`.

**The emptiness test lives inside `jq` too, and so does the trim.** The identical argument applies one
step further: a **whitespace-padded** `.version` is a string, and it is not empty, so a bare length test
clears it and `-r` prints the padded value at exit `0` on exactly one non-empty line — an **exit and
line signature byte-identical to the healthy case**. Reported verbatim, that hands a caller's equality
or semver check a silent miss with no `error` key to branch on, which is the fabricated-version outcome
one road over. So `test("\\S")` asks for at least one non-whitespace character *while the value is still
JSON*, and the two `sub` calls strip the surrounding whitespace before the value ever leaves `jq`.
**The trim is deliberate and it is the only normalization performed:** "verbatim" means the filter's
output byte for byte, not the manifest's raw bytes, because a caller gating on a version string cannot
use one it has to trim itself and cannot tell that it needs to. Nothing else is rewritten — case, inner
characters and length are untouched — and a `.version` that has no non-whitespace character at all is
collapsed to `null` rather than reported as an empty string.

**`-e` is load-bearing, and so is reading the exit status.** `-e` is what turns that `null` into a
non-zero exit. Without it, `jq` succeeds on exactly the inputs this step exists to catch: a manifest with
no `.version` key prints the four characters `null` and exits `0` — a fabricated version, reported as if
it were real — and an empty, whitespace-only or truncated manifest prints nothing and also exits `0`,
because `jq` reads zero documents as zero output rather than as an error, so the most likely corruption
of a half-synced install would sail past the failure path below. **Check the exit status before you
report anything:**

| Exit | What happened | What you do |
|---|---|---|
| `0`, with one non-empty line of output | `.version` is present, is a JSON string, and carries at least one non-whitespace character | Report the filter's output verbatim — it is already trimmed |
| `1` | The filter returned `null` — `.version` is absent, `null`, `""`, whitespace-only, or not a string at all (a number, a bool, a float, an object, an array) | **Failure** — a missing, contentless or wrong-typed version |
| `4` | The file held no JSON document at all — empty, whitespace-only, or `/dev/null` | **Failure** — an unparseable manifest |
| anything else | The path could not be read at all (missing, a directory, no permission) or the JSON is malformed | **Failure** — an unreadable or unparseable manifest |

A zero exit is necessary and not sufficient: the output must also be **one non-empty line**. The filter
settles what each value `jq` emitted *was*; it cannot settle *how many* it emitted, and a manifest
holding two concatenated JSON documents prints two candidate versions at exit `0`. A `.version` string
carrying an inner newline splits across lines the same way. Blank or whitespace-only counts as empty,
and any output that is not a single non-empty string line is an **unparseable manifest** — the same
failure as exit `4`.

Between them the two checks are exhaustive: the filter decides **what was emitted** — the type, and that
it has content — while the line rule decides **how many** were emitted, so anything clearing both is
exactly one JSON string with non-whitespace content, trimmed by the filter, which is the only thing this
step is allowed to report.

**Never fabricate.** A missing or unparseable manifest is a **failure**, not a fallback: return the
`E_MANIFEST_UNREADABLE` envelope (declared in `../engine/references/engine-api.md` § Errors) carrying
the path you could not read and the exit status that classified it, and return no report at all.
The version is never fabricated, guessed, or hardcoded — a caller gating on it would rather see a
broken install than a confident wrong answer. That install-integrity failure travels the **same
`error` channel** as every other failure here, and for the same reason: a caller doing the documented
`if (r.error)` branch must never land in the success arm holding an undefined `version`.

## Step 2: Match `require` against the advertised set

**Check the shape first.** Matching runs only once `require` is known to be an array of strings; a
`require` that is not returns `E_INVALID_INPUT` and nothing is matched. A shape bug and a missing
capability are different failures with different fixes, and a caller that cannot tell them apart will
go looking for a newer lens when what it actually has is a serialization bug.

**Matching is exact.** A requested token counts as supported only if it appears in `capabilities[]`
character-for-character — **a misspelling is a miss**, never a fuzzy, case-folded or prefix hit.
Collect every requested token that is not advertised into `missing[]`, in the order the caller asked
for them. A caller that guessed a name wrong has a different bug from one that needs a newer lens, and
only exact matching tells the two apart.

## Step 3: Return

You have exactly two return shapes, and a caller tells them apart by one key:
branch on the presence of `error`.

**Every requested token advertised, or `require` absent** — the report:

```json
{
  "name": "lens",
  "version": "<read from the manifest at call time>",
  "capabilities": [
    "injectedIntent",
    "injectedFinders",
    "adherenceReturn",
    "emptyScope",
    "renderReview",
    "modelPolicy",
    "verifyVotes",
    "finderModel",
    "finderEffort",
    "degradedReasons",
    "namedErrors"
  ],
  "supports": {
    "inputKeys": [
      "target",
      "scope",
      "taskIds",
      "injectedIntent",
      "injectedFinders",
      "finders",
      "modelPolicy",
      "verifyVotes"
    ],
    "resolutionRules": {
      "verify": "huginn-quorum-v1",
      "intent": "injected-wins",
      "dedup": "file-line-title",
      "model": "lens-model-precedence-v1",
      "emptyScope": "flag-not-empty-findings"
    },
    "effortChannel": "prompt-directive"
  }
}
```

`inputKeys[]` is what `lens:engine` accepts (`scope` is the historical alias of `target` — both
spellings work). `resolutionRules` names the rule each ambiguity is settled by. **Every value there is
a rule NAME, never a restatement of the rule** — `lens-model-precedence-v1` is declared at
`../engine/references/engine-api.md` § Model resolution exactly as `huginn-quorum-v1` is declared at
its own governing site. A name cannot go lossy; a restated chain can, and did: an arrow string that
dropped one position advertised a six-step order against a seven-step rule.

**Two of the five names resolve today; three do not, and that bounds what the set is good for.** A
caller can look `huginn-quorum-v1` and `lens-model-precedence-v1` up at the governing sites above and
read what they mean, so for `verify` and `model` it can tell whether *this* lens settles the ambiguity
the way it expects. `injected-wins`, `file-line-title` and `flag-not-empty-findings` occur nowhere
under `lens/` but in the set itself: each is a slot label awaiting a declaration site. They are stable
enough to compare across versions — a caller can tell that the rule changed — but not yet enough to
tell what it changed to, and reading one as a lookup that resolves would be reading more than this
release delivers.

`effortChannel` says how a finder record's `effort` reaches the dispatch: as a prompt-level directive,
never as a model-resolution input.

**Any requested token not advertised** — the named error:

```json
{
  "error": {
    "code": "E_UNSUPPORTED_CAPABILITY",
    "message": "lens does not advertise: verifyVote",
    "extra": {
      "missing": ["verifyVote"],
      "have": ["<the capabilities[] array above, complete and verbatim>"]
    }
  }
}
```

`have[]` carries the whole advertised set, so a caller reading the failure sees the correct spellings
next to what it asked for and can fix a typo without a second round trip.

**The version could not be read** (Step 1) — the same channel, a different code:

```json
{
  "error": {
    "code": "E_MANIFEST_UNREADABLE",
    "message": "cannot read a single non-empty .version from the plugin manifest",
    "extra": {
      "path": "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json",
      "exit": 4
    }
  }
}
```

`path` is the file that could not be read and `exit` is the status Step 1's table classified it by, so
a caller can tell a half-synced install from an absent one without parsing the message. Both failures
are envelopes because a caller branches on one key: an install failure reported as prose has no
`error` for that branch to see, and lands in the success arm with `version` undefined.

## Key Rules

- **Answer, never act.** No agent, no diff, no file. This skill is a declaration, not a review.
- **Version from the manifest, every call.** Read it, report the filter's output verbatim, and fail through `E_MANIFEST_UNREADABLE` when it cannot be read — never carry a literal, and never report a failure as prose the branch key cannot see. Exit `0` alone is not a successful read: the filter must have confirmed inside `jq` that `.version` is a string carrying non-whitespace content, and the output must be a single non-empty line. Neither the type check nor the content check can be moved after the read — `-r` has already erased the type by then, and a padded value clears every post-hoc test a healthy one clears.
- **Two return shapes, one branch key.** The report, or an error envelope — `E_UNSUPPORTED_CAPABILITY` for a token lens does not advertise, `E_INVALID_INPUT` for a `require` that is not an array of strings, `E_MANIFEST_UNREADABLE` for a manifest that yields no readable `.version`. `require` absent is the report on every path but the last.
- **Advertise only what is governed.** A token belongs in `capabilities[]` only while a section of `../engine/references/engine-api.md` (or the skill it points at) actually governs the behavior it names.
