# Renderer architecture (post-R6)

Post-refactor inventory of all 16 renderer modules (11 schema + 5 CI) + the entrypoint dispatch + the shared library. The R6 refactor extracted shared helpers into `render-common.sh` and rewrote each renderer to source from it.

## Module inventory

### Schema renderers (11 total — 6 R5 + 5 R6)

| Module | Triggered when | Library |
|---|---|---|
| render-db-prisma.sh | engine in {postgres,mysql,sqlite} AND language=prisma | render-common.sh |
| render-db-sql-ddl.sh | engine in {postgres,mysql,sqlite} AND language=sql-ddl | render-common.sh |
| render-db-mongoose.sh | engine=mongodb | render-common.sh |
| render-db-drizzle.sh | engine in {postgres,mysql,sqlite} AND language=drizzle | render-common.sh |
| render-api-openapi.sh | style=rest AND language=openapi-3.0 | render-common.sh |
| render-api-graphql.sh | style=graphql AND language=graphql-sdl | render-common.sh |
| render-api-trpc.sh | style=trpc | render-common.sh |
| render-api-hasura.sh | style=hasura | render-common.sh |
| render-event-asyncapi.sh | asyncPattern in {kafka,sns,rabbit} AND language=asyncapi | render-common.sh |
| render-event-json-schema.sh | asyncPattern != none AND language=json-schema | render-common.sh |
| render-event-avro.sh | asyncPattern in {kafka,kinesis} AND language=avro | render-common.sh |

### CI renderers (4 modules + 1 entrypoint)

| Module | Triggered when | Library |
|---|---|---|
| render-ci-drafts.sh (entry) | Step 20 wizard hook | render-common.sh |
| render-ci-gha.sh | provider in {gha, github-actions} | render-common.sh |
| render-ci-gitlab.sh | provider in {gitlab, gitlab-ci} | render-common.sh |
| render-ci-circleci.sh | provider in {circle, circleci} | render-common.sh |
| render-ci-llm-fallback.sh | any other provider | render-common.sh |

## render-common.sh helper API

| Helper | Signature | Purpose |
|---|---|---|
| `_emit_warning <level> <code> <message> <warnings-json>` | returns updated JSON to stdout | append cross-check warning |
| `_check_pii_encryption <path> <pii-array> <warnings-json>` | returns updated JSON | warn if PII has no encryption hint |
| `_atomic_write <target-path> <content>` | side-effect | tmp-then-rename atomic write |
| `_render_handlebars <template> <data-json>` | returns rendered string | minimal `{{key}}` substitution |
| `_emit_dependency <phase> <path> <value> <rationale>` | side-effect (writes to $DEPS_PATH) | append to dependencies.json |
| `_validate_jq_path <state-file> <path> <required>` | returns value or exits non-zero | safe jq read with required-path gate |

## Renderer envelope contract

Every renderer module (schema + CI) returns JSON on stdout:

```json
{ "content": "<rendered text>", "sourceRefs": [{"path": "...", "renderedAs": "..."}], "crossCheckWarnings": [{"id": "...", "level": "warn|error|info", "message": "..."}] }
```

Entrypoints dispatch by `(artifact, language)` (schema) or `provider` (CI) and atomically write back to the state file.
