# Adapter: a codebase → subject-model (system map)

Turns a codebase into a subject model whose centre is a **system map**: the people, containers, stores,
queues and external systems, and the wires between them, each with the place in the code where it was
seen. The reading is done by two read-only agents under one set of rules. The skill applies their
results and builds the model; the shared render stages do the rest.

For this adapter the `document` rule "README is canonical" does **not** apply. Machine-read files beat
prose (reading rule 7).

## When this adapter runs

- the request asks for the subject's architecture, system map, containers, components or "how it fits
  together"; or
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
Step D is one). If you cannot read the rules file, stop the whole skill here: read nothing of the
codebase, dispatch no agent and build no page. Tell the user that the reading rules could not be read
and which paths you tried. Do not fall back to the generic route: it would read the subject with no
never-opened list.

Pass the path you read to both agents as `rules`.

1. **Analyze.** Dispatch the `walkthrough:system-analyzer` agent with `root`, `depth`, `containers`
   (when named) and `rules`. It returns one JSON object: `subjectKind`, `depth`, `nodes[]`, `edges[]`,
   `gaps[]`, `read`. If it reports that it could not read the rules, go to step 5.
2. **Verify.** Skip this when the analyzer returned `subjectKind: none` or no nodes: there is nothing
   to verify, and the last paragraph of Step C applies. Otherwise dispatch the
   `walkthrough:system-verifier` agent with `root`, the analyzer's JSON as `claims`, and `rules`. It
   returns one verdict per claim, nodes first, then edges, in the order given. If it reports that it
   could not read the rules, go to step 5.
3. **If either agent cannot be dispatched** (there is no Agent tool, or the dispatch fails), do the
   work yourself from the same rules file: first the analysis, then, as a separate pass, try to refute
   each of your own claims as the verifier would. Record that the reading was **inline**. Never skip the
   second pass, and never present an inline reading as independently verified. When only the verifier
   failed, the analysis is not redone: keep the analyzer's claims and do the second pass on them.
4. **If a reply is not valid JSON,** ask that agent once to return only the JSON. If it still is not,
   treat it as a failed dispatch (step 3).
5. **If an agent reports that it could not read the rules,** treat its reply as a failed dispatch
   (step 3): you have read the rules, so you can do that pass yourself. The analyzer reports it with
   `subjectKind: none` and one gap whose `note` is "could not open the reading rules". The verifier
   reports it by giving every verdict that sentence as its `reason`. Neither reply is a result: do not
   fall back to the generic route on the first, and do not apply the second as verdicts.

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

**Before you keep any claim, whatever its verdict,** check every path in its `evidence` against the
never-opened list (rule 6), by name and without opening anything, and check that it is inside `root`
(not absolute, no leading `~`, no `..` segment). The verifier makes these checks too, but its reply
cannot show that it made them, and a claim with no verdict was never checked at all.
If any path is on the list or outside `root`, drop the claim instead, whatever else it cites and
whatever its verdict, and add a gap with the reason `refuted` that names the claim by its `id` and
says its evidence was a never-opened file or a path outside `root`. Such a path is never cited as
evidence.

Then, in this order:

1. **Move children up.** When a dropped node was a `parent`, set each of its children's `parent` to the
   nearest ancestor that is still a node (to none when there is none: the child moves to the top
   level). A child is never dropped because its parent was. It has its own verdict.
2. **Drop the edges that lost an end, last.** Once every node is settled, drop each edge whose `from`
   or `to` is no longer a node, and add a gap with the reason `refuted` that says which end it lost.

Nothing is dropped without a gap. A gap names a dropped claim by its `id` (an edge by the ids of its
two ends), never by its label: a claim can be dropped because its label leaks a value.

If `subjectKind` is `none`, or no node is left, stop using this adapter and tell the user why. Fall
back to the plugin adapter when the subject is a plugin directory, to the marketplace adapter when it
is the marketplace, and otherwise to the generic route in `../gather-subject.md`. Rules 5 and 6 still
bind you on that route: the never-opened paths stay unread and unsearched, and no value is copied.

## Step D: Map to the subject-model

| subject-model field | Source | How |
|---|---|---|
| `title` | the repository or directory name | as it stands after the names-only check below |
| `tagline` | the manifest's description, else one line you write from the surviving nodes | no claim the reading does not support |
| `summary` | the surviving claims | what the system is made of, in two or three plain sentences |
| `typeTags` | — | `["system", "architecture"]`, plus `"library"` for a package map |
| `nodes` / `edges` | the surviving claims | `provenance: inferred` → `inferred: true`; an edge's `evidence` → its `where[]`; `parent`, `kind`, `flow` verbatim; `sub` as it stands after the names-only check below |
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

**Everything from the codebase or from an agent is text**, such as a label, a `sub`, a `signal`, an
evidence path, an analyzer's `what` or `note`, a verifier's `reason` and the directory name. Two
things hold for every such string, wherever it ends up:

- **Names only.** Before it enters the model, check that it holds no value (rule 5), and leave out any
  value it carries. If nothing is left of a label, name the node by its `id`. The verifier's leak
  check covered only the `label`, `sub` and `signal` of the claims it judged, so a gap, a `reason` and
  a claim kept with no verdict reach you unchecked.
- **Escaped.** When it is written into the page it is escaped (`&`, `<` and `>`, and `"` inside an
  attribute), never written as markup. That includes the `details` fields, which the page inserts as
  HTML.

**"How this was read"** is a key–value grid: depth; files and lines read; `Read by agents: analyzer and
verifier.` or `Read inline (agents unavailable): claims were not independently verified.`; how many
claims were confirmed, downgraded and refuted.

**"Gaps"** is one callout per gap: what was not read or was dropped, and why. This section is the
honest edge of the map; never leave it out to make the page look complete.

## Step E: The coverage critic (your skill's Step 4)

`completeness.md` Part 1 has you re-scan the subject's canonical files and fold in what the model
lacks. For this adapter the source to check against is the surviving claims and the gaps list, not the
code:

- confirm that every surviving node and edge is in the model with its `evidence`, and that every gap
  is in the model's "Gaps" section; add any that is missing;
- deepen a detail only from what the surviving claims already say (a `signal`, a `sub`, the node's
  edges, the verifier's `reason`), each checked for values as Step D says;
- the critic never re-reads the codebase and never brings back a dropped claim, and it adds no node,
  edge or claim that is not among the surviving claims. The reading was done within a budget and then
  checked. A dropped claim is covered by its gap; folding it back in would draw something the verifier
  refuted.

## Step F: After the page is written

The offer message carries the reading line from "How this was read" as well as the engine line the
render contract asks for. Its coverage note (`completeness.md` Part 2) reports what was not read as
the gaps: on this adapter "not read" is the honest reason for that omission, not a process excuse.
Self-check #27 applies to every page this adapter produces.
