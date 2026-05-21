function slugify(s) {
  return String(s).replace(/[^A-Za-z0-9_-]+/g, '-').replace(/^-|-$/g, '');
}

// Sections whose type lives in this set are surfaced as nodes in the overview
// graph. GENERIC_PROSE is excluded on purpose: those are catch-all body
// chunks ("Background", "Open follow-ups", etc.) that vary spec-to-spec and
// would (a) all collide on the same id `sect-GENERIC_PROSE` and (b) clutter
// the structural map without adding navigation value. Authors who want a
// non-canonical heading on the map should add a `sections_override:` entry
// pointing it at a canonical type.
const CANONICAL_GRAPH_TYPES = new Set([
  'AFFECTED_FILES', 'DATA_FLOW', 'EDGE_CASES',
  'DEPS_RISKS', 'ROLLBACK', 'TESTING',
]);

export function buildGraph() {
  return function transformer(tree) {
    tree.data = tree.data ?? {};
    const adr = tree.data.adr ?? {};
    const sections = tree.data.sections ?? [];
    const options = adr.considered_options?.value ?? [];

    const nodes = [];
    const edges = [];

    nodes.push({ id: 'adr', label: 'Decision', type: 'adr' });

    for (const opt of options) {
      const id = 'opt-' + slugify(opt.name).split('-')[0];
      nodes.push({ id, label: opt.name, type: opt.verdict === 'chosen' ? 'opt-chosen' : 'opt' });
      edges.push({ source: 'adr', target: id });
    }

    for (const sect of sections) {
      if (!CANONICAL_GRAPH_TYPES.has(sect.type)) continue;
      const id = 'sect-' + sect.type;
      nodes.push({ id, label: sect.headingText, type: 'sect' });
    }

    const chosen = options.find(o => o.verdict === 'chosen');
    if (chosen) {
      const optId = 'opt-' + slugify(chosen.name).split('-')[0];
      for (const sect of sections) {
        if (!CANONICAL_GRAPH_TYPES.has(sect.type)) continue;
        edges.push({ source: optId, target: 'sect-' + sect.type });
      }
    }

    tree.data.graph = { nodes, edges };
  };
}
