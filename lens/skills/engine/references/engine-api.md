# lens programmatic API — the single declared surface

What `lens:engine` takes and returns, what `lens:render-review` consumes, and **who owns each field** —
stated once, here. A programmatic caller (matali, vicario, any orchestrator) reads this file instead of
reconciling the same shapes out of eight SKILL and reference files.

## Precedence — this doc declares, the skills govern

This doc **declares** the surface — names, shapes, owners. The SKILL and reference sections cited below
**govern** it: they are the runtime. **If the two disagree, the procedure wins and this doc is the bug** —
repair the declaration here, never the behavior there.

That precedence is what makes a declaration doc safe in a repo where prose *is* the runtime: nothing here
changes what the engine does, so a stale line here can never silently change behavior. In exchange, the
procedure files point at this file rather than restating a shape — a shape restated in two places is a
surface that has already begun to fork.

## Ownership map

| Surface | Owner (who SETS it) | Declared here | Procedure lives at |
|---|---|---|---|
| `lens:engine` inputs — `target`, `taskIds?`, `injectedIntent?`, `injectedFinders?`, `finders`, `modelPolicy?`, `verifyVotes?` | the **caller** | § lens:engine — inputs | `../SKILL.md` · `./pipeline.md` §1–§3 |
| `lens:engine` returns — `findings[]`, `recommendedEscalation`, `degraded`, `degradedReasons[]?`, `summary?`, `emptyScope?`, `adherence?` | **`lens:engine`** | § lens:engine — returns | `../SKILL.md` Steps 1–5 · `./pipeline.md` §4–§8 |
| `delta`, `severityTrend` | **reconcile (compute-only)** — never the engine | § Downstream additions (NOT engine returns) | `../../review/references/reconcile.md` § Orchestrator mode |
| `lens:render-review` inputs — `findings`, `priorFindings?`, `diffRef?`, `spec?`/`plan?`/`adherence?`, `outputPath` | the **caller** | § lens:render-review — inputs and returns | `../../render-review/SKILL.md` |
| the rendered artifact + `renderedPath` | **`lens:render-review`** (write-once, `outputPath` only) | § lens:render-review — inputs and returns | `../../render-review/SKILL.md` |
| prior-run state (`.claude/lens/review-state.json`) | **the caller** — standalone `/lens:review`, or the orchestrator in compute-only mode | — | `../../review/references/reconcile.md` § Write-back |
| the per-finding shape + the closed `dimension` enum | **the schema** | — | `../../../schemas/review-findings.schema.json` |
| the named-error envelope — the failure channel of both surfaces | **`lens:engine`** (pre-flight only) · **`lens:capability`** | § Errors · § lens:engine — return channels | `../SKILL.md` Step 0 · `../../capability/SKILL.md` |

## lens:engine — inputs

Every input arrives through the one Skill-tool invocation channel, and **every one is optional**: handed
none, the engine reviews the default scope, runs task-silent, and selects intent diff-correlated. A missing
or empty arg is "not provided"; an arg delivered as a JSON string rather than the structure it declares is
parsed defensively before it is checked — an **array** for `injectedIntent`/`injectedFinders`, before the
emptiness check (`./pipeline.md` §2 rule 0, §3), and an **object** for `modelPolicy`, in pre-flight
(`../SKILL.md` Step 0). The parse is where a serializing harness is forgiven, not where the type stops
mattering: what it yields still has to **be** that structure, and a `modelPolicy` that is not an object
after it raises rather than being ignored (§ Model resolution).

| Input | Shape | Notes |
|---|---|---|
| `target` | string — a ref, a range, or a pathspec | The **canonical** name for the diff-scope override; used verbatim in place of the default scope. Historical alias: `scope` — the same channel under the older spelling, still used by `./pipeline.md` §2/§3 and by matali's call site. Both spellings are in use and nothing is renamed; a caller may hand either. |
| `taskIds` | `{ scope, intent, analyze, verify }` | Harness task ids for the four engine stages, handed only by the standalone `/lens:review` path. **Absent ⇒ the engine is task-silent** — it takes no task action at all, which is the compute-only/orchestrator path. |
| `injectedIntent` | `Array<{ role: "spec" \| "plan", name: string, content: string }>` | The **frozen matali contract**, and the highest-priority intent source. `content` is the full spec/plan markdown used verbatim; `name` is the provenance tag carried as `sourceSpec`/`sourcePlan`; `role` selects the adherence fan-out. Governed by `./pipeline.md` §2 rule 0. |
| `injectedFinders` | `Array<{ agent, dimension, label?, readonly: true, model?, effort? }>` | **The canonical project-finder path** for a programmatic caller. `agent` resolves through the Agent-tool registry and **may be plugin-qualified** (e.g. `matali:principles-finder`), so the finder ships in the caller's own plugin. Dispatched identically to the file-registered project tier — read-only enforced at the boundary, normalized, deduped, adversarially verified. A malformed `model`/`effort` on one of these **call-time** records **raises `E_INVALID_INPUT`** in pre-flight (§ Errors, I-1): the caller that sent the record is the one that can fix it. **A record carrying neither key never raises** — a 1.4.3-shaped `injectedFinders` record has no 1.5.0 key to be malformed, so it resolves and dispatches exactly as it did in 1.3.0 (I-2). Governed by `./pipeline.md` §3 and `./finder-registry.md` Tier 3. |
| `finders` | project-tier finder entries (`agent`, `dimension`, `label?`, `readonly: true`, `model?`, `effort?`) | The **file-based** project registry, read from `.claude/lens/settings.md`. Same dispatch and same read-only enforcement as `injectedFinders`; the only difference is where the entry came from. A malformed `model`/`effort` here **never raises**: it is normalized where it can be and dropped where it cannot, with `degraded: true`, `degradedReasons` code `finder-malformed`, and the drop named in `summary` — standalone `/lens:review` hands the engine no 1.5.0 input, so it **cannot fail on project config**. |
| `modelPolicy` | `{ deny?: string[], default?: string, byRole?: { finder?: string, verifier?: string }, byAgent?: { <agent>: string } }` | The caller's model policy for this run. Every key is optional and `{}` is valid; resolved once in pre-flight and never re-read mid-run. The ordering, the denied-winner rule and the matching semantics are declared in § Model resolution — the precedence chain. A malformed policy raises `E_INVALID_INPUT` — including one that is not an object at all, which is checked before any key is read. |
| `verifyVotes` | integer — `1..5` | How many independent verifier votes each surviving candidate gets in VERIFY. The votes are resolved into `verified` and `voteResolution` by the named rule `huginn-quorum-v1`, whose procedure lives at `./pipeline.md` §5. |

**The `effort` knob, and the one channel it travels.** `effort` is exactly `low` | `medium` | `high` |
`xhigh` | `max`, and it is **not** a model: it never enters model resolution but is a **prompt-level
directive prepended to the dispatched finder prompt** — placed **behind** any read-only/findings-only
contract that prompt already carries and **never ahead of it**, because a directive that arrives first
can be read as re-framing the contract behind it. That ordering is the guard, not a formatting
preference, and both procedures enforce it: `./pipeline.md` §3 for an ordinary finder prompt, and the
forcing wrapper-prompt at `./adapter-dispatch.md` Part 1 for an adapter-tier producer. That the file
tier degrades where the call-time tier raises is a **deliberate decision, not an inconsistency**: a
caller can fix `injectedFinders` in the same call that sent it, while `settings.md` is a human's
project config, written long before this run.

**What a malformed `model` is.** `model` is a **model id string**, non-empty once trimmed. Anything
else on a Tier-3 record is malformed and takes that record form's declared path — raise for a
call-time `injectedFinders` record, normalize-or-drop for a file-registered one: a number, a bool, an
object, an array, an empty or whitespace-only string, or the key present with no value. lens checks
the **shape, not the id** — it keeps no catalog of known models, because one written here would go
stale on the next model release, so an id the harness does not recognize is the harness's to reject at
dispatch rather than lens's to pre-judge. `deny` is unaffected either way: it matches by substring, so
a deny list still holds against an id lens has never seen.

**`verifyVotes` is optional, and validated strictly:**

- **Default `1`.** Handed nothing, the engine runs one skeptic per finding — the 1.4.3 panel size.
- **Absent never raises.** A call that omits `verifyVotes` cannot receive an error envelope for it (§ Errors, I-2); it gets the default.
- **Present-and-invalid raises `E_INVALID_INPUT`** — a non-integer, or an integer outside `1..5` — rejected in pre-flight (§ Errors, I-1) with `extra.expected` naming the range `1..5`.

## Model resolution — the precedence chain

Every dispatch resolves to exactly one model before it is sent — every finder, and every verifier vote.
The chain is declared **here and nowhere else**; the procedure files point at this section rather than
restating it, because a resolution order stated twice has already begun to fork.

The chain has a **name**: `lens-model-precedence-v1`. That is the name `lens:capability` advertises
under `supports.resolutionRules.model`, exactly as `huginn-quorum-v1` is the name it advertises under
`resolutionRules.verify` — a caller reads the name to tell whether *this* lens resolves the way it
expects, and reads this section for what the name means. A rule NAME is what the advertised set carries;
the chain itself is never restated there, because a restatement that drops a position is a lossy second
declaration of the one thing this section exists to declare once.

**`deny → record.model → byAgent → byRole → default → agent frontmatter → harness default`**

Read left to right. `deny` is a **gate on the winner, not a filter over the candidates**: it removes
nothing from the chain, so the first position that yields a value still takes the dispatch, and `deny`
then judges *that* value. A denied model can therefore win — which is the whole subject of the
denied-winner rule below, and would be unreachable under the other reading.

| # | Position | Where the value comes from |
|---|---|---|
| ① | `deny` | `modelPolicy.deny` — a gate on the winner, not a source and not a filter: it removes no candidate from the chain and judges the value that wins it |
| ② | `record.model` | the finder record's own `model`, from `injectedFinders` or the file-registered project tier |
| ③ | `byAgent` | `modelPolicy.byAgent`, keyed by the dispatched agent exactly as written |
| ④ | `byRole` | `modelPolicy.byRole`, keyed by `finder` or `verifier` |
| ⑤ | `default` | `modelPolicy.default` — one model for every dispatch the policy has not named individually |
| ⑥ | agent frontmatter | the dispatched agent's own `model:` line — the 1.4.3 source |
| ⑦ | harness default | whatever the harness would have chosen with no `model:` at all |

**`modelPolicy` must be an object.** Every rule below is **key-scoped** — an unknown key, a wrong-typed
key, an unaccepted role — and a value that has no keys at all satisfies every one of them vacuously. So
the top-level type is checked **first**, before any key is looked at. A policy delivered as a JSON string
is parsed defensively once (§ lens:engine — inputs); anything that is not a JSON object after that parse
— **a string** that does not parse to one, **an array**, **a number**, **a bool** — raises
`E_INVALID_INPUT`, with `extra.expected` naming an object of the four accepted keys. Being ignored is the
outcome this rule exists to forbid: a discarded policy takes the `deny` gate down with it and the run
still reports an ordinary non-degraded success, so the one cost/compliance control over finder dispatch
would fail open with nothing in the return to say so. **`null` and an absent key are not a wrong type** —
they are "not provided", the 1.4.3 case, and provide no policy at all.

**The four keys.** Once it is an object, `modelPolicy` accepts
**exactly these four optional keys, and no others**: `deny`, `default`, `byRole` and `byAgent`. The input
is optional, and an empty policy constrains nothing: `modelPolicy: {}` is **valid** and **must not raise**.

**`byRole` accepts exactly two roles**, and each one covers a whole class of dispatch:

| Role | The dispatches it selects a model for |
|---|---|
| `finder` | every ANALYZE producer — the five built-in finders, the adapter tier, the file-registered project tier, and `injectedFinders` |
| `verifier` | every VERIFY dispatch — the adversarial skeptic, on each of its votes |

A malformed policy is rejected in pre-flight (§ Errors, I-1), never mid-run:

| Malformation | Example | Result |
|---|---|---|
| the policy itself is not an object — checked ahead of every row below, which a keyless value would otherwise pass vacuously | `"{ \"deny\": [\"haiku\"] }"` — a stringified policy that does not parse to an object, or an array, a number, a bool | `E_INVALID_INPUT`, with `extra.expected` naming an object of the four accepted keys |
| an unknown key — anything outside the four | `{ "denyList": ["haiku"] }` | `E_INVALID_INPUT`, with `extra.expected` naming the four accepted keys |
| a wrong-typed key — `deny` that is not a `string[]`, `default` that is not a string, `byRole`/`byAgent` that is not a string→string map | `{ "deny": "haiku" }` | `E_INVALID_INPUT`, with `extra.value` carrying what actually arrived |
| a `byRole` role outside `finder`/`verifier` | `{ "byRole": { "skeptic": "opus" } }` | `E_INVALID_INPUT`, with `extra.expected` naming the two accepted roles |

**Denied-winner rule.** `deny` is absolute: a denied model is never dispatched. There are **exactly two
branches**, and which one applies turns on **who chose the denied model**.

| Winning position | Outcome |
|---|---|
| ②–⑤ — a caller-supplied request | **Raise `E_MODEL_POLICY_UNSATISFIABLE`.** lens never clamps a model the caller explicitly asked for down to one it did not ask for — a policy that denies what the same call requests is a contradiction only the caller can resolve. |
| ⑥–⑦ — an implicit default | **Raise `E_MODEL_POLICY_UNSATISFIABLE`.** Reaching ⑥–⑦ at all means the policy named neither this agent nor this role and set no `default`, so it has offered **no allowed candidate** for this dispatch — nothing to put in the denied default's place, and no model left to send. |

**Why there is no third, substituting branch.** ③–⑤ are consulted **before** ⑥–⑦, and each is matched
to *this* dispatch site — `byAgent` keyed to this exact `agent`, then `byRole` keyed to this dispatch's
role, then `default`, and never a value keyed to some other agent or some other role. So a dispatch that
reaches ⑥–⑦ at all is one the policy was already silent about for this site, and silence has nothing to
substitute: the substitute set is empty by construction, not merely small. An earlier draft of this
section declared a third row that substituted "the highest-precedence allowed policy value" for a denied
implicit default; under site-scoped matching that row can never fire, and a branch a caller cannot reach
is a promise it would be wrong to make. The way to keep a dispatch off the raise path is to give the
chain a value it can see: name the agent in `byAgent`, name the role in `byRole`, or set `default`. Deny
an implicit default without doing one of those and the run raises — which is what "`deny` is absolute"
means once the policy has offered nothing to put in its place.

**A policy outcome is never a degrade.** Neither branch records anything in `degradedReasons[]`: a raise
comes back on the failure channel as the named-error envelope (§ Errors), and a resolution that clears
`deny` is the policy working exactly as written. `degradedReasons[]` reports *coverage*, and a policy
doing its job is not a coverage gap.

**The file tier is not exempt from `deny`.** Position ② covers both record forms, so a
**file-registered** record whose `model` is well-formed but denied raises exactly as a call-time one
does. That is not a contradiction of the file tier's normalize-or-drop posture: **that posture is
scoped to malformation** — a `model`/`effort` the engine cannot make sense of — while `deny` gates a
value it understands perfectly. The two never meet on the standalone path, because `deny` exists only
when a caller sent a `modelPolicy` and `/lens:review` sends none: a project's own registered model can
be denied only by an orchestrator that asked for it to be.

**The verifier floor.** `deny` is not the only gate. Every `verifier`-role dispatch also passes a
**never-Haiku floor**: the adversarial skeptic is never dispatched on a Haiku-class model, whatever the
policy says. The floor matches the way `deny` matches — **case-insensitively, by substring**: a
resolved id containing `haiku` is below it, so a dated id is caught without the floor having to
enumerate one. It is applied in pre-flight, at the same point the plan is resolved.

| Winning position for a `verifier` dispatch | Outcome |
|---|---|
| ③–⑤ — a caller-supplied policy value below the floor | **Raise `E_MODEL_POLICY_UNSATISFIABLE`**, `extra.role` being `verifier`. lens never silently downgrades the skeptic: a policy that puts the pass which decides what survives below the floor is a contradiction only the caller can resolve, exactly as a denied ②–⑤ winner is. |
| ⑥ — the agent frontmatter | Never below the floor — `../../../agents/verifier.md` declares `model: opus`. That frontmatter is an **overridable default**, and this floor is what bounds the override. |
| ⑦ — the harness default | Not reached while ⑥ yields. Were it reached and below the floor it is an implicit default like any other, and takes the implicit-default branch above: it raises. |

The floor is verifier-only, and deliberately so: a `finder`-role dispatch is gated by `deny` alone, so
a caller that wants cheap finders gets them and only the refute pass is held to a minimum. A 1.4.3-shaped
call never meets the floor either — with no `modelPolicy`, every verifier vote resolves at ⑥ to `opus`.

**Matching.**

- **`deny` matches case-insensitively, by substring, against the resolved model id.** An entry `haiku`
  denies `claude-haiku-4-5-20251001` and `Claude-Haiku-4-5` alike, so a policy never has to enumerate
  dated ids it cannot know in advance. The breadth is deliberate: a deny list is a floor, and a floor
  that the next version bump slips past is not one.
- **`byAgent` matches the `agent` value verbatim** — exactly as written at the dispatch site. There is
  no normalization, no case folding and no plugin-prefix stripping: a key `principles-finder`
  does **not** match a record whose `agent` is `matali:principles-finder`, which has to be keyed under
  that full plugin-qualified spelling. Exact matching is what stops a policy from silently governing an
  agent the caller never named.

## lens:engine — returns

One object, schema-valid against `../../../schemas/review-findings.schema.json` — **seven fields, and nothing
else**. The engine writes no file and asks no question; the caller owns all I/O and any gate.

| Field | Required | Shape |
|---|---|---|
| `findings[]` | required | The surviving findings. Per finding, required: `id`, `title`, `severity`, `dimension`, `verified` (the schema owns the optional rest). |
| `recommendedEscalation` | required | `minor \| moderate \| major \| critical` — the max surviving severity. |
| `degraded` | required | Bool. True whenever coverage was partial; the gap is named in `summary`. |
| `degradedReasons[]` | optional | `{ code, detail }[]` — the closed set of degrade causes: `finder-died` \| `finder-malformed` \| `intent-soft` \| `intent-reconstructed` \| `adherence-capped` \| `finders-capped` \| `diff-truncated`. **Non-empty if and only if `degraded` is true** — that is the rule the schema enforces, in both directions: `degraded:true` requires at least one entry, and `degraded:false` admits only an absent or empty array. Presence alone is not the discriminator: a present-but-empty array is the same statement as an absent one. |
| `summary` | optional | Prose. Names every degrade reason and every skipped doc/finder. |
| `emptyScope` | optional | `true` **only** on empty-diff/no-repo. The sole discriminator between *nothing to review* and *a review that found nothing* — key on it, never on an empty `findings[]`. |
| `adherence` | optional | `{ specItems, planSteps }` — omit-empty; present only when the adherence finders ran. Lets a caller render the full met/partial/missing matrix without re-deriving it. |

**`finder-malformed` must name its emitting site in `detail`.** One code covers **three** distinct
stages, and they are not the same coverage state: a **file-registered record** rejected in pre-flight
(that finder never ran — `./pipeline.md` §3), a **finder's own output** rejected at Step 4 (it ran, and
its item did not conform — `../SKILL.md` Step 4), and an **adapter's output** that could not be
normalized into the finding shape (`./adapter-dispatch.md`). The set stays closed at seven rather than
splitting into three codes, so the discrimination has to live in `detail`: an entry carrying
`finder-malformed` **MUST** name which of those three sites produced it. A consumer branching on `code`
alone learns that a producer is missing; only `detail` tells it whether that producer was ever
dispatched.

That is the **success** channel. Anything a consumer needs beyond these seven is either computed
downstream (§ Downstream additions), arrives on the other channel (§ lens:engine — return channels), or is
not part of the contract at all (§ Known consumer assumptions).

## lens:engine — return channels

`lens:engine` answers on **two channels**, and a consumer tells them apart by one key: **branch on the
presence of `error`** — the same branch key `lens:capability` uses for its own two returns. Branch first,
then read; a consumer that validates before it branches reads a failure as a malformed success.

| Channel | What comes back | Schema |
|---|---|---|
| success | the object declared in § lens:engine — returns | the success branch of `../../../schemas/review-findings.schema.json` — the seven fields, `error` absent |
| failure | the named-error envelope declared in § Errors | that schema's failure branch, sealed to the single key `error`. It is **not** a `review-findings` object and carries none of the seven |

Declaring the envelope as an alternative **branch** rather than as another field is what keeps the two
promises above from contradicting each other: the success return is still seven fields and nothing else,
and a raise is still schema-valid — on its own channel. The schema is what makes that machine-checkable;
the branch key is what makes it usable, because the channels are mutually exclusive, so no object is ever
both.

The failure channel is narrow by construction and stays that way: § Errors' **I-1** confines a raise to
pre-flight and **I-2** confines it to an input introduced in 1.5.0, so a 1.4.3-shaped call receives the
success channel and can receive nothing else.

## Downstream additions (NOT engine returns)

Two optional fields exist in `review-findings.schema.json` that a *downstream* stage — not the engine —
sets:

| Field | Shape | Set by |
|---|---|---|
| `delta` | `{ fixed, new, stillOpen }` — the iteration delta vs the prior run | reconcile, in compute-only mode |
| `severityTrend` | `improving \| same \| regressed` | reconcile, in compute-only mode |

**Not an engine return.** Both are **never set by the engine** — the schema says so on each field's
`$comment`, and the engine's Step 5 return carries neither. They appear only once a caller supplies prior
state: `lens:render-review` runs that reconcile in memory when handed `priorFindings` and surfaces them on
its own return. Procedure: `../../review/references/reconcile.md` § Orchestrator mode.

## lens:render-review — inputs and returns

A pure, stateless, write-once render of an already-computed object. It never re-runs finders and never
re-judges.

| Input | Required | Meaning |
|---|---|---|
| `findings` | required | The current `review-findings` object, already computed by `lens:engine`. |
| `priorFindings` | optional | A prior-run `review-findings` object. Supplying it is what enables reconcile. |
| `diffRef` | optional | A git ref/range to read for the annotated diff hunks; unavailable ⇒ the panel is omitted. |
| `spec` / `plan` / `adherence` | optional | Intent for the adherence matrix. |
| `outputPath` | required | Absolute path for the artifact — the **only** file this skill writes. |

**Returns** — three, and a consumer must branch on which:

| Return | Outcome | Meaning |
|---|---|---|
| `{ renderedPath, delta?, severityTrend? }`, or the line `wrote: <path>` | success | The artifact was written to `outputPath`. |
| `noop: nothing to review` | success | The supplied `findings` carried `emptyScope: true` — nothing to render, **no artifact written**. |
| `skipped: <one-line reason>` | **failure only** | The render failed — never partial state, never an exception that blocks the caller. |

**Empty scope.** When the supplied `findings` carries `emptyScope: true`, render-review returns the
literal `noop: nothing to review` and writes **no artifact** — an empty scope has nothing to render, and
a zero-finding artifact would misreport it as a clean review. It is deliberately **not** `skipped:`:
that line is the failure channel, so a consumer that routes it to a degrade/warn path would read an
ordinary empty diff as a broken render.

## Known consumer assumptions (not part of the contract)

One live consumer reads a field lens does not declare. It is recorded here so it is not mistaken for
contract:

- **An `agents` finder roster.** matali reads `agents` off the engine return — its `review` skill (lines
  186 and 216 of that skill's `SKILL.md`, in the matali repo) forwards it verbatim into
  `derived.execution.P5`, and matali's plugin `CLAUDE.md` (line 52) states that lens "now returns its finder
  roster in `agents`". **lens declares no such field**: not in `../../../schemas/review-findings.schema.json`,
  not in `../SKILL.md`, not in § lens:engine — returns above. It is **not part of the contract** — a
  consumer must default it to `[]` and degrade quietly when it is absent. Documented as a divergence, not
  promoted to a return.

## Errors

The inputs introduced in 1.5.0 are validated strictly, and so is the one file `lens:capability` must
read before it can answer at all: a violation comes back as a **named error envelope** rather than a
crash, a silently ignored key, or a quietly degraded review. One shape, always:

```json
{ "error": { "code": "E_...", "message": "<one line, human-readable>", "extra": {} } }
```

`message` is a single human-readable line; `extra` is a per-code object carrying the facts a caller
needs in order to act, so nothing has to be recovered by parsing prose. The registry is **closed** —
these four codes, and no others:

| Code | Raised by | Trigger | `extra` |
|---|---|---|---|
| `E_UNSUPPORTED_CAPABILITY` | `lens:capability` | A requested capability token lens does not advertise. Matching is exact, so a misspelling is a miss. | `{ missing: [], have: [] }` — the tokens asked for and not found, plus the full advertised set with its correct spellings |
| `E_MODEL_POLICY_UNSATISFIABLE` | `lens:engine` | The model that wins the precedence chain fails a gate. From positions ②–⑤ a denied winner raises even when an allowed candidate exists elsewhere in the policy — a caller's explicit request is never clamped; from ⑥–⑦ a denied winner raises unconditionally, because reaching ⑥–⑦ means the policy offered no allowed candidate for that dispatch site. A `verifier` winner that clears `deny` but sits below the never-Haiku floor raises on the same terms (§ Model resolution). | `{ role, agent, resolved, gate, deny: [] }` — the dispatch site being resolved, the model that won it, and `gate`: which of the two gates rejected it, `"deny"` or `"verifier-floor"`. `deny` carries the list that rejected the model when `gate` is `"deny"`, and is absent or empty on a floor raise — where no deny list rejected anything, so `role` alone cannot tell the two apart |
| `E_INVALID_INPUT` | `lens:engine` · `lens:capability` | A 1.5.0 input that is present but malformed — an unknown or wrong-typed `modelPolicy` key, an out-of-range `verifyVotes`, a bad `model`/`effort` on a call-time `injectedFinders` record, or a `require` handed to `lens:capability` that is not an array of strings. | `{ input, value, expected }` — which input was rejected, what arrived, and what was required |
| `E_MANIFEST_UNREADABLE` | `lens:capability` | The plugin manifest did not yield a single `.version` string carrying non-whitespace content — an absent path, a directory, no read permission, no `jq`, malformed JSON, an empty or truncated file, a wrong-typed `.version`, an empty or whitespace-only `.version`, or more than one JSON document. An install-integrity failure and never a fallback: no version is guessed, so a caller's compatibility gate sees a broken install instead of a confident wrong answer. | `{ path, exit }` — the manifest path that could not be read, and the exit status that classified the failure |

Two named invariants bound the **engine's** half of this channel. Both are load-bearing: they are what
keeps a hard-fail path from leaking into a plugin whose whole posture is degrade-and-annotate.
`lens:capability` sits outside both by construction — it dispatches no finder, so it has no stage to
raise after, and the whole skill is new in 1.5.0, so there is no 1.4.3-shaped call that can reach it.

**I-1 — pre-flight only.** An error may be raised **only in pre-flight, before the first finder is dispatched**.
Once ANALYZE has begun, lens degrades and annotates permanently: partial coverage is reported through
`degraded` + `summary`, never through this channel.

**I-2 — new inputs only.** An error is raised only on an input introduced in 1.5.0, so
**a 1.4.3-shaped call can never receive an error envelope**. A malformed pre-1.5.0 input keeps its
normalize-or-drop posture — normalized where it can be, dropped and named in `summary` where it
cannot, exactly as before.

Procedure: `../SKILL.md` — pre-flight validates the 1.5.0 keys, resolves the model plan, and
raises-or-proceeds ahead of every stage below it.

## lens:capability — inputs and returns

The compatibility gate a programmatic caller runs **before** it sends a review: it asks what this
installation supports and gets a machine-checkable answer instead of inferring one from behavior.

| Input | Required | Meaning |
|---|---|---|
| `require` | optional | An **array of strings** — the capability tokens the caller needs. Absent, or present and empty, ⇒ a pure report, which cannot fail *on capability grounds*: nothing was asked for that could be unsatisfied. It can still fail on install integrity — the version read is unconditional, so `E_MANIFEST_UNREADABLE` reaches every call. Present and **not** an array of strings — a bare string, an object, an array holding a non-string — raises `E_INVALID_INPUT` before any matching happens, so a caller's shape bug never comes back disguised as a capability miss. |

**Returns** — two shapes, told apart by the presence of `error`:

| Return | Outcome | Meaning |
|---|---|---|
| `{ name, version, capabilities[], supports{} }` | success | `version` is read from the plugin manifest at call time; `capabilities[]` is the advertised token set; `supports` carries `inputKeys[]`, the named `resolutionRules`, and `effortChannel`. |
| `{ error: { code, message, extra } }` | failure | `E_UNSUPPORTED_CAPABILITY` when a requested token is not advertised — `extra.missing[]` is what was asked for and not found, `extra.have[]` the full advertised set. `E_INVALID_INPUT` when `require` itself is the wrong shape. `E_MANIFEST_UNREADABLE` when the version read fails, so an unreadable install comes back on the same branch key rather than as prose with no `error` at all. All three registered in § Errors. |

The advertised set itself is **not restated here** — it lives at `../../capability/SKILL.md`, the
skill that emits it, because it is the answer rather than the shape. This section declares only what
comes back and how to branch on it.

**Two senses of "capability", and they are unrelated.** The tokens above name **contract features** a
caller may rely on. `capability-locked` in `./finder-registry.md` (and `./adapter-dispatch.md`) names
something else entirely: an adapter's **tool permissions**, constrained read-only at the dispatch
boundary. An adapter's permissions never appear in `capabilities[]`, and a contract token never
governs what tools a finder gets.

## Where the procedure lives

| Procedure | File |
|---|---|
| Engine stages (SCOPE → INTENT → ANALYZE → VERIFY → return), optional progress tracking, key rules | `../SKILL.md` |
| Stage detail: scope resolution, intent precedence, the `<untrusted-user-input>` fence, dedup key, vote aggregation, ranking, the huge-diff + fan-out caps | `./pipeline.md` |
| The 3 finder tiers, per-tier read-only enforcement, normalization into the finding shape | `./finder-registry.md` |
| Reconcile: fingerprints, iteration labels, `delta`, `severityTrend`, orchestrator (compute-only) mode, write-back | `../../review/references/reconcile.md` |
| Render: reconcile-in-memory, review-model assembly, the walkthrough handoff and markdown fallback, write-once | `../../render-review/SKILL.md` |
| The advertised capability set: the version read, the tokens, the input keys, the named resolution rules | `../../capability/SKILL.md` |
| The per-finding shape and the closed `dimension` enum | `../../../schemas/review-findings.schema.json` |

None of those files should restate a shape declared above. One that does has re-forked the surface this
file exists to keep single.
