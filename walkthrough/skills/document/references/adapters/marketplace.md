# Adapter: marketplace → subject-model (landing page)

The marketplace landing is the collection-as-subject. Inputs: `.claude-plugin/marketplace.json`
(the plugin list) + root `README.md` (positioning, install routes, workflow diagram).

| subject-model field | Source | How |
|---|---|---|
| `title` | "claude-plugins" | the marketplace name |
| `tagline` | root README opening blockquote | the one-line pitch |
| `summary` | root README intro | condensed |
| `typeTags` | — | `["marketplace", "claude-code"]` |
| `install` | root README Quick Start | the `marketplace add` + per-plugin install lines |
| `sections` | root README sections | "Plugins at a glance", "How they fit together", "Companion plugins" |
| `reference` | `marketplace.json` `plugins[]` | one row per plugin: `name`, `version`, `description` |
| `links` | root README Links section | docs, community marketplace, repo |

## The plugin-card grid (bespoke component)

The landing's centerpiece is a grid of plugin cards (one per `marketplace.json` entry), each linking
to that plugin's page (`./<plugin>/`). No catalog component is a card grid, so compose a **bespoke**
one per `authoring-guide.md` §"compose a new component":
- Use design-system tokens only (no raw hex), the type scale, and `--space-*` spacing.
- Each card: plugin name (h3), `description`, a `keywords` chip row, and a relative link `./<plugin>/`.
- Must pass the authoring-guide "looks-native" checklist (indistinguishable from catalog components).

Each card's link is **relative** (`./onboard/`) so it survives the `/claude-plugins/` Pages base path.
