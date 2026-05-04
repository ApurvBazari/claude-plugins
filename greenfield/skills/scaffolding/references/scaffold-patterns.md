# Scaffold Patterns

Common scaffold approaches organized by stack family. These are starting points — always prefer web research findings over these patterns when available.

## JavaScript / TypeScript

### Next.js
- **CLI**: `pnpm create next-app@latest . --ts --tailwind --eslint --app --turbopack --import-alias '@/*'`
- **Structure**: `app/` (App Router), `public/`, `lib/`, `components/`
- **Dev command**: `npm run dev` (port 3000)

### Vite (React/Vue/Svelte)
- **CLI**: `pnpm create vite@latest . --template react-ts`
- **Structure**: `src/`, `public/`, `index.html`
- **Dev command**: `npm run dev` (port 5173)

### Express / Hono / Fastify
- **CLI**: None standard — scaffold from scratch
- **Structure**: `src/`, `src/routes/`, `src/middleware/`, `src/lib/`
- **Dev command**: `npm run dev` (port 3000)

### NestJS
- **CLI**: `npx @nestjs/cli new . --package-manager pnpm --strict`
- **Structure**: `src/`, `src/modules/`, `test/`
- **Dev command**: `npm run start:dev` (port 3000)

## Python

### FastAPI
- **CLI**: None standard — scaffold from scratch or use `uv init`
- **Structure**: `app/`, `app/routers/`, `app/models/`, `tests/`
- **Dev command**: `uvicorn app.main:app --reload` (port 8000)

### Django
- **CLI**: `django-admin startproject [name] .`
- **Structure**: `[name]/`, `manage.py`, `[name]/settings.py`
- **Dev command**: `python manage.py runserver` (port 8000)

### Flask
- **CLI**: None standard — scaffold from scratch
- **Structure**: `app/`, `app/__init__.py`, `app/routes/`
- **Dev command**: `flask run --debug` (port 5000)

## Go

### Standard (net/http, Chi, Gin, Echo)
- **CLI**: `go mod init [module]`
- **Structure**: `cmd/`, `internal/`, `pkg/`, `api/`
- **Dev command**: `go run cmd/server/main.go` (port 8080)

## Rust

### Axum / Actix
- **CLI**: `cargo init`
- **Structure**: `src/`, `src/routes/`, `src/models/`
- **Dev command**: `cargo run` or `cargo watch -x run` (port 3000/8080)

## Ruby

### Rails
- **CLI**: `rails new . --api --database=postgresql` (adjust flags)
- **Structure**: `app/`, `config/`, `db/`, `lib/`, `spec/`
- **Dev command**: `bin/rails server` (port 3000)

## Common Post-Scaffold Additions

These apply across stacks:

| Addition | When | Files |
|---|---|---|
| `.env.example` | Always | Placeholder env vars |
| `.gitignore` | If missing | Stack-specific patterns |
| `Dockerfile` | If Docker selected | Multi-stage build |
| `docker-compose.yml` | If Docker selected | App + services |
| Monorepo config | If monorepo | turborepo.json, pnpm-workspace.yaml |
| i18n structure | If i18n selected | Locale dirs, base config |
