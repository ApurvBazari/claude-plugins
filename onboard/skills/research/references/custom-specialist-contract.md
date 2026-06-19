# Custom Specialist Contract — discovery, roster math, and the prompt-XOR-agent rule

The research roster is **extensible and tunable**. A target repo can disable built-in dimensions and add its own specialists via `.claude/onboard-research.config.json` (the `research-config.json` contract). This file defines how the engine discovers that config, computes the effective roster, and degrades gracefully when a custom specialist is malformed.

## Step A: Discover the config

1. Look for `.claude/onboard-research.config.json` in the project root.
2. **Absent / unreadable** → no tuning; effective roster = the 7 built-ins (capped by depth). This is the common case; do not warn.
3. **Present** → validate against `onboard/schemas/research-config.json` (read the schema as the contract; opportunistically shell to `python3 -c "import jsonschema; …"` for a hard check when the dev dep is present).
   - **Config itself malformed** (fails the schema at the top level) → warn and **fall back to built-ins only**. A broken config must not crash the run; it disables tuning, not research.

## Step B: Compute the effective roster

```
builtins          = [architecture, data-model, testing, security, conventions, domain, dependencies]
disabledBuiltins  = config.disabledBuiltins            (⊆ the builtins enum, by schema)
extraSpecialists  = config.extraSpecialists            (each {name, dimension, prompt?, agent?, scopeGlobs?})

effectiveRoster   = (builtins − disabledBuiltins) ∪ validExtraSpecialists
```

- `disabledBuiltins` is constrained by the schema to the seven built-in names, so the echoed `research-dossier.roster.disabledBuiltins` is **config-derived by construction** — it is always a subset of the enum, no separate assertion needed.
- The depth cap (`depth-profiles.md`) is applied to `effectiveRoster` *after* this math.

## Step C: The prompt-XOR-agent rule (enforced at discovery, not in the schema)

Each `extraSpecialist` MUST supply **exactly one** of `prompt` or `agent`. The schema is deliberately permissive (it does not encode XOR) so a near-usable config is not rejected outright; the engine enforces XOR at discovery:

| Custom specialist shape | Engine action |
|---|---|
| `prompt` only | **Use it** — fill it as the specialist's investigation brief, dispatch `research-specialist` with the custom `dimension` + `scopeGlobs`. |
| `agent` only | **Use it** — the `agent` path points to a user agent file (e.g. `.claude/agents/research-a11y.md`). First run the **path-safety check** (below); if it passes, verify the file exists, then dispatch THAT agent with the same `{dimension, scopeGlobs, prompt:""}` envelope + `dispatchedAsAgent:true`. |
| **neither** `prompt` nor `agent` | **Skip + warn** — `"custom specialist '<name>' supplies neither prompt nor agent; skipped."` Roster falls back to the remaining valid specialists. |
| **both** `prompt` and `agent` | **Skip + warn** — `"custom specialist '<name>' supplies both prompt and agent (exactly one required); skipped."` |
| `agent` points to a **missing file** | **Skip + warn** — `"custom specialist '<name>' references missing agent file <path>; skipped, falling back to built-ins."` |
| `agent` path **escapes the project root** (absolute, contains a `..` segment, not under `.claude/`, or resolves via symlink outside the repo) | **Skip + warn** — `"custom specialist '<name>' agent path '<path>' escapes the project root; skipped, falling back to built-ins."` |
| `prompt` **exceeds 16 KiB** (16384 bytes) | **Skip + warn** — `"custom specialist '<name>' prompt exceeds the 16 KiB cap; skipped."` |

A skipped custom specialist never enters `effectiveRoster`; the run continues with whatever remains. Skipping a custom is **never fatal**.

### Path-safety + size guards (authoritative — schema validation is opportunistic)

Step A validates the config against `research-config.json` only *opportunistically* (when the `jsonschema` dev dep is present). The security-relevant constraints must therefore be **re-enforced here at discovery**, where they always run; the schema `pattern`/`maxLength` are a belt, this check is the load-bearing one.

- **`agent` path-safety.** Before touching the file, confirm the path is repo-safe: it (a) is relative — does not begin with `/` or `~`; (b) begins with `.claude/`; (c) contains no `..` path segment; and (d) after resolving symlinks, still resolves to a location **under the project root**. Any failure → skip + warn (table rows above). This stops a hostile `.claude/onboard-research.config.json` (e.g. a fork/PR contribution) from pointing `agent` at `/etc/passwd`, `../../secrets.md`, or `/tmp/evil-agent.md`.
- **`prompt` size cap.** Truncating a brief can silently corrupt its meaning, so an oversized `prompt` (> 16384 bytes) is **skipped + warned**, not truncated.

**Residual (documented, accepted):** `.claude/onboard-research.config.json` is project-owner-authored config committed to the repo, so the trust boundary is the repo itself, and the symlink check (d) is best-effort within an LLM-run engine. An attacker who already controls the repo's `.claude/` tree has easier vectors than a research-config path — these guards harden the *fork/PR-contributed-config* case, not a fully-compromised checkout.

## Step D: Custom specialists emit the same shape

Every custom specialist — whether driven by an inline `prompt` (via the built-in `research-specialist`) or a user `agent` — MUST return a `research-findings.json`-shaped object (`dimension`, `status`, `claims[]`). They flow through the **same** Gate-1 validation, the **same** verifier, and the **same** synthesizer as built-ins. This single-shape contract is what makes the roster extensible without special-casing downstream.

## Step E: Malformed-output handling — the built-in vs. custom split

This is the load-bearing asymmetry (it mirrors `config-generator`'s hard-fail discipline for built-ins while staying tolerant of third-party customs):

| Source | Output fails `research-findings.json` at Gate-1 |
|---|---|
| **Built-in** dimension | **FAIL-LOUD** — abort the run before synthesis with the validation error. A built-in producing malformed output is a defect in onboard itself and must surface. |
| **Custom** specialist | **Skip + warn** — drop that dimension, record the warning, continue synthesis with the rest. A third-party specialist must not be able to crash the run. |

(Discovery-time skips in Step C and Gate-1 output skips in Step E are both "skip + warn" for customs — the difference is only *when* the problem is detected.)

## Worked example

`.claude/onboard-research.config.json`:

```json
{
  "disabledBuiltins": ["security"],
  "extraSpecialists": [
    { "name": "accessibility", "dimension": "WCAG / a11y coverage",
      "agent": ".claude/agents/research-a11y.md", "scopeGlobs": ["src/components/**"] },
    { "name": "i18n", "dimension": "Internationalization coverage",
      "prompt": "Assess i18n: hardcoded strings, message catalogs, locale handling.",
      "scopeGlobs": ["src/**"] }
  ]
}
```

At `comprehensive` depth, assuming `.claude/agents/research-a11y.md` exists:

```
builtins − disabledBuiltins = [architecture, data-model, testing, conventions, domain, dependencies]
∪ extraSpecialists          = + accessibility (via agent) + i18n (via prompt)
effectiveRoster             = 6 builtins + 2 customs = 8 specialists dispatched
roster.builtins             = the 6 enabled builtins
roster.disabledBuiltins     = ["security"]            (echoed from config)
roster.customSpecialists    = ["accessibility", "i18n"]
```

If `.claude/agents/research-a11y.md` is missing → `accessibility` is skipped+warned; the run proceeds with 6 builtins + `i18n`.
