import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildGraph } from '../scripts/plugins/build-graph.mjs';

test('builds nodes for ADR + options + sections', () => {
  const t = {
    type: 'root',
    children: [],
    data: {
      adr: {
        considered_options: { value: [
          { name: 'A', verdict: 'chosen' },
          { name: 'B', verdict: 'rejected' },
        ]},
      },
      sections: [
        { type: 'AFFECTED_FILES', headingText: 'Affected Files' },
        { type: 'EDGE_CASES', headingText: 'Edge Cases' },
      ],
    },
  };
  buildGraph()(t);
  const ids = t.data.graph.nodes.map(n => n.id).sort();
  assert.ok(ids.includes('adr'));
  assert.ok(ids.includes('opt-A'));
  assert.ok(ids.includes('opt-B'));
  assert.ok(ids.includes('sect-AFFECTED_FILES'));
  assert.ok(ids.includes('sect-EDGE_CASES'));
});

test('chosen option node is flagged opt-chosen', () => {
  const t = {
    type: 'root', children: [],
    data: { adr: { considered_options: { value: [{ name: 'A', verdict: 'chosen' }] }}, sections: [] },
  };
  buildGraph()(t);
  const chosen = t.data.graph.nodes.find(n => n.id === 'opt-A');
  assert.equal(chosen.type, 'opt-chosen');
});

test('emits adr→options and option→sections edges', () => {
  const t = {
    type: 'root', children: [],
    data: {
      adr: { considered_options: { value: [{ name: 'A', verdict: 'chosen' }, { name: 'B' }] }},
      sections: [{ type: 'AFFECTED_FILES', headingText: 'Affected Files' }],
    },
  };
  buildGraph()(t);
  const edges = t.data.graph.edges.map(e => `${e.source}->${e.target}`);
  assert.ok(edges.includes('adr->opt-A'));
  assert.ok(edges.includes('adr->opt-B'));
  assert.ok(edges.includes('opt-A->sect-AFFECTED_FILES'));
});
