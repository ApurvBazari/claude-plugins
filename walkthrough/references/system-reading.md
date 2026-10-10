# System reading rules — how a codebase is read into a system map

These rules are shared by the `system-analyzer` agent (which reads a codebase and makes claims), the
`system-verifier` agent (which tries to refute them), and the `document` skill when it has to do both
passes itself. They exist so that a system map built from code shows only what the code supports, says
where each thing was seen, and says what was not looked at.

## 1. No evidence, no box

Every node and every edge carries at least one `path:line` that was actually read in this run. A thing
you believe is there but cannot point to is not returned. This applies to wires as much as to boxes.

## 2. Stated versus inferred

Each claim is one or the other.

| | Means | Typical evidence |
|---|---|---|
| **stated** | a file a machine reads declares it | a build or package manifest, a compose or Kubernetes file, an infrastructure definition, an import, a route registration, the construction of a client or a connection |
| **inferred** | only indirect signals support it | a name, the name of an environment variable, a directory layout, a comment, prose in a README or other docs |

An inferred claim still has evidence: the place where the signal was seen. Put what the evidence shows
in `signal`, in a few words ("env var name `REDIS_URL`", "README says events go through Kafka").

## 3. Bounded reading

Read at most **60 files and 8,000 lines** at container depth. At component depth add **40 files and
6,000 lines** for each container that is opened. Stop when either limit is reached.

Read in this order, so the budget goes to the files that declare structure:

1. build and package manifests, workspace files, lockfile names (not lockfile contents);
2. deploy and infrastructure files: compose files, Dockerfiles, Kubernetes manifests, Procfiles,
   serverless and infrastructure-as-code definitions, CI deploy steps;
3. entry points: `main` files, server start-up, worker start-up, command definitions;
4. wiring: route tables, dependency containers, client and connection construction, message
   producers and consumers;
5. README and docs, last.

## 4. Gaps are listed

Everything skipped is reported: a directory with the reason it was not read. The reasons are
`over-budget`, `unreadable`, `denied` (rule 6), `conflict` (rule 7) and `refuted` (added by the skill
when the verifier rejects a claim). A reader must be able to tell "this part of the system has no box
because nothing is there" from "this part was not looked at".

## 5. Names only

The name of an environment variable may be used as a signal. Its value is never copied: not into a
claim, not into a label, not into a `signal`, not even from a template file. The same holds for any
string that looks like a credential, a token, a key or a connection string.

## 6. Files that are never opened

- `.env` and `.env.<anything>`, except a template named `*.example`, `*.sample`, `*.template` or `*.dist`
  (read those for variable names only);
- `*.pem`, `*.key`, `*.p12`, `*.pfx`, `id_rsa*`, `*.keystore`;
- `secrets.*` and `credentials*`;
- anything under `.git/`, dependency folders (`node_modules/`, `vendor/`, a virtual environment) and
  build output (`dist/`, `build/`, `target/`, `out/`).

A skipped file of the first three kinds is reported as a gap with the reason `denied`. This rule is an
instruction: nothing technical stops a Read. The verifier checks it again (it refutes any claim whose
evidence is such a file), and the page is checked a third time (self-check #27).

## 7. Manifests beat prose

Where a README or other prose and a machine-read file disagree, the machine-read file wins. Report the
disagreement as a gap with the reason `conflict`. A thing only prose mentions is at most inferred.

## 8. Depth

- **Containers (the default).** People who use the system (`actor`), systems outside it (`external`),
  and, inside one boundary that stands for the system, each separately running or separately stored
  thing: an application or service (`service`), a database, cache or bucket (`store`), a queue, topic
  or stream (`queue`).
- **Components (only when asked).** Inside each container the request named (all of them when it named
  none), the main parts and how they call each other (`component`), nested under that container.

Nesting is expressed with `parent`. There is no level field.

## 9. A library has no containers

When nothing in the subject runs or is deployed on its own, set `subjectKind` to `library`: nodes are
packages or modules (`component`), edges are imports with no label, and workspaces or top-level
folders are groups. When the subject has neither deployable units nor more than one package, set
`subjectKind` to `none` and return no nodes.

## 10. Ids and labels

`id` is short, lowercase, stable and unique across the whole result: letters, digits and hyphens.
`label` is what the code calls the thing. `sub` is its technology or role in a few words ("Postgres",
"Go", "worker"). An edge label is a verb phrase of one to three words ("reads", "publishes orders").
`flow` is `async` for a queue, a stream, an event or a background job, and `sync` otherwise.
