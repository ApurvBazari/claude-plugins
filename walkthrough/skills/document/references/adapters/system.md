# Adapter: a codebase → subject-model (system map)

Turns a codebase into a subject model whose centre is a **system map**: the people, containers, stores,
queues and external systems, and the wires between them, each with the place in the code where it was
seen. The reading is done by two read-only agents under one set of rules. The skill applies their
results and builds the model; the shared render stages do the rest.

For this adapter the `document` rule "README is canonical" does **not** apply. Machine-read files beat
prose (reading rule 7).

## When this adapter runs

- the request asks for the subject's architecture, system map, containers or "how it fits together"; or
- the subject is a repository root with at least one build or deploy manifest, and it is neither a
  plugin directory nor a marketplace.

Everything else keeps the route it has in `../gather-subject.md`.

## Step A: Depth

Read the depth from the request. **Containers** is the default. **Components** only when the request
asks for it ("at component level", "open the API", "components of X"); note which containers it named,
if any.

## Step B: Read (agents, or inline)

The reading rules are `system-reading.md` in the plugin's `references/` directory. Your skill names its
path. Pass that path to both agents as `rules`.

1. **Analyze.** Dispatch the `walkthrough:system-analyzer` agent with `root`, `depth`, `containers`
   (when named) and `rules`. It returns one JSON object: `subjectKind`, `depth`, `nodes[]`, `edges[]`,
   `gaps[]`, `read`.
2. **Verify.** Dispatch the `walkthrough:system-verifier` agent with `root`, the analyzer's JSON as
   `claims`, and `rules`. It returns one verdict per claim, nodes first, then edges, in the order given.
3. **If either agent cannot be dispatched** (there is no Agent tool, or the dispatch fails), do the
   work yourself from the same rules file: first the analysis, then, as a separate pass, try to refute
   each of your own claims as the verifier would. Record that the reading was **inline**. Never skip the
   second pass, and never present an inline reading as independently verified.
4. **If a reply is not valid JSON,** ask that agent once to return only the JSON. If it still is not,
   treat it as a failed dispatch (step 3).

## Step C: Apply the verdicts (the skill does this, not the agents)

Match verdicts to claims by position; `ref` is a cross-check.

| Verdict | What happens to the claim |
|---|---|
| `confirmed` | kept as claimed |
| `downgrade` | kept, with `provenance` set to `inferred` |
| `refuted` | dropped, and a gap is added with the reason `refuted` and the verifier's sentence |
| missing, or the verifier could not open the evidence | kept as `inferred`, and a gap is added saying it was not verified |

Then:

- drop every edge that lost an end, and add a gap naming it;
- drop every node whose `parent` was dropped only if the parent was `refuted` as not existing;
  otherwise move the node up to the dropped parent's own parent;
- if `subjectKind` is `none`, or no node is left, stop using this adapter: fall back to the generic
  route in `../gather-subject.md` and tell the user why.

## Step D: Map to the subject-model

| subject-model field | Source | How |
|---|---|---|
| `title` | the repository or directory name | verbatim |
| `tagline` | the manifest's description, else one line you write from the surviving nodes | no claim the reading does not support |
| `summary` | the surviving claims | what the system is made of, in two or three plain sentences |
| `typeTags` | — | `["system", "architecture"]`, plus `"library"` for a package map |
| `nodes` / `edges` | the surviving claims | `provenance: inferred` → `inferred: true`; an edge's `evidence` → its `where[]`; `parent`, `kind`, `sub`, `flow` verbatim |
| `details` | one per surviving node | `kicker` = its kind, `heading` = its label, `summary` = what it is and does, `where[]` = its `evidence`, `points[]` = the `signal`, and for an inferred node "Inferred from: <signal>", `related[]` = the nodes it is wired to |
| `sections` | fixed order | "The system" (the map), "What it is made of" (the reference table), "How this was read", "Gaps" (only when there are gaps) |
| `reference` | the surviving nodes | grouped as "Services", "Data stores", "Queues", "External systems", "People" (a library: "Packages"); `name` = label, `sig` = `sub`, `summary` = one line |
| `links` | the manifest's repository or homepage | omit when there is none |

`install` and `examples` are omitted (omit empty, never stub).

**"How this was read"** is a key–value grid: depth; files and lines read; `Read by agents: analyzer and
verifier.` or `Read inline (agents unavailable): claims were not independently verified.`; how many
claims were confirmed, downgraded and refuted.

**"Gaps"** is one callout per gap: what was not read or was dropped, and why. This section is the
honest edge of the map; never leave it out to make the page look complete.

## Step E: After the page is written

The offer message carries the reading line from "How this was read" as well as the engine line the
render contract asks for. Self-check #27 applies to every page this adapter produces.
