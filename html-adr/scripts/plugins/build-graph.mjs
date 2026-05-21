function slugify(s) {
  return String(s).replace(/[^A-Za-z0-9_-]+/g, '-').replace(/^-|-$/g, '');
}

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
      const id = 'sect-' + sect.type;
      nodes.push({ id, label: sect.headingText, type: 'sect' });
    }

    const chosen = options.find(o => o.verdict === 'chosen');
    if (chosen) {
      const optId = 'opt-' + slugify(chosen.name).split('-')[0];
      for (const sect of sections) {
        edges.push({ source: optId, target: 'sect-' + sect.type });
      }
    }

    tree.data.graph = { nodes, edges };
  };
}
