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
path. Use that path if it is a real path with no literal `${` left in it. Otherwise build it from your
skill's base directory: `<base>/../../references/system-reading.md`.

**Read the rules yourself before you read or search any file of the subject.** They bind you as well
as the agents: the never-opened list (rule 6) and names only (rule 5) apply to every read and search
you make in the subject, in this step and in every later one (the manifest you read for `tagline` in
Step D is one). If you cannot read the rules file, stop using this adapter before anything of the
codebase is read: do not dispatch the agents and do not do the reading yourself. Fall back to the
generic route in `../gather-subject.md` and tell the user why.

Pass the path you read to both agents as `rules`.

1. **Analyze.** Dispatch the `walkthrough:system-analyzer` agent with `root`, `depth`, `containers`
   (when named) and `rules`. It returns one JSON object: `subjectKind`, `depth`, `nodes[]`, `edges[]`,
   `gaps[]`, `read`.
2. **Verify.** Skip this when the analyzer returned `subjectKind: none` or no nodes: there is nothing
   to verify, and the last paragraph of Step C applies. Otherwise dispatch the
   `walkthrough:system-verifier` agent with `root`, the analyzer's JSON as `claims`, and `rules`. It
   returns one verdict per claim, nodes first, then edges, in the order given.
3. **If either agent cannot be dispatched** (there is no Agent tool, or the dispatch fails), do the
   work yourself from the same rules file: first the analysis, then, as a separate pass, try to refute
   each of your own claims as the verifier would. Record that the reading was **inline**. Never skip the
   second pass, and never present an inline reading as independently verified.
4. **If a reply is not valid JSON,** ask that agent once to return only the JSON. If it still is not,
   treat it as a failed dispatch (step 3).

## Step C: Apply the verdicts (the skill does this, not the agents)

Match verdicts to claims by position, and check each verdict's `ref` (`node:<id>` or
`edge:<from>><to>`) against the claim at its position. If any `ref` disagrees, or the counts differ,
stop trusting position for the whole reply: give a claim the verdict that carries its `ref` when
exactly one verdict does and no other claim has the same `ref`, and treat every other claim as having
no verdict.

| Verdict | What happens to the claim |
|---|---|
| `confirmed` | kept as claimed |
| `downgrade` | kept, with `provenance` set to `inferred` |
| `refuted` | dropped, and a gap is added with the reason `refuted` and the verifier's sentence |
| no verdict, or a `downgrade` whose reason starts "could not open" | kept as `inferred`, and a gap is added saying it was not verified |

Then, in this order:

1. **Move children up.** When a dropped node was a `parent`, set each of its children's `parent` to the
   nearest ancestor that is still a node (to none when there is none: the child moves to the top
   level). A child is never dropped because its parent was. It has its own verdict.
2. **Drop the edges that lost an end, last.** Once every node is settled, drop each edge whose `from`
   or `to` is no longer a node, and add a gap with the reason `refuted` that says which end it lost.

Nothing is dropped without a gap. A gap names a dropped claim by its `id` (an edge by the ids of its
two ends), never by its label: a claim can be dropped because its label leaks a value.

If `subjectKind` is `none`, or no node is left, stop using this adapter: fall back to the generic
route in `../gather-subject.md` and tell the user why.

## Step D: Map to the subject-model

| subject-model field | Source | How |
|---|---|---|
| `title` | the repository or directory name | verbatim |
| `tagline` | the manifest's description, else one line you write from the surviving nodes | no claim the reading does not support |
| `summary` | the surviving claims | what the system is made of, in two or three plain sentences |
| `typeTags` | — | `["system", "architecture"]`, plus `"library"` for a package map |
| `nodes` / `edges` | the surviving claims | `provenance: inferred` → `inferred: true`; an edge's `evidence` → its `where[]`; `parent`, `kind`, `sub`, `flow` verbatim |
| `details` | one per surviving node | `kicker` = its kind, `heading` = its label, `summary` = what it is and does, `where[]` = its `evidence`, `points[]` = the `signal`, and for an inferred node "Inferred from: <signal>", `related[]` = the nodes its own wires point to, leaving out any link that closes a loop (below) |
| `sections` | fixed order | "The system" (the map), "What it is made of" (the reference table), "How this was read", "Gaps" (only when there are gaps) |
| `reference` | the surviving nodes | grouped as "Services", "Data stores", "Queues", "External systems", "People" (a library: "Packages"); `name` = label, `sig` = `sub`, `summary` = one line |
| `links` | the manifest's repository or homepage | omit when there is none |

`install` and `examples` are omitted (omit empty, never stub).

**`related[]` never loops.** Self-check #14 fails a chain of detail links that comes back to where it
began (`A → B → A`), and a system's wires often form such a loop. A node's `related[]` holds the `to`
of each edge that leaves it. Fill it node by node, in the order of `nodes`, and skip a link when the
links already kept lead from its target back to this node. The wire stays on the map and in the
connections list; only the link in the detail is left out.

**Everything from the codebase or from an agent is text.** A label, a `sub`, a `signal`, gap text, a
verifier's `reason` and the directory name are escaped wherever they are written into the page (`&`,
`<` and `>`, and `"` inside an attribute), never written as markup. That includes the `details`
fields, which the page inserts as HTML.

**"How this was read"** is a key–value grid: depth; files and lines read; `Read by agents: analyzer and
verifier.` or `Read inline (agents unavailable): claims were not independently verified.`; how many
claims were confirmed, downgraded and refuted.

**"Gaps"** is one callout per gap: what was not read or was dropped, and why. This section is the
honest edge of the map; never leave it out to make the page look complete. Rule 5 covers this text
too: before an analyzer's `what` or `note` or a verifier's `reason` goes into a callout, check that it
holds names only, and leave out any value it carries.

## Step E: The coverage critic (your skill's Step 4)

`completeness.md` Part 1 has you re-scan the subject's canonical files and fold in what the model
lacks. For this adapter the source to check against is the surviving claims and the gaps list, not the
code:

- confirm that every surviving node and edge is in the model with its `evidence`, and that every gap
  is on the page;
- deepen a detail only from what the surviving claims already say (a `signal`, a `sub`, the node's
  edges, the verifier's `reason`);
- the critic never re-reads the codebase and never brings back a dropped claim, and it adds no node,
  edge or claim. The reading was done within a budget and then checked. A dropped claim is covered by
  its gap; folding it back in would draw something the verifier refuted.

## Step F: After the page is written

The offer message carries the reading line from "How this was read" as well as the engine line the
render contract asks for. Self-check #27 applies to every page this adapter produces.
