'use strict';

const REFRESH_MS = 2000;
let lastRendered = '';

async function fetchState() {
  const r = await fetch('/state.json', { cache: 'no-store' });
  if (r.status === 503) return null;
  if (!r.ok) throw new Error('state fetch failed: ' + r.status);
  return r.json();
}

function makeCard(phaseKey, phase) {
  const card = document.createElement('article');
  card.className = 'card ' + phase.status.toLowerCase().replace('_', '-');
  card.dataset.phase = phaseKey;
  card.dataset.status = phase.status;

  const statusEl = document.createElement('div');
  statusEl.className = 'card-status';
  statusEl.textContent = phase.status;
  card.appendChild(statusEl);

  const iconEl = document.createElement('div');
  iconEl.className = 'card-icon';
  iconEl.textContent = phase.icon || '';
  card.appendChild(iconEl);

  const labelEl = document.createElement('div');
  labelEl.className = 'card-label';
  labelEl.textContent = phase.label || phaseKey;
  card.appendChild(labelEl);

  const hintEl = document.createElement('div');
  hintEl.className = 'card-hint';
  hintEl.textContent = phase.hint || '';
  card.appendChild(hintEl);

  if (phase.blockingReason) {
    const blockerEl = document.createElement('div');
    blockerEl.className = 'card-blocker';
    blockerEl.textContent = phase.blockingReason;
    card.appendChild(blockerEl);
  }

  card.addEventListener('click', () => onCardClick(phaseKey, phase));
  return card;
}

function renderMap(state) {
  document.getElementById('project-name').textContent = state.project || 'project';
  document.getElementById('completion-progress').textContent =
    state.completionPolicy.currentApproved + ' / ' + state.completionPolicy.requiredApproved;

  document.querySelectorAll('.layer-cards').forEach((el) => {
    while (el.firstChild) el.removeChild(el.firstChild);
  });

  for (const [phaseKey, phase] of Object.entries(state.phases)) {
    if (phase.status === 'HIDDEN') continue;
    const card = makeCard(phaseKey, phase);
    const slot = document.querySelector('.layer[data-layer="' + phase.layer + '"] .layer-cards');
    if (slot) slot.appendChild(card);
  }
}

async function onCardClick(phaseKey, phase) {
  if (phase.status === 'LOCKED') {
    showToast('Locked. ' + (phase.blockingReason || 'prerequisites not met'));
    return;
  }
  if (phase.status === 'APPROVED') {
    window.open('/adr/' + phaseToKebab(phaseKey), '_blank');
    return;
  }
  if (phase.status === 'AVAILABLE' || phase.status === 'PARKED') {
    try {
      const r = await fetch('/intent', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'activate', phase: phaseKey })
      });
      if (r.status === 409) {
        showToast('Another phase is already in progress. Finish it in the CLI first.');
        return;
      }
      if (r.ok) {
        showToast('Back to the CLI. Claude is waiting to ask about ' + phase.label + '.');
      } else {
        showToast('Error: ' + r.status);
      }
    } catch (e) {
      showToast('Network error: ' + e.message);
    }
    return;
  }
  showToast('This phase is in progress in the CLI.');
}

function phaseToKebab(name) {
  return name.replace(/([A-Z])/g, '-$1').toLowerCase().replace(/^-/, '');
}

function showToast(msg) {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.hidden = false;
  clearTimeout(showToast._timer);
  showToast._timer = setTimeout(() => { t.hidden = true; }, 5000);
}

async function tick() {
  try {
    const state = await fetchState();
    if (!state) return;
    const sig = JSON.stringify(state.phases) + state.completionPolicy.currentApproved;
    if (sig !== lastRendered) {
      renderMap(state);
      lastRendered = sig;
    }
  } catch (e) {
    // network errors are silent; retry next tick
  }
}

document.getElementById('refresh-btn').addEventListener('click', () => { lastRendered = ''; tick(); });

tick();
setInterval(tick, REFRESH_MS);
