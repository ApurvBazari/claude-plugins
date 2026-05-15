# CI Draft Review — {{cicdAndDelivery.draftProvider}}

{{#if cicdAndDelivery.draftFallback}}
> ⚠ **LLM draft — review carefully.** Provider `{{cicdAndDelivery.draftProvider}}` has no vetted renderer module. CHECK-R6-8 requires every warning marked `addressed=true` before Approve.
{{/if}}

## Panel 1 — Inputs

- **Provider:** {{cicdAndDelivery.draftProvider}}
- **Stages:** {{cicdAndDelivery.cicd.stages}}
- **Runners:** {{cicdAndDelivery.cicd.runners}}
- **Deploy:** {{cicdAndDelivery.cicd.deploy.environment}}
- **Framework:** {{architecturalFraming.frontendFramework}}
- **Stack:** {{stack.language}}

## Panel 2 — Decisions log

{{#each cicdAndDelivery.adjustHistory}}
- **{{this.at}}**: {{this.instruction}}
{{/each}}

### Cross-check warnings

{{#each cicdAndDelivery.draftWarnings}}
- [{{this.level}}] **{{this.id}}**: {{this.message}}{{#if this.addressed}} _(addressed)_{{/if}}
{{/each}}

## Panel 3 — Rendered YAML

```yaml
{{cicdAndDelivery.draftYaml}}
```

_Rendered at: {{cicdAndDelivery.draftRenderedAt}}_

## Approve / Adjust / Reject

- **Approve:** writes the YAML to `cicdAndDelivery.lockedYaml`; onboard generates verbatim at scaffold time.
- **Adjust:** describe a correction in natural language; the LLM edits the YAML inline and re-renders Panel 3.
- **Reject:** returns to Step 19 CI/CD to re-answer questions.
