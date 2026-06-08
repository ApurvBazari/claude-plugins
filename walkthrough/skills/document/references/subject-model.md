# Subject Model — the structured shape that drives a subject walkthrough

`document` renders a **subject** (a plugin, a library, a subsystem, the marketplace itself) into the
same house style as a session walkthrough. Before any HTML, synthesize the subject into this model.
Field names are load-bearing — the shared ones map to the same catalog components as the session
model (`authoring-guide.md` § 1), so reused components render them with no change.

## Part A — Annotated schema

```jsonc
{
  // --- chrome (always rendered) ---
  "title":    "...",                 // doc <title> + hero <h1>
  "tagline":  "...",                 // one-line positioning under the h1 (the "what is this")
  "summary":  "...",                 // hero lede — a short plain-language paragraph
  "typeTags": ["plugin", "cli"],     // → hero chips (kind of subject)

  // install → annotated code block(s) in a "Quick start" section. Omit for subjects with no install.
  "install": [ { "label": "From the marketplace", "code": "claude plugin install onboard@apurvbazari-plugins" } ],

  // The document spine — same shape as session-model. Prose carries the narrative.
  "sections": [ { "id": "overview", "heading": "...", "prose": "...", "components": ["flow"] } ],

  // nodes[] + edges[] → diagram (flow / architecture / dependency / concept) — reused unchanged.
  "nodes": [ { "id": "...", "label": "...", "kind": "component|step|concept" } ],
  "edges": [ { "from": "<id>", "to": "<id>", "label": "" } ],

  // reference[] → the structured API/command surface. Grouped rows render as a comparison table
  // (Comparison table component) or a key–value metadata grid. `group` buckets entries
  // (e.g. "Skills", "Config", "Hooks"); `name` is the entry, `sig` an optional invocation form.
  "reference": [ { "group": "Skills", "name": "/walkthrough:create", "sig": "[focus]", "summary": "..." } ],

  // examples[] → annotated code blocks / tabs. `body` is the snippet or transcript.
  "examples": [ { "title": "First run", "body": "/walkthrough:create\n→ writes .claude/walkthrough/...html" } ],

  // links[] → external links rendered in a key–value grid or footer (repo, docs, marketplace).
  "links": [ { "label": "Source", "href": "https://github.com/ApurvBazari/claude-plugins/tree/main/walkthrough" } ],

  // details{} → detail-surface store, keyed by node/reference id; openSurface('<id>') routes to a pane
  // (light) or a sheet (rich). Same structured contract as session-model: {kicker, heading, summary,
  // where[], code[]?, points[]?, related[]?, surface?, components[]} — see create's session-model.md +
  // authoring-guide.md § 3. `where[]` holds path:line anchors when real source locations exist.
  "details": { "<id>": { "kicker": "...", "heading": "...", "summary": "...", "where": ["path:line"], "related": ["<id>"] } }
}
```

Dropped vs session-model (session-only): `decisions`, `files`, `timeline`, `metrics`, `openQuestions`.

## Part B — Worked example: documenting the `notify` plugin

A complete, realistic model — no placeholders.

```jsonc
{
  "title": "notify",
  "tagline": "Desktop notifications when Claude Code finishes a task — duration-filtered so short tasks don't spam you.",
  "summary": "notify fires a macOS or Linux system notification when Claude stops, carrying a repo/branch subtitle and Claude's actual last message. A per-event minimum-duration filter suppresses notifications for fast responses, so it only interrupts you when Claude has genuinely been working.",
  "typeTags": ["plugin", "notifications", "hooks"],

  "install": [
    { "label": "From this marketplace", "code": "claude plugin install notify@apurvbazari-plugins" },
    { "label": "Then configure", "code": "/notify:setup" }
  ],

  "sections": [
    { "id": "overview", "heading": "What it does", "prose": "A Stop-hook wrapper around terminal-notifier (macOS) / notify-send (Linux). Setup detects your platform, installs the notifier if needed, and wires the hook.", "components": [] },
    { "id": "flow", "heading": "How a notification fires", "prose": "Claude stops → the Stop hook runs notify.sh → it checks the elapsed duration against minDurationSeconds → if over threshold, it builds a repo/branch subtitle and posts the notification.", "components": ["flow"] }
  ],

  "nodes": [
    { "id": "stop", "label": "Claude stops", "kind": "step" },
    { "id": "hook", "label": "Stop hook → notify.sh", "kind": "component" },
    { "id": "filter", "label": "duration filter", "kind": "component" },
    { "id": "post", "label": "system notification", "kind": "step" }
  ],
  "edges": [
    { "from": "stop", "to": "hook", "label": "" },
    { "from": "hook", "to": "filter", "label": "elapsed vs minDurationSeconds" },
    { "from": "filter", "to": "post", "label": "over threshold" }
  ],

  "reference": [
    { "group": "Skills", "name": "/notify:setup", "sig": "", "summary": "Detect platform, install notifier, wire the Stop hook" },
    { "group": "Skills", "name": "/notify:check", "sig": "", "summary": "Health-check the install + hook + config" },
    { "group": "Skills", "name": "/notify:uninstall", "sig": "", "summary": "Remove the hook + config" },
    { "group": "Config", "name": "minDurationSeconds", "sig": "per-event", "summary": "Suppress notifications for responses faster than N seconds" }
  ],

  "examples": [
    { "title": "Suppressed vs delivered", "body": "# 3s task → suppressed (under minDurationSeconds)\n# 90s task → delivered: 'claude-plugins / develop — <last message>'" }
  ],

  "links": [
    { "label": "README", "href": "https://github.com/ApurvBazari/claude-plugins/tree/main/notify" },
    { "label": "Install from community", "href": "https://github.com/anthropics/claude-plugins-community" }
  ],

  "details": {
    "filter": { "kicker": "Filter", "heading": "Duration filter", "summary": "minDurationSeconds is read per event; the wrapper compares the hook's elapsed time and returns early (exit 0) below threshold, so fast turns never notify.", "where": ["notify/scripts/notify.sh"], "related": ["hook"] }
  }
}
```

## This model is not a file

Synthesized in-memory before any HTML; it drives component selection via `authoring-guide.md`.
Not written to disk.
