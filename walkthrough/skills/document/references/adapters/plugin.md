# Adapter: Claude Code plugin → subject-model

Extract a plugin directory into the `subject-model`.

| subject-model field | Source | How |
|---|---|---|
| `title` | `plugin.json` `name` | verbatim |
| `tagline` | `plugin.json` `description` | verbatim (one line) |
| `summary` | `README.md` intro | the opening paragraph(s), condensed to plain language |
| `typeTags` | `plugin.json` `keywords` | pick 2–4 most descriptive |
| `install` | README install block | the `claude plugin install <name>@apurvbazari-plugins` line + any setup skill |
| `sections` | README H2 sections | one section per major README heading; `prose` summarizes it |
| `nodes`/`edges` | README architecture/flow prose | build a flow or architecture diagram when the plugin has a clear pipeline (e.g. walkthrough's 5 stages, notify's hook flow) |
| `reference` | `skills/*/SKILL.md` frontmatter (`name`, `description`), `agents/*.md`, documented config knobs | group as "Skills", "Agents", "Config", "Hooks" |
| `examples` | README example/transcript blocks | verbatim fenced blocks |
| `links` | repo tree URL, community marketplace, README | `https://github.com/ApurvBazari/claude-plugins/tree/main/<plugin>` |
| `details` | per-skill / per-node detail | optional expandable bodies keyed by node or reference id |

Read each `skills/<name>/SKILL.md` only for its frontmatter `name` + `description` (the reference
row) unless a skill warrants a `details` entry. Do not paste skill bodies.
