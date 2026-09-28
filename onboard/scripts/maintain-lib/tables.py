"""Fixed tables for maintain-detect.

LANGUAGES and VENDOR_DIRS are copies of scripts/detect-lsp-signals.sh, MCP_SIGNALS of
scripts/detect-mcp-signals.sh, CONFIG_PATTERNS of scripts/detect-config-changes.sh.
Those scripts are not refactored (spec § 5); tests/onboard/test_maintain_tables_parity.sh
fails when a copy drifts from its source.
"""
import re

VENDOR_DIRS = frozenset([
    "node_modules", ".git", "dist", "build", "target", ".venv", "venv",
    "__pycache__", "vendor", ".next", ".cache",
])

# (language, LSP plugin, extensions) — the same rows as detect-lsp-signals.sh.
LANGUAGES = [
    ("typescript", "typescript-lsp", (".ts", ".tsx", ".mts", ".cts", ".js", ".jsx", ".mjs", ".cjs")),
    ("go", "gopls-lsp", (".go",)),
    ("rust", "rust-analyzer-lsp", (".rs",)),
    ("c-cpp", "clangd-lsp", (".c", ".cpp", ".cc", ".cxx")),
    ("csharp", "csharp-lsp", (".cs",)),
    ("java", "jdtls-lsp", (".java",)),
    ("kotlin", "kotlin-lsp", (".kt", ".kts")),
    ("lua", "lua-lsp", (".lua",)),
    ("php", "php-lsp", (".php",)),
    ("python", "pyright-lsp", (".py",)),
    ("ruby", "ruby-lsp", (".rb",)),
    ("swift", "swift-lsp", (".swift",)),
]

# The one source-file extension list (spec § 7): every extension in LANGUAGES.
SOURCE_EXTS = frozenset(ext for _, _, exts in LANGUAGES for ext in exts)

# Non-JS dependency manifests: reported as manifest-changed, never parsed (D11).
MANIFEST_NAMES = frozenset(["pyproject.toml", "Cargo.toml", "go.mod", "Gemfile"])
MANIFEST_RE = re.compile(r"^requirements.*\.txt$")

# The same basenames detect-config-changes.sh reacts to, minus pyproject.toml (a manifest here).
CONFIG_PATTERNS = [
    re.compile(r"^tsconfig.*\.json$"),
    re.compile(r"^\.eslintrc"),
    re.compile(r"^eslint\.config"),
    re.compile(r"^prettier\.config"),
    re.compile(r"^\.prettierrc"),
    re.compile(r"^biome\.json$"),
    re.compile(r"^ruff\.toml$"),
    re.compile(r"^\.ruff\.toml$"),
]

# Basenames that never act as a recheck key (D28): lockfiles and tool configs.
LOCKFILES = frozenset([
    "package-lock.json", "pnpm-lock.yaml", "yarn.lock", "bun.lockb", "bun.lock",
    "Cargo.lock", "Gemfile.lock", "poetry.lock", "go.sum", "composer.lock", "uv.lock",
])
TOOL_CONFIG_RE = re.compile(r"^(.+\.config\.[A-Za-z0-9]+|\.[A-Za-z0-9_-]+rc(\.[A-Za-z0-9]+)?)$")

# MCP signals — the same predicates as detect-mcp-signals.sh (root package.json only).
# `@remix-run/` and the unescaped `.` in `@builder.io/qwik` are copied as-is: parity with
# the shipped script beats fixing it here (flagged as an adjacent issue, not fixed).
FRONTEND_RE = re.compile(
    r'"(react|next|vue|svelte|@sveltejs/kit|astro|@remix-run/|solid-js|nuxt|@builder.io/qwik)":')
PRISMA_DEP_RE = re.compile(r'"(@prisma/client|prisma)":')
MCP_SIGNALS = [
    ("github", ".github/workflows", lambda v: v.has_dir(".github/workflows")),
    ("vercel", "vercel-config-or-dep",
     lambda v: v.has_file("vercel.json") or '"@vercel/' in v.root_package_text),
    ("prisma", "prisma-dir-or-dep",
     lambda v: v.has_dir("prisma") or PRISMA_DEP_RE.search(v.root_package_text) is not None),
    ("supabase", "supabase-dir-or-dep",
     lambda v: v.has_dir("supabase") or '"@supabase/' in v.root_package_text),
    ("chrome-devtools-mcp", "frontend-framework",
     lambda v: FRONTEND_RE.search(v.root_package_text) is not None),
]

# Built-in skills with a dependency signal (built-in-skills-catalog.md): today only /claude-api.
BUILTIN_SKILL_SIGNALS = [("/claude-api", frozenset(["anthropic", "@anthropic-ai/sdk"]))]

# The mention predicate's runner words (D24).
RUNNERS = frozenset(["npm", "pnpm", "yarn", "bun", "npx", "turbo", "nx"])

# recheck-line: the per-run cap (owner's question budget, chosen 2026-09-27) and the
# stems too generic to act as a key.
RECHECK_CAP = 8
GENERIC_STEMS = frozenset([
    "api", "app", "cli", "client", "common", "config", "core", "lib", "node", "plugin",
    "react", "sdk", "server", "shared", "test", "testing", "tests", "type", "types", "util",
    "utils",
])

LESSONS_LARGE_LINES = 60      # .claude/rules/lessons.md is always loaded: ~20 lessons
DIRECTORY_NEW_MIN_FILES = 5   # the structure hook's threshold

# research-stale (update/references/re-research.md § Detection)
DEPTH_ROSTER = {
    "minimal": frozenset(),
    "standard": frozenset(["architecture", "data-model", "testing", "security"]),
    "comprehensive": frozenset(["architecture", "data-model", "testing", "security",
                                "conventions", "domain", "dependencies"]),
}
FRAMEWORKS = frozenset([
    "next", "react", "vue", "svelte", "@sveltejs/kit", "astro", "nuxt", "express", "fastify",
    "@nestjs/core", "@angular/core", "@remix-run/node", "solid-js",
])
SECURITY_PATH_RE = re.compile(r"(^|/)[^/]*(auth|crypto|secret)[^/]*(/|$)", re.IGNORECASE)
DATA_MODEL_PATH_RE = re.compile(
    r"(^|/)(migrations?|schema|schemas|models?)(/|$)|\.(prisma|sql)$|(^|/)schema\.[A-Za-z]+$",
    re.IGNORECASE)
TEST_PATH_RE = re.compile(r"(^|/)(__tests__|tests?|spec|e2e)(/|$)|\.(test|spec)\.[A-Za-z]+$")
