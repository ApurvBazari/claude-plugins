# Depth Profiles — preset → research depth

The `depth` input preset bounds the entire run: how many specialists run, which dimensions they cover, and how wide each one reads. It is the primary cost dial on large repos. There are three presets; the dossier records the one used in `research-dossier.depth`.

## The three presets

| Preset | Specialists run | Built-in dimensions | Customs | Verify pass | Scope per specialist |
|---|---|---|---|---|---|
| `minimal` | **None** — recon only | (none dispatched) | (none dispatched) | none (no claims to verify) | n/a |
| `standard` | Core 4 | `architecture`, `data-model`, `testing`, `security` | none | single adversarial verify | tight — per-dimension `scopeGlobs` from the roster, intersected with detected source roots |
| `comprehensive` | All 7 + customs | `architecture`, `data-model`, `testing`, `security`, `conventions`, `domain`, `dependencies` | all enabled `extraSpecialists` | single adversarial verify | per-dimension `scopeGlobs`, widened to the full detected source tree |

> **Multi-vote verification is the deferred Workflow power-up.** Every preset in this plan runs exactly **one** adversarial verifier pass (`research-verifier`). Multi-vote (K skeptics + majority resolution) is reserved for the later Workflow-backend plan; `engineUsed` stays `"subagent"` throughout.

## How depth caps the roster

The depth preset is applied **after** the effective roster is computed (see `custom-specialist-contract.md`):

```
effectiveRoster = (builtins − disabledBuiltins) ∪ extraSpecialists   # from config
                          │
                          ▼  depth cap
  minimal        → []                                  (drop everything; no specialists)
  standard       → effectiveRoster ∩ {architecture, data-model, testing, security}
                   (customs are NOT run at standard depth — they need comprehensive)
  comprehensive  → effectiveRoster                      (all enabled builtins + all customs)
```

- A built-in disabled in config is already absent from `effectiveRoster`, so depth never re-adds it.
- At `standard`, only the **core 4** builtins run; a custom specialist or a non-core builtin (`conventions`, `domain`, `dependencies`) is held until `comprehensive`. Record the held dimensions in the run log so the user understands why a configured custom did not run at standard depth.
- The roster actually dispatched is what lands in `research-dossier.roster.builtins` / `.customSpecialists`; `roster.disabledBuiltins` echoes the config (config-derived by construction, so it is always a subset of the config enum).

## How depth caps per-specialist scope

Each specialist receives a `scopeGlobs` array that bounds its reads:

1. Start from the dimension's default `scopeGlobs` in `specialist-roster.md` (or the custom's `scopeGlobs`).
2. **Intersect** with the detected source roots from the engine's SCOPE step (Step 2) so a glob never escapes the real source tree — except **root-dwelling globs** (manifests/lockfiles, docs, test/lint config) which are exempt from the intersection (see SKILL § Step 2), since they legitimately live at the repo root.
3. At `standard`, prefer the tighter end of the dimension's globs (the engine may sample representative subtrees on a very large repo); at `comprehensive`, pass the full intersected set.

The point: depth `standard` is the everyday default — fast, four core dimensions, one verify pass. `comprehensive` is the "tell me everything" mode — all seven dimensions plus any project customs, still one verify pass. `minimal` is the empty-repo / recon-only floor that produces a valid dossier with an empty roster and empty findings.
