/*!
 * html-adr — client runtime
 * ----------------------------------------------------------------------------
 * Inlined into every rendered ADR HTML. Sibling <script> tags load Cytoscape,
 * cytoscape-dagre, dagre, Mermaid, and highlight.js BEFORE this file executes,
 * so those libraries are available as globals.
 *
 * Hard rules:
 *   - ZERO innerHTML. Every DOM build path uses document.createElement +
 *     textContent + appendChild.
 *   - No eval, no Function(), no string→code conversion of any kind.
 *   - No imports. ES2020 plain script, IIFE for module-level state.
 *
 * Data contract (set by the renderer at build time):
 *   <script id="graph-data" type="application/json">{...}</script>
 *     → { nodes: [{ id, label, type }], edges: [{ source, target }] }
 *
 *   Any clickable item element in the rendered HTML carries:
 *     data-item-type="<kind>"        // file | step | case | dep | risk |
 *                                    // rollback-step | test | section
 *     data-item-id="<stable-id>"     // optional, for telemetry / debugging
 *     data-item-payload='<json>'     // the per-item record, JSON-encoded
 *
 *   The payload shape is determined by the kind. Builders below tolerate
 *   missing fields and never throw on malformed payloads — they degrade
 *   gracefully because the user's spec.md authored the data.
 *
 * Sections in this file (in order):
 *   1. Bootstrap & shared DOM helpers
 *   2. Cytoscape graph
 *   3. Side panel core (open/close, focus trap, clear, builders)
 *   4. Item builders (one per data-item-type)
 *   5. Click delegation & keyboard handling
 *   6. TOC scroll-spy
 *   7. Mermaid
 */

(function () {
  'use strict';

  // =========================================================================
  // 1. Bootstrap & shared DOM helpers
  // =========================================================================

  /**
   * Wait for DOMContentLoaded if needed, then run init().
   * The runtime <script> is at the end of <body>, so usually the DOM is
   * already parsed by the time we run — but this guard keeps the file safe
   * if a future renderer change moves the tag.
   */
  function whenReady(fn) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn, { once: true });
    } else {
      fn();
    }
  }

  /**
   * Small DOM builder. Intentionally does NOT accept raw HTML strings —
   * every value passed in is treated as text content. This is the only
   * authorized element factory in this file.
   *
   *   el('h4', { text: 'Heading' })
   *   el('div', { class: 'foo bar' }, child1, child2, 'inline text')
   *   el('span', { attrs: { 'data-x': '1' } }, 'label')
   */
  function el(tag, opts) {
    var e = document.createElement(tag);
    if (opts) {
      if (opts['class']) e.className = opts['class'];
      if (opts.text != null) e.textContent = String(opts.text);
      if (opts.style) Object.assign(e.style, opts.style);
      if (opts.attrs) {
        for (var k in opts.attrs) {
          if (Object.prototype.hasOwnProperty.call(opts.attrs, k)) {
            e.setAttribute(k, String(opts.attrs[k]));
          }
        }
      }
    }
    // Remaining args are children: Nodes pass through; strings become text.
    for (var i = 2; i < arguments.length; i++) {
      var c = arguments[i];
      if (c == null || c === false) continue;
      if (typeof c === 'string' || typeof c === 'number') {
        e.appendChild(document.createTextNode(String(c)));
      } else {
        e.appendChild(c);
      }
    }
    return e;
  }

  /** Convenience constructors for the common patterns. */
  function text(node) { return document.createTextNode(String(node)); }
  function h4(label) { return el('h4', { text: label }); }
  function p(body) { return el('p', { text: body }); }
  function pre(body) { return el('pre', { text: body }); }
  function muted(body) {
    return el('p', { text: body, style: { color: 'var(--muted)', fontStyle: 'italic' } });
  }

  /** Provenance chip: "Extracted from: …" — appears at the top of each panel. */
  function provBox(key, val) {
    return el('div', { 'class': 'side-prov' },
      el('span', { 'class': 'side-prov-key', text: key + ' ' }),
      text(val)
    );
  }

  /** File-existence pill. Renders both branches of the badge consistently. */
  function existsBadge(exists, path) {
    var label = (exists ? '✓ exists' : '✗ not yet on disk') + ' — ' + path;
    return el('div', { 'class': 'side-existence ' + (exists ? 'exists' : 'missing'), text: label });
  }

  /**
   * Read a JSON payload from an element's data-item-payload attribute.
   * Returns {} on missing/invalid payload — builders defensively handle
   * empty objects rather than throwing.
   */
  function readPayload(node) {
    if (!node) return {};
    var raw = node.getAttribute('data-item-payload');
    if (!raw) return {};
    try {
      var parsed = JSON.parse(raw);
      return (parsed && typeof parsed === 'object') ? parsed : {};
    } catch (err) {
      // Console-only; never throw into the user's reading experience.
      if (window.console && console.warn) {
        console.warn('[html-adr] malformed data-item-payload on', node, err);
      }
      return {};
    }
  }

  // =========================================================================
  // 2. Cytoscape graph
  // =========================================================================

  function initGraph() {
    var container = document.getElementById('cy');
    var dataTag = document.getElementById('graph-data');
    if (!container || !dataTag || typeof window.cytoscape !== 'function') return null;

    // Register the dagre layout extension if present. Wrapped in try because
    // the extension auto-registers on load in some bundles.
    if (window.cytoscapeDagre) {
      try { window.cytoscape.use(window.cytoscapeDagre); } catch (e) { /* already registered */ }
    }

    var graphData;
    try {
      graphData = JSON.parse(dataTag.textContent || '{}');
    } catch (e) {
      if (window.console && console.warn) console.warn('[html-adr] graph-data parse failed', e);
      return null;
    }

    var nodes = (graphData.nodes || []).map(function (n) { return { data: n }; });
    var edges = (graphData.edges || []).map(function (e) { return { data: e }; });

    var cy = window.cytoscape({
      container: container,
      elements: nodes.concat(edges),
      style: [
        { selector: 'node', style: {
          'label':              'data(label)',
          'background-color':   '#ffffff',
          'border-width':       1.5,
          'border-color':       '#d4ccbc',
          'color':              '#1a1714',
          'font-family':        'Inter, sans-serif',
          'font-size':          11,
          'font-weight':        500,
          'text-valign':        'center',
          'text-halign':        'center',
          'text-wrap':          'wrap',
          'text-max-width':     150,
          'padding':            12,
          'width':              160,
          'height':             46,
          'shape':              'round-rectangle',
        }},
        { selector: 'node[type="adr"]', style: {
          'background-color':   '#1a1714',
          'color':              '#faf8f3',
          'border-color':       '#1a1714',
          'font-weight':        600,
          'font-size':          12,
        }},
        { selector: 'node[type="opt-chosen"]', style: {
          'background-color':   '#e8efe1',
          'border-color':       '#4a6b3a',
          'border-width':       2,
          'color':              '#4a6b3a',
          'font-weight':        600,
        }},
        { selector: 'node[type="opt"]', style: {
          'background-color':   '#f5f0e3',
          'border-color':       '#d4ccbc',
          'color':              '#756f66',
          'font-style':         'italic',
        }},
        { selector: 'node[type="sect"]', style: {
          'background-color':   '#faf8f3',
          'border-color':       '#d4ccbc',
          'color':              '#1a1714',
        }},
        { selector: 'node.highlight', style: {
          'border-color':       '#b8651b',
          'border-width':       2.5,
          'background-color':   '#faf2e3',
        }},
        { selector: 'edge', style: {
          'width':              1.2,
          'line-color':         '#d4ccbc',
          'target-arrow-color': '#d4ccbc',
          'target-arrow-shape': 'triangle',
          'curve-style':        'bezier',
          'arrow-scale':        0.9,
        }},
        { selector: 'edge.highlight', style: {
          'line-color':         '#b8651b',
          'target-arrow-color': '#b8651b',
          'width':              2,
        }},
      ],
      layout: {
        name:           'breadthfirst',
        directed:       true,
        padding:        24,
        spacingFactor:  1.5,
        // Render top-to-bottom by default — root ("Decision") at the top,
        // options below, then sections.
      },
      minZoom: 0.5,
      maxZoom: 2.0,
    });

    cy.on('mouseover', 'node', function (e) {
      var n = e.target;
      n.addClass('highlight');
      n.connectedEdges().addClass('highlight');
      n.neighborhood('node').addClass('highlight');
    });
    cy.on('mouseout', 'node', function () {
      cy.elements().removeClass('highlight');
    });

    // Mapping from build-graph's sect-* node IDs to the canonical widget IDs
    // that widget-builders.mjs emits. Without this, tap navigation to sections
    // never finds a target because graph node IDs and DOM IDs diverge.
    var SECTION_TYPE_TO_WIDGET_ID = {
      AFFECTED_FILES: 'files',
      DATA_FLOW:      'flow',
      EDGE_CASES:     'edge',
      DEPS_RISKS:     'deps',
      ROLLBACK:       'rollback',
      TESTING:        'test',
    };

    function widgetIdForNodeId(nodeId) {
      if (nodeId === 'adr') return 'adr-header';
      if (nodeId.indexOf('sect-') === 0) {
        var type = nodeId.slice(5);
        if (SECTION_TYPE_TO_WIDGET_ID[type]) return SECTION_TYPE_TO_WIDGET_ID[type];
        return type.toLowerCase().replace(/_/g, '-');
      }
      return nodeId;
    }

    cy.on('tap', 'node', function (e) {
      var nodeId = e.target.id();
      var targetId = widgetIdForNodeId(nodeId);
      var sectionEl = document.getElementById(targetId);
      if (sectionEl) {
        sectionEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
        var head = sectionEl.querySelector('[data-item-type="section"]');
        if (head) openItem(head);
      }
    });

    return cy;
  }

  // =========================================================================
  // 3. Side panel core
  // =========================================================================

  var sidePanel, sideTitle, sideEyebrow, sideBody, sideCloseBtn;
  var lastFocusedTrigger = null;

  function clearSide() {
    while (sideBody.firstChild) sideBody.removeChild(sideBody.firstChild);
  }

  function showSide() {
    if (!sidePanel) return;
    sidePanel.classList.add('open');
    sidePanel.setAttribute('aria-hidden', 'false');
    // Move focus into the panel for keyboard users.
    if (sideCloseBtn) {
      // Delay one frame so the panel's CSS transition has started before focus.
      requestAnimationFrame(function () { sideCloseBtn.focus(); });
    }
  }

  function closeSide() {
    if (!sidePanel) return;
    sidePanel.classList.remove('open');
    sidePanel.setAttribute('aria-hidden', 'true');
    // Restore focus to whatever opened the panel — keyboard nav stays sane.
    if (lastFocusedTrigger && typeof lastFocusedTrigger.focus === 'function') {
      lastFocusedTrigger.focus();
    }
    lastFocusedTrigger = null;
  }

  function setSideHeader(title, eyebrow) {
    sideTitle.textContent = title || '';
    sideEyebrow.textContent = eyebrow || '';
  }

  /** Render a list payload into a <ul>; supports string items or {text} objects. */
  function renderList(items) {
    var ul = el('ul');
    items.forEach(function (item) {
      var s = typeof item === 'string' ? item : (item && item.text) || '';
      ul.appendChild(el('li', { text: s }));
    });
    return ul;
  }

  // =========================================================================
  // 4. Item builders (one per data-item-type)
  // =========================================================================
  //
  // Every builder receives the parsed payload object and returns a DocumentFragment
  // worth of nodes by appending to sideBody. Builders also set the header.
  //
  // Each builder defensively handles missing fields: when the spec.md omits a
  // value, the renderer omits the corresponding section rather than printing
  // "undefined" into a reading experience.

  /** SECTION-level. payload: { title, eyebrow, regex, summary, overrideHint }. */
  function buildSection(payload) {
    setSideHeader(payload.title, payload.eyebrow || '#section · section detail');
    sideBody.appendChild(provBox('Extracted from:', payload.provenance || 'H2 heading match · auto-classified'));
    if (payload.regex) {
      sideBody.appendChild(h4('Heading regex'));
      sideBody.appendChild(pre(payload.regex));
    }
    if (payload.summary) {
      sideBody.appendChild(h4('Summary'));
      sideBody.appendChild(p(payload.summary));
    }
    if (payload.overrideHint) {
      sideBody.appendChild(h4('Override'));
      sideBody.appendChild(p('To force a different widget for this heading:'));
      sideBody.appendChild(pre(payload.overrideHint));
    }
  }

  /** FILE. payload: { path, status, exists, gitLog: [str], mentions: [str] }. */
  function buildFile(payload) {
    var name = payload.path ? payload.path.split('/').pop() : 'file';
    setSideHeader(name, '#files · file detail');
    sideBody.appendChild(provBox('From:', 'AFFECTED_FILES widget · line bullet in source spec'));
    if (payload.path) {
      sideBody.appendChild(h4('Full path'));
      sideBody.appendChild(pre(payload.path));
    }
    if (payload.status) {
      sideBody.appendChild(h4('Status'));
      var statusP = el('p');
      statusP.appendChild(text('Marker detected: '));
      statusP.appendChild(el('code', { text: payload.status }));
      statusP.appendChild(text(' — explicit marker, no inference.'));
      sideBody.appendChild(statusP);
    }
    sideBody.appendChild(h4('Filesystem'));
    sideBody.appendChild(existsBadge(!!payload.exists, payload.path || '(unknown path)'));
    if (Array.isArray(payload.gitLog) && payload.gitLog.length) {
      sideBody.appendChild(h4('Git log'));
      sideBody.appendChild(renderList(payload.gitLog));
    } else if (payload.exists === false) {
      sideBody.appendChild(h4('Git log'));
      sideBody.appendChild(muted('(not yet committed — file does not exist on disk yet)'));
    }
    if (Array.isArray(payload.mentions) && payload.mentions.length) {
      sideBody.appendChild(h4('Cross-spec mentions'));
      sideBody.appendChild(renderList(payload.mentions));
    }
  }

  /** STEP. payload: { title, role, kind: 'input'|'plugin'|'custom', pkg, file }. */
  function buildStep(payload) {
    setSideHeader(payload.title || 'pipeline step', '#flow · pipeline step detail');
    sideBody.appendChild(provBox('From:', 'DATA_FLOW widget · pipeline step'));
    if (payload.role) {
      sideBody.appendChild(h4('Role'));
      sideBody.appendChild(p(payload.role));
    }
    if (payload.kind === 'custom' && payload.file) {
      sideBody.appendChild(h4('Implementation file'));
      sideBody.appendChild(pre(payload.file));
      sideBody.appendChild(h4('Filesystem'));
      sideBody.appendChild(existsBadge(!!payload.exists, payload.file));
    } else if (payload.kind === 'plugin' && payload.pkg) {
      sideBody.appendChild(h4('npm package'));
      sideBody.appendChild(pre(payload.pkg));
    }
  }

  /** CASE. payload: { title, sev, sevWhy, handling, related: [str] }. */
  function buildCase(payload) {
    setSideHeader(payload.title || 'edge case', '#edge · case detail');
    sideBody.appendChild(provBox('From:', 'EDGE_CASES widget · severity: ' + (payload.sev || 'medium')));
    if (payload.sevWhy) {
      sideBody.appendChild(h4('Severity reasoning'));
      sideBody.appendChild(p(payload.sevWhy));
    }
    if (payload.handling) {
      sideBody.appendChild(h4('Handling'));
      sideBody.appendChild(p(payload.handling));
    }
    sideBody.appendChild(h4('Related items (keyword overlap)'));
    if (Array.isArray(payload.related) && payload.related.length) {
      sideBody.appendChild(renderList(payload.related));
    } else {
      sideBody.appendChild(muted('No closely-related items detected.'));
    }
  }

  /** DEP. payload: { name, version, upstreamUrl, localPath, exists, firstMention }. */
  function buildDep(payload) {
    var label = (payload.name || 'dependency') + (payload.version ? '@' + payload.version : '');
    setSideHeader(label, '#deps · dependency detail');
    sideBody.appendChild(provBox('From:', 'DEPS_RISKS widget · vendored libraries chip'));
    sideBody.appendChild(h4('Package'));
    sideBody.appendChild(pre(label));
    if (payload.upstreamUrl) {
      sideBody.appendChild(h4('Upstream URL'));
      sideBody.appendChild(pre(payload.upstreamUrl));
    }
    if (payload.localPath) {
      sideBody.appendChild(h4('Local path'));
      sideBody.appendChild(pre(payload.localPath));
      sideBody.appendChild(h4('Filesystem'));
      sideBody.appendChild(existsBadge(!!payload.exists, payload.localPath));
    }
    if (payload.firstMention) {
      sideBody.appendChild(h4('Mentioned in source spec'));
      sideBody.appendChild(p(payload.firstMention));
    }
  }

  /** RISK. payload: { title, prose, mitigation, related: [str] }. */
  function buildRisk(payload) {
    setSideHeader(payload.title || 'risk', '#deps · risk detail');
    sideBody.appendChild(provBox('From:', 'DEPS_RISKS widget · risk callout'));
    if (payload.prose) {
      sideBody.appendChild(h4('Description'));
      sideBody.appendChild(p(payload.prose));
    }
    if (payload.mitigation) {
      sideBody.appendChild(h4('Mitigation'));
      sideBody.appendChild(p(payload.mitigation));
    }
    sideBody.appendChild(h4('Related rollback steps'));
    if (Array.isArray(payload.related) && payload.related.length) {
      sideBody.appendChild(renderList(payload.related));
    } else {
      sideBody.appendChild(muted('No related items detected.'));
    }
  }

  /** ROLLBACK STEP. payload: { title, prose, commands: [str], returnsTo, key }. */
  function buildRollbackStep(payload) {
    setSideHeader(payload.title || 'rollback step', '#rollback · step detail');
    sideBody.appendChild(provBox('From:', 'ROLLBACK widget · numbered step ' + (payload.key || '')));
    if (payload.prose) {
      sideBody.appendChild(h4('Action'));
      sideBody.appendChild(p(payload.prose));
    }
    sideBody.appendChild(h4('Commands referenced'));
    if (Array.isArray(payload.commands) && payload.commands.length) {
      payload.commands.forEach(function (c) { sideBody.appendChild(pre(c)); });
    } else {
      sideBody.appendChild(muted('(no inline code chips in this step)'));
    }
    if (payload.returnsTo) {
      sideBody.appendChild(h4('Returns to state'));
      sideBody.appendChild(p(payload.returnsTo));
    }
  }

  /** TEST. payload: { title, cat: 'unit'|'e2e', kind, file, exists, golden }. */
  function buildTest(payload) {
    setSideHeader(payload.title || 'test', '#test · ' + (payload.cat || 'unit') + ' test detail');
    sideBody.appendChild(provBox('From:', 'TESTING widget · ' + (payload.cat || 'unit') + ' test bullet'));
    if (payload.kind) {
      sideBody.appendChild(h4('Kind'));
      sideBody.appendChild(p(payload.kind));
    }
    if (payload.file) {
      sideBody.appendChild(h4('Test file'));
      sideBody.appendChild(pre(payload.file));
      sideBody.appendChild(h4('Filesystem'));
      sideBody.appendChild(existsBadge(!!payload.exists, payload.file));
    }
    if (payload.golden) {
      sideBody.appendChild(h4('Golden HTML'));
      sideBody.appendChild(pre(payload.golden));
      sideBody.appendChild(existsBadge(!!payload.goldenExists, payload.golden));
    }
  }

  /** Dispatch table: data-item-type → builder. */
  var BUILDERS = {
    'section':        buildSection,
    'file':           buildFile,
    'step':           buildStep,
    'case':           buildCase,
    'dep':            buildDep,
    'risk':           buildRisk,
    'rollback-step':  buildRollbackStep,
    'test':           buildTest,
  };

  /**
   * Open the side panel for a given trigger element. Reads the element's
   * data-item-type, finds the matching builder, parses the payload, and
   * renders. Captures the trigger so focus can be restored on close.
   */
  function openItem(triggerEl) {
    if (!triggerEl) return;
    var kind = triggerEl.getAttribute('data-item-type');
    var build = BUILDERS[kind];
    if (!build) return;
    lastFocusedTrigger = triggerEl;
    clearSide();
    build(readPayload(triggerEl));
    showSide();
  }

  // =========================================================================
  // 5. Click delegation & keyboard handling
  // =========================================================================

  function wireInteractions() {
    // One delegated click handler. The closest()-with-attribute pattern means
    // a single listener serves every clickable item type in the document,
    // including future renderer additions — no per-type bindings to maintain.
    document.body.addEventListener('click', function (e) {
      var trigger = e.target.closest('[data-item-type]');
      if (!trigger) return;
      e.stopPropagation();
      openItem(trigger);
    });

    // Keyboard: ESC closes the side panel. Enter/Space on a focusable item
    // also opens it (the trigger element must be focusable — the renderer
    // adds tabindex="0" / role="button" where appropriate).
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') {
        if (sidePanel && sidePanel.classList.contains('open')) {
          e.preventDefault();
          closeSide();
        }
        return;
      }
      if (e.key === 'Enter' || e.key === ' ') {
        var active = document.activeElement;
        if (active && active.hasAttribute && active.hasAttribute('data-item-type')) {
          e.preventDefault();
          openItem(active);
        }
      }
    });

    if (sideCloseBtn) {
      sideCloseBtn.addEventListener('click', closeSide);
    }
  }

  // =========================================================================
  // 6. TOC scroll-spy
  // =========================================================================

  function initScrollSpy() {
    var tocLinks = document.querySelectorAll('.toc-list a');
    if (!tocLinks.length || typeof window.IntersectionObserver !== 'function') return;

    // Collect every section the TOC actually points at, in document order.
    var sections = [];
    tocLinks.forEach(function (a) {
      var href = a.getAttribute('href') || '';
      if (href.charAt(0) !== '#') return;
      var id = href.slice(1);
      var node = document.getElementById(id);
      if (node) sections.push(node);
    });
    if (!sections.length) return;

    function setActive(id) {
      tocLinks.forEach(function (a) {
        a.classList.toggle('active', a.getAttribute('href') === '#' + id);
      });
    }

    // rootMargin pushes the active band into the upper-middle of the viewport
    // — feels right for editorial documents where the eye sits near the top.
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (en.isIntersecting) setActive(en.target.id);
      });
    }, { rootMargin: '-30% 0px -60% 0px', threshold: 0 });

    sections.forEach(function (s) { observer.observe(s); });
  }

  // =========================================================================
  // 6.5 Per-widget DATA_FLOW Cytoscape canvases
  // =========================================================================

  function readFlowGraph(canvas) {
    var raw = canvas.getAttribute('data-flow-graph');
    if (!raw) return null;
    try {
      var data = JSON.parse(raw);
      if (!data || !Array.isArray(data.nodes) || !Array.isArray(data.edges)) return null;
      return data;
    } catch (err) {
      if (window.console && console.warn) console.warn('[html-adr] flow graph parse failed', err);
      return null;
    }
  }

  function buildFlowInstance(canvas, data) {
    var elements = data.nodes.map(function (n) {
      return { data: { id: n.id, label: n.label || '', description: n.description || '' } };
    }).concat(data.edges.map(function (e) {
      return { data: { source: e.source, target: e.target } };
    }));

    // breadthfirst is built into Cytoscape and produces a clean layered
    // layout for sequential flows — no external dagre dependency required
    // (vendored cytoscape-dagre + dagre don't auto-wire as window globals).
    var layout = {
      name:           'breadthfirst',
      directed:       true,
      grid:           true,
      padding:        20,
      spacingFactor:  1.4,
      transform:      function (node, pos) { return { x: pos.y, y: pos.x }; },
    };

    var cy = cytoscape({
      container: canvas,
      elements: elements,
      autoungrabify: false,
      userPanningEnabled: true,
      userZoomingEnabled: true,
      minZoom: 0.4,
      maxZoom: 2.5,
      style: [
        {
          selector: 'node',
          style: {
            'background-color':  '#faf2e3',
            'border-color':      '#b8651b',
            'border-width':      1,
            'shape':             'round-rectangle',
            'label':             'data(label)',
            'color':             '#1a1714',
            'font-family':       'JetBrains Mono, ui-monospace, monospace',
            'font-size':         11,
            'text-wrap':         'wrap',
            'text-max-width':    160,
            'text-valign':       'center',
            'text-halign':       'center',
            'padding':           12,
            'width':             170,
            'height':            44,
          },
        },
        {
          selector: 'node.hovered',
          style: {
            'background-color': '#f5ebd9',
            'border-color':     '#b8651b',
            'color':            '#b8651b',
          },
        },
        {
          selector: 'node.faded',
          style: { 'opacity': 0.3 },
        },
        {
          selector: 'edge',
          style: {
            'width':              1.5,
            'line-color':         '#d4ccbc',
            'target-arrow-color': '#b8651b',
            'target-arrow-shape': 'triangle',
            'curve-style':        'bezier',
            'arrow-scale':        0.9,
          },
        },
        {
          selector: 'edge.highlight',
          style: {
            'line-color':         '#b8651b',
            'target-arrow-color': '#b8651b',
            'width':              2,
          },
        },
      ],
      layout: layout,
    });

    cy.on('mouseover', 'node', function (evt) {
      var n = evt.target;
      n.addClass('hovered');
      cy.nodes().not(n).not(n.neighborhood('node')).addClass('faded');
      n.connectedEdges().addClass('highlight');
    });
    cy.on('mouseout', 'node', function (evt) {
      evt.target.removeClass('hovered');
      cy.elements().removeClass('faded').removeClass('highlight');
    });

    cy.on('tap', 'node', function (evt) {
      // Synthesize a transient trigger element with the step payload, then
      // dispatch through the existing openItem path so side-panel behavior is
      // identical between pill clicks and graph clicks.
      var n = evt.target;
      var trigger = document.createElement('span');
      trigger.setAttribute('data-item-type', 'step');
      trigger.setAttribute('data-item-payload', JSON.stringify({
        title: n.data('label'),
        role:  n.data('description'),
      }));
      openItem(trigger);
    });

    return cy;
  }

  function initFlowGraphs() {
    if (typeof window.cytoscape !== 'function') return;
    var canvases = document.querySelectorAll('.flow-canvas[data-flow-graph]');
    Array.prototype.forEach.call(canvases, function (canvas) {
      var data = readFlowGraph(canvas);
      if (data) buildFlowInstance(canvas, data);
    });
  }

  function wireFlowToggles() {
    document.body.addEventListener('click', function (e) {
      var btn = e.target.closest && e.target.closest('.flow-view-btn[data-flow-view]');
      if (!btn) return;
      var widget = btn.closest('.widget');
      if (!widget) return;
      var view = btn.getAttribute('data-flow-view');
      var siblings = widget.querySelectorAll('.flow-view-btn');
      Array.prototype.forEach.call(siblings, function (b) {
        b.classList.toggle('active', b === btn);
      });
      var canvas   = widget.querySelector('.flow-canvas');
      var pipeline = widget.querySelector('.flow-pipeline');
      var raw      = widget.querySelector('.flow-raw');
      if (canvas)   canvas.hidden   = view !== 'graph';
      if (pipeline) pipeline.hidden = view !== 'pipeline';
      if (raw)      raw.hidden      = view !== 'raw';
    });
  }

  // =========================================================================
  // 7. Mermaid
  // =========================================================================

  function initMermaid() {
    if (typeof window.mermaid === 'undefined' || !window.mermaid.initialize) return;
    // SECURITY POLICY: Mermaid securityLevel = 'loose'.
    // Trade-off:
    //   - 'sandbox' renders each diagram inside a sandboxed iframe. The iframe
    //     does NOT inherit page CSS, so our --accent / --ink CSS variables and
    //     fonts don't reach Mermaid's SVG. We lose theming.
    //   - 'loose' lets diagrams render inline with full page CSS and supports
    //     click bindings + inline styles. Authors are trusted (specs are
    //     hand-written by the dev; not user-input).
    // Guard: tests/render-templates.test.mjs asserts this literal stays as
    // 'loose'. Changing it intentionally requires editing that test too,
    // which forces explicit acknowledgement of the security trade-off in
    // the diff.
    window.mermaid.initialize({
      startOnLoad: true,
      theme: 'neutral',
      securityLevel: 'loose',
      themeVariables: {
        primaryColor:       '#faf2e3',
        primaryTextColor:   '#1a1714',
        primaryBorderColor: '#b8651b',
        lineColor:          '#756f66',
        fontFamily:         'Inter, sans-serif',
      },
    });
  }

  // =========================================================================
  // Entry point
  // =========================================================================

  whenReady(function () {
    sidePanel    = document.getElementById('sidePanel');
    sideTitle    = document.getElementById('sideTitle');
    sideEyebrow  = document.getElementById('sideEyebrow');
    sideBody     = document.getElementById('sideBody');
    sideCloseBtn = document.getElementById('sideCloseBtn');

    // Side panel is optional — if the renderer ever ships a panel-less view,
    // graph + scroll-spy + mermaid still work.
    if (sidePanel) {
      sidePanel.setAttribute('aria-hidden', 'true');
    }

    initGraph();
    initFlowGraphs();
    if (sidePanel && sideBody) wireInteractions();
    wireFlowToggles();
    initScrollSpy();
    initMermaid();
  });
})();
