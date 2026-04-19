# LSP Plugin Catalog

Maps detected project languages to official Claude Code marketplace LSP plugins used by Phase 7c of the generation pipeline and by `detect-lsp-signals.sh`. Each plugin ships its own `lspServers` config inline in its `plugin.json` — onboard does **not** generate any project-level LSP config files.

When `onboard:init` detects files of these extensions, wizard Phase 5.6 presents a checkbox list of the matching plugins. User-selected entries are installed via `bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-plugins.sh" <plugin-name>`.

See `mcp-guide.md` for the sibling MCP catalog pattern.

## Catalog

| Language label | Marketplace plugin | File extensions | Language-server binary | Install prereq |
|---|---|---|---|---|
| `typescript` | `typescript-lsp` | `.ts`, `.tsx`, `.mts`, `.cts`, `.js`, `.jsx`, `.mjs`, `.cjs` | `typescript-language-server` | `npm install -g typescript-language-server typescript` |
| `go` | `gopls-lsp` | `.go` | `gopls` | `go install golang.org/x/tools/gopls@latest` (ensure `$GOPATH/bin` in PATH) |
| `rust` | `rust-analyzer-lsp` | `.rs` | `rust-analyzer` | `rustup component add rust-analyzer` |
| `c-cpp` | `clangd-lsp` | `.c`, `.cpp`, `.cc`, `.cxx` | `clangd` | macOS: `brew install llvm` · Linux: distro package (`clangd` or `llvm`) |
| `csharp` | `csharp-lsp` | `.cs` | OmniSharp / `csharp-ls` | Ships with `dotnet` SDK; see plugin README for variants |
| `java` | `jdtls-lsp` | `.java` | Eclipse JDT Language Server | See plugin README — JDK 17+ required |
| `kotlin` | `kotlin-lsp` | `.kt`, `.kts` | `kotlin-language-server` | See plugin README |
| `lua` | `lua-lsp` | `.lua` | `lua-language-server` | `brew install lua-language-server` or distro package |
| `php` | `php-lsp` | `.php` | Intelephense / phpactor | `npm install -g intelephense` |
| `python` | `pyright-lsp` | `.py` | `pyright` | `npm install -g pyright` |
| `ruby` | `ruby-lsp` | `.rb` | `ruby-lsp` gem | `gem install ruby-lsp` |
| `swift` | `swift-lsp` | `.swift` | `sourcekit-lsp` | Ships with Swift toolchain (`xcode-select --install` on macOS) |

## Aggregation notes

- `typescript-lsp` covers both TypeScript and JavaScript — the catalog row lists all eight extensions. Pure JS projects get the same plugin (the name is historical; the plugin config handles both).
- `clangd-lsp` handles mixed C / C++ projects. The detection row omits `.h` / `.hpp` on purpose — header files alone aren't a reliable signal that clangd is wanted.

## Signal strictness

Any file of a listed extension triggers the plugin candidate (no threshold). Rationale: the wizard's Phase 5.6 checklist is the natural filter — users uncheck any plugins they don't want. For sorting the checklist, `detect-lsp-signals.sh` emits a `fileCount` field and sorts candidates descending so the primary language sits at the top with its box checked by default.

## Adding a new language

When Anthropic ships a new official `-lsp` plugin:

1. Add a row to the catalog table above with the language label, plugin name, extensions, binary name, and install prereq.
2. Add a corresponding entry to the `LANGUAGES` array in `onboard/scripts/detect-lsp-signals.sh` (the script itself; plugin-root-relative paths at runtime use `${CLAUDE_PLUGIN_ROOT}/scripts/detect-lsp-signals.sh`).
3. Bump onboard minor version (language coverage is additive — no migration needed).
4. No changes needed in `wizard/SKILL.md` or `generation/SKILL.md` — both consume the script's JSON output generically.

## Rename / deprecation handling

If a marketplace plugin is renamed (e.g., `rust-analyzer-lsp` → `rust-lsp`), only two files change:

1. This catalog — update the plugin column.
2. `detect-lsp-signals.sh` — update the matching row in the `LANGUAGES` array.

`install-plugins.sh` receives the new name from the wizard output and calls `claude plugin install <new-name>` — no code change needed there.

## Relationship to `.lsp.json`

Claude Code's `.lsp.json` format is a **plugin-level** artifact (ships inside each `-lsp` plugin's `plugin.json` under the `lspServers` key). Onboard never emits a project-root `.lsp.json` — installing the right plugin is the complete story.

Reference: [Claude Code Plugins Reference](https://code.claude.com/docs/en/plugins-reference).
