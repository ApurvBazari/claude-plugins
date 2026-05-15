# Search — {{search.searchType}} via {{search.engine}}

## Index scope
{{#each search.indexScope}}- {{this}}
{{/each}}

## Update strategy
{{search.updateStrategy}}

## Query patterns
{{#each search.queryPatterns}}- {{this}}
{{/each}}

## Ranking
{{search.ranking}}

## Security
- RLS: {{search.security.rls}}
- Query auth: {{search.security.queryAuth}}

## Risks
{{#each search.qRisks}}- {{this}}
{{/each}}
