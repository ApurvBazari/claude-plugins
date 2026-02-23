# Config Extraction & Pattern Scanning Guide

Reference for deep config file reading and codebase pattern scanning during analysis. Use this to extract actual enforced standards and observed conventions — not generic templates.

---

## Section 1: Config File Discovery

Complete map of config file locations by ecosystem. Search for all applicable files using Glob.

### JavaScript / TypeScript

- **ESLint**: `.eslintrc.js`, `.eslintrc.cjs`, `.eslintrc.json`, `.eslintrc.yml`, `eslint.config.js`, `eslint.config.mjs`, `eslint.config.ts`, `"eslintConfig"` in `package.json`
- **Prettier**: `.prettierrc`, `.prettierrc.json`, `.prettierrc.yml`, `.prettierrc.js`, `.prettierrc.cjs`, `prettier.config.js`, `"prettier"` in `package.json`
- **Biome**: `biome.json`, `biome.jsonc`
- **TypeScript**: `tsconfig.json`, `tsconfig.*.json` (build, app, etc.)
- **Tailwind**: `tailwind.config.js`, `tailwind.config.ts`, `tailwind.config.cjs`
- **EditorConfig**: `.editorconfig`

### Python

- **Ruff**: `ruff.toml`, `.ruff.toml`, `pyproject.toml [tool.ruff]`
- **Black**: `pyproject.toml [tool.black]`, `.black.toml`
- **MyPy**: `mypy.ini`, `.mypy.ini`, `pyproject.toml [tool.mypy]`, `setup.cfg [mypy]`
- **Flake8**: `.flake8`, `setup.cfg [flake8]`, `tox.ini [flake8]`
- **Pylint**: `.pylintrc`, `pyproject.toml [tool.pylint]`
- **isort**: `.isort.cfg`, `pyproject.toml [tool.isort]`, `setup.cfg [isort]`

### Go

- **golangci-lint**: `.golangci.yml`, `.golangci.yaml`, `.golangci.toml`
- **staticcheck**: `staticcheck.conf`

### Rust

- **rustfmt**: `rustfmt.toml`, `.rustfmt.toml`
- **Clippy**: `clippy.toml`, `.clippy.toml`

### Ruby

- **RuboCop**: `.rubocop.yml`, `.rubocop_todo.yml`

---

## Section 2: What to Extract Per Config Type

For each config type, read specific keys and translate them into rule generation guidance.

### TypeScript (`tsconfig.json`)

| Key | Rule Implication |
|-----|-----------------|
| `strict: true` | Never use `any`, always handle `null`/`undefined` |
| `noImplicitAny: true` | All variables and parameters must have explicit or inferable types |
| `strictNullChecks: true` | Always check for `null`/`undefined` before accessing properties |
| `paths` (alias patterns) | Use path aliases (e.g., `@/components`) instead of deep relative imports |
| `target` | Determines which JS features are available natively |
| `module` | Determines import/export syntax (ESM vs CJS) |
| `jsx` | React JSX transform mode — affects whether React import is needed |

### ESLint

Group enabled rules by category. Extract rules set to `error` vs `warn` to understand severity intent.

Key categories to extract:
- **Naming conventions**: `@typescript-eslint/naming-convention` — exact casing rules
- **Import rules**: `import/order`, `import/no-cycle`, `import/no-unresolved`
- **React hooks**: `react-hooks/rules-of-hooks`, `react-hooks/exhaustive-deps`
- **Unused code**: `no-unused-vars`, `no-unused-imports`
- **Consistency patterns**: `consistent-return`, `eqeqeq`, `no-console`
- **Plugin-specific**: any custom or framework-specific rules

Note which rules are `error` (hard enforcement) vs `warn` (soft guidance).

### Prettier / Formatters

Extract settings — these become CLAUDE.md conventions, NOT path-scoped rules (formatters auto-fix these):

- `printWidth` — line length limit
- `singleQuote` — quote style
- `semi` — semicolon usage
- `tabWidth` — indentation size
- `trailingComma` — trailing comma style
- `arrowParens` — arrow function parentheses

### Biome

Similar to ESLint + Prettier combined. Extract:
- Linter rules: enabled rules and their severity
- Formatter settings: indent style, line width, quote style

### Ruff / Black (Python)

- `line-length` — maximum line length
- `target-version` — minimum Python version
- `select` / `extend-select` — enabled rule categories
- `ignore` — disabled rules
- `isort` settings if integrated

### MyPy

| Key | Rule Implication |
|-----|-----------------|
| `strict: true` | All functions must have type annotations |
| `disallow_untyped_defs: true` | No function without type hints |
| `ignore_missing_imports: true` | Third-party stubs may be missing — note but don't flag |

### Tailwind

- `content` paths — which files Tailwind scans
- `theme.extend` — custom design tokens (colors, spacing, fonts)
- `plugins` list — available utility extensions

### golangci-lint

- Enabled linters list (e.g., `govet`, `errcheck`, `staticcheck`, `gosimple`)
- Per-linter settings and exclusions
- Severity configuration

### RuboCop

- Enabled/disabled cops
- Custom configuration per cop
- `AllCops` settings (TargetRubyVersion, NewCops)

---

## Section 3: Codebase Usage Pattern Scanning

Beyond configs, sample 5-10 representative source files to identify actual patterns in use.

### Import & Module Patterns

- **Barrel exports**: Presence of `index.ts`/`index.js` re-export files — count how many exist
- **Path aliases vs relative imports**: Ratio of `@/...` imports vs `../../` imports
- **Import ordering**: Are imports grouped by external/internal/relative? Consistent pattern?

### Component Patterns (React/Vue/Svelte)

- **Component style**: Functional + hooks vs class components vs HOC — what percentage of each?
- **`forwardRef` usage**: How frequently used?
- **Props pattern**: `interface` vs `type` for props, destructured in signature vs `props` object
- **State management**: Local `useState` vs store (Redux, Zustand, Jotai, etc.)

### Styling Patterns

- **Tailwind**: Utility-only vs `@apply` usage, `cn()`/`clsx()` composition pattern, co-located vs global
- **CSS Modules**: Naming convention (`.module.css` vs `.module.scss`), usage pattern
- **styled-components/Emotion**: Theme usage, component naming convention

### Error Handling

- **Try-catch vs Result/Either patterns**
- **Custom error classes** vs raw `throw new Error()`
- **Structured logging**: Winston, Pino, or similar
- **API error response format**: Is there a consistent shape?

### Naming Conventions

- **File naming**: PascalCase vs kebab-case vs camelCase — per file type
- **Variable/function naming**: camelCase, snake_case, etc.
- **Test file naming**: `.test.ts` vs `.spec.ts` vs `_test.go`

### Architecture & Layer Boundaries

- **Import direction**: Do lower layers import from higher layers? (violation detection)
- **Organization**: Feature-based vs layer-based
- **API route structure**: RESTful naming, versioning pattern

---

## Section 4: Output Format

Add this section to the analysis report under `Config & Pattern Analysis`:

```
## Config & Pattern Analysis

### Tooling Configs Found
- [tool]: [file path] — [key settings extracted]

### Enforced Rules (from linters/formatters)
- [category]: [specific rules with severity]

### Observed Patterns (from code sampling)
- [pattern type]: [what was found, with evidence from sampled files]

### Formatter Settings (for CLAUDE.md, not rules)
- [setting]: [value] — auto-fixed by [tool], document but don't make a rule

### Rule Generation Hints
- [concrete suggestions for rules capturing intent beyond linter enforcement]
```

**Key distinction**: Enforced Rules are things linters check automatically. Rule Generation Hints are for patterns linters CANNOT enforce — architectural boundaries, naming intent, error handling philosophy, component composition patterns, import boundaries. These are the most valuable rules to generate.
