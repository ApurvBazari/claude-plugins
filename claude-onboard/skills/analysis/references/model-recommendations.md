# Model Recommendation Logic

Only recommend **Sonnet** or **Opus**. The developer must explicitly approve any recommendation.

---

## Decision Matrix

| Factor | Sonnet Indicator | Opus Indicator |
|---|---|---|
| Complexity score | ≤50 (small-medium) | >50 (large-enterprise) |
| Source files | <500 | ≥500 |
| Total LOC | <50K | ≥50K |
| Languages | 1-2 | 3+ |
| Monorepo | No | Yes |
| CI/CD complexity | Simple or none | Multi-stage, complex |
| Architecture layers | ≤3 | >3 |

## Recommendation Tiers

### Recommend Sonnet (default for most projects)

**When**:
- Small to medium projects (complexity score ≤50)
- Single language or language + templating (e.g., TypeScript + HTML)
- Straightforward architecture (typical MVC, SPA, API server)
- <500 source files, <50K LOC

**Reasoning to present**:
- Excellent performance for most development tasks
- Faster response times for iterative development
- Lower cost per interaction
- Handles typical feature development, bug fixes, and refactoring well

### Present Both Options (let developer choose)

**When**:
- Medium to large projects (complexity score 40-70)
- 500-2000 source files, 50K-200K LOC
- Multiple significant languages
- Moderate architectural complexity

**Reasoning to present**:
- Sonnet: Faster, more cost-effective, great for focused tasks
- Opus: Better at holding large context, understanding complex interactions across modules, architectural reasoning

### Recommend Opus

**When**:
- Large to enterprise projects (complexity score >70)
- 2000+ source files, 200K+ LOC
- 3+ programming languages with significant code in each
- Complex monorepo with cross-package dependencies
- Complex CI/CD with multi-stage deployments
- Deep architectural layering (>3 layers)

**Reasoning to present**:
- Superior at reasoning across large codebases
- Better understanding of complex dependency chains
- Handles multi-language context switches effectively
- More reliable at maintaining architectural consistency

## Nudge Factors (adjust recommendation by one tier)

Each of these nudges the recommendation toward Opus by one level:
- **Monorepo detected**: Cross-package reasoning benefits from deeper analysis
- **3+ languages**: Context switching between language paradigms
- **Complex CI/CD**: Multi-stage pipelines, environment-specific configs
- **Deep nesting** (depth >8): Deeply nested module structures
- **High dependency count** (>100): Large dependency graphs need better understanding

Each of these nudges the recommendation toward Sonnet by one level:
- **Solo developer**: Fewer coordination concerns, faster iteration preferred
- **New/small project**: Simpler context, speed matters more
- **Single primary language**: Less context switching needed

## Presentation Format

Always present the recommendation as:

```
Based on your project analysis:
- [X source files, Y LOC, Z languages]
- [Key complexity factors]

Recommended model: [Sonnet/Opus]
Reasoning: [2-3 bullet points]

[If both are viable]: You could also consider [other model] if [trade-off explanation].

Which model would you like to use? (You can always change this later.)
```

**Critical**: Never auto-select a model. Always present the reasoning and let the developer choose.
