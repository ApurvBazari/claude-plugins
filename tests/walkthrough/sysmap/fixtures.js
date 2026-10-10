/* Fixture graphs for the system-map engine belt and the golden page.
   Shape is the walkthrough model: flat nodes[] with `parent`, edges[] with `flow`.
   `graphs` and `pair` feed the belt and the page; `nested` is drawn on the golden page only. */
'use strict';
const n = (id, label, kind, sub, parent, extra) => Object.assign({ id, label, kind, sub, parent }, extra || {});
const g = (id, label, parent, extra) => Object.assign({ id, label, parent }, extra || {});
const e = (from, to, label, flow, extra) => Object.assign({ from, to, label, flow: flow || 'sync' }, extra || {});

const small = {
  slug: 'small', title: 'Link shortener',
  nodes: [
    n('visitor', 'Visitor', 'actor', 'browser'), n('cdn', 'CDN', 'external', 'edge cache'),
    g('svc', 'Link shortener'),
    n('web', 'Web app', 'service', 'Next.js', 'svc'), n('api', 'Redirect API', 'service', 'Go', 'svc'),
    n('cache', 'Hot links', 'store', 'Redis', 'svc'), n('db', 'Links DB', 'store', 'Postgres', 'svc'),
    n('q', 'Click events', 'queue', 'Kafka', 'svc'), n('worker', 'Stats worker', 'service', 'Go', 'svc'),
  ],
  edges: [
    e('visitor', 'cdn', 'GET /abc'), e('cdn', 'web', 'cache miss'), e('web', 'api', 'resolve'),
    e('api', 'cache', 'lookup'), e('api', 'db', 'read on miss'), e('api', 'q', 'click', 'async'),
    e('q', 'worker', 'consume', 'async'), e('worker', 'db', 'write stats'),
  ],
};

const medium = {
  slug: 'medium', title: 'Online shop',
  nodes: [
    n('customer', 'Customer', 'actor', 'browser'), n('admin', 'Admin', 'actor', 'back office'),
    g('edge', 'Edge'), n('cdn', 'CDN', 'service', 'static + cache', 'edge'), n('gw', 'API gateway', 'service', 'Envoy', 'edge'),
    g('shop', 'Shop services'),
    n('web', 'Storefront', 'service', 'Next.js', 'shop'), n('catalog', 'Catalog', 'service', 'Node', 'shop'),
    n('cart', 'Cart', 'service', 'Node', 'shop'), n('checkout', 'Checkout', 'service', 'Kotlin', 'shop'),
    n('auth', 'Auth', 'service', 'Go', 'shop'),
    g('data', 'Data'),
    n('catalogdb', 'Catalog DB', 'store', 'Postgres', 'data'), n('ordersdb', 'Orders DB', 'store', 'Postgres', 'data'),
    n('sessions', 'Sessions', 'store', 'Redis', 'data'), n('search', 'Search index', 'store', 'OpenSearch', 'data'),
    g('async', 'Async'),
    n('bus', 'Event bus', 'queue', 'Kafka', 'async'), n('emailw', 'Email worker', 'service', 'Node', 'async'),
    n('invw', 'Inventory worker', 'service', 'Kotlin', 'async'),
    n('payments', 'Payments', 'external', 'PSP'), n('emailp', 'Email provider', 'external', 'SMTP API'),
  ],
  edges: [
    e('customer', 'cdn', 'HTTPS'), e('admin', 'gw', 'admin API'), e('cdn', 'gw', 'dynamic'),
    e('gw', 'web', 'route'), e('gw', 'auth', 'verify token'),
    e('web', 'catalog', 'browse'), e('web', 'cart', 'add item'), e('web', 'checkout', 'place order'),
    e('catalog', 'catalogdb', 'read'), e('catalog', 'search', 'query'), e('cart', 'sessions', 'cart state'),
    e('auth', 'sessions', 'session'), e('checkout', 'ordersdb', 'write order'), e('checkout', 'payments', 'charge'),
    e('checkout', 'bus', 'order.placed', 'async'), e('bus', 'emailw', 'fan-out', 'async'), e('bus', 'invw', 'fan-out', 'async'),
    e('emailw', 'emailp', 'send'), e('invw', 'catalogdb', 'decrement stock'), e('payments', 'gw', 'webhook'),
    e('checkout', 'cart', 'clear cart'),
  ],
};

const large = {
  slug: 'large', title: 'Ride-hailing platform',
  nodes: [
    n('rider', 'Rider', 'actor', 'mobile app'), n('driver', 'Driver', 'actor', 'mobile app'), n('ops', 'Ops', 'actor', 'internal'),
    g('edge', 'Edge'),
    n('lb', 'Load balancer', 'service', 'L7', 'edge'), n('apigw', 'API gateway', 'service', 'Envoy', 'edge'),
    n('wsgw', 'WebSocket gateway', 'service', 'Go', 'edge'),
    g('core', 'Core services'),
    g('trips', 'Trips', 'core'),
    n('tripapi', 'Trip API', 'service', 'Kotlin', 'trips'), n('matching', 'Matching', 'service', 'Go', 'trips'),
    n('pricing', 'Pricing', 'service', 'Go', 'trips'), n('eta', 'ETA', 'service', 'Python', 'trips'),
    g('identity', 'Identity', 'core'),
    n('auth', 'Auth', 'service', 'Go', 'identity'), n('profiles', 'Profiles', 'service', 'Kotlin', 'identity'),
    n('kyc', 'KYC', 'service', 'Kotlin', 'identity'),
    g('pay', 'Payments', 'core'),
    n('billing', 'Billing', 'service', 'Kotlin', 'pay'), n('wallet', 'Wallet', 'service', 'Kotlin', 'pay'),
    n('payouts', 'Payouts', 'service', 'Kotlin', 'pay'), n('fraud', 'Fraud scoring', 'service', 'Python', 'pay'),
    g('rt', 'Realtime'),
    n('locingest', 'Location ingest', 'service', 'Go', 'rt'), n('geoidx', 'Geo index', 'store', 'Redis + H3', 'rt'),
    n('dispatchq', 'Dispatch stream', 'queue', 'Kafka', 'rt'), n('notifier', 'Notifier', 'service', 'Go', 'rt'),
    g('data', 'Data stores'),
    n('tripsdb', 'Trips DB', 'store', 'Postgres', 'data'), n('usersdb', 'Users DB', 'store', 'Postgres', 'data'),
    n('ledger', 'Ledger', 'store', 'Postgres', 'data'), n('cache', 'Cache', 'store', 'Redis', 'data'),
    n('blob', 'Blob store', 'store', 'S3', 'data'),
    g('analytics', 'Analytics'),
    n('bus', 'Event bus', 'queue', 'Kafka', 'analytics'), n('stream', 'Stream processor', 'service', 'Flink', 'analytics'),
    n('wh', 'Warehouse', 'store', 'BigQuery', 'analytics'), n('dash', 'Dashboards', 'service', 'Looker', 'analytics'),
    n('maps', 'Maps', 'external', 'routing API'), n('psp', 'PSP', 'external', 'card payments'), n('sms', 'SMS', 'external', 'gateway'),
    n('push', 'Push', 'external', 'APNs / FCM'), n('idcheck', 'ID check', 'external', 'KYC vendor'),
  ],
  edges: [
    e('rider', 'lb', 'app API'), e('driver', 'lb', 'app API'), e('driver', 'wsgw', 'location stream'),
    e('rider', 'wsgw', 'trip updates'), e('ops', 'dash', 'monitor'),
    e('lb', 'apigw', 'forward'), e('apigw', 'auth', 'verify'), e('apigw', 'tripapi', 'trips'),
    e('apigw', 'profiles', 'profile'), e('apigw', 'billing', 'payments'), e('wsgw', 'locingest', 'GPS pings'),
    e('tripapi', 'matching', 'find driver'), e('tripapi', 'pricing', 'quote'), e('tripapi', 'eta', 'estimate'),
    e('tripapi', 'tripsdb', 'persist'), e('tripapi', 'bus', 'trip events', 'async'),
    e('matching', 'geoidx', 'nearby drivers'), e('matching', 'dispatchq', 'offer', 'async'), e('pricing', 'cache', 'surge'),
    e('eta', 'maps', 'routes'), e('pricing', 'maps', 'distance'),
    e('auth', 'usersdb', 'credentials'), e('auth', 'cache', 'sessions'), e('profiles', 'usersdb', 'read/write'),
    e('profiles', 'blob', 'photos'), e('kyc', 'idcheck', 'verify ID'), e('kyc', 'blob', 'documents'), e('profiles', 'kyc', 'start KYC'),
    e('billing', 'wallet', 'debit'), e('billing', 'psp', 'charge'), e('billing', 'fraud', 'score'), e('wallet', 'ledger', 'entries'),
    e('payouts', 'ledger', 'entries'), e('payouts', 'psp', 'transfer'), e('fraud', 'cache', 'signals'),
    e('billing', 'bus', 'payment events', 'async'),
    e('locingest', 'geoidx', 'update'), e('locingest', 'bus', 'locations', 'async'), e('dispatchq', 'notifier', 'consume', 'async'),
    e('notifier', 'push', 'notify'), e('notifier', 'sms', 'fallback'), e('notifier', 'wsgw', 'socket push'),
    e('bus', 'stream', 'consume', 'async'), e('stream', 'wh', 'load'), e('dash', 'wh', 'query'), e('stream', 'fraud', 'features'),
  ],
};

const chain = {
  slug: 'chain', title: 'Request path',
  nodes: [n('req', 'Request', 'actor', 'client'), n('authz', 'Auth check', 'service', 'middleware'),
    n('handler', 'Handler', 'service', 'route'), n('store', 'Store', 'store', 'SQLite')],
  edges: [e('req', 'authz', 'HTTP'), e('authz', 'handler', 'allowed'), e('handler', 'store', 'query')],
};

// Two sibling groups whose cross wires are declared in opposite order: the case where wires cross.
const twogroups = {
  slug: 'twogroups', title: 'Producers and consumers',
  nodes: [
    g('prod', 'Producers'),
    n('p1', 'Orders', 'service', 'Kotlin', 'prod'), n('p2', 'Payments', 'service', 'Kotlin', 'prod'),
    n('p3', 'Shipping', 'service', 'Go', 'prod'), n('p4', 'Returns', 'service', 'Go', 'prod'),
    g('cons', 'Consumers'),
    n('c1', 'Returns desk', 'service', 'Node', 'cons'), n('c2', 'Tracking', 'service', 'Node', 'cons'),
    n('c3', 'Ledger', 'store', 'Postgres', 'cons'), n('c4', 'Order history', 'store', 'Postgres', 'cons'),
  ],
  edges: [
    e('p1', 'c4', 'order placed', 'async'), e('p2', 'c3', 'payment taken', 'async'),
    e('p3', 'c2', 'parcel moved', 'async'), e('p4', 'c1', 'return opened', 'async'), e('p1', 'c2', 'label made'),
  ],
};

// A module dependency graph: unlabelled import edges with shared leaves.
const deps = {
  slug: 'deps', title: 'Package imports',
  nodes: [n('cli', 'cli'), n('plugins', 'plugins'), n('core', 'core'), n('config', 'config'), n('parser', 'parser'), n('utils', 'utils')],
  edges: [e('cli', 'core'), e('cli', 'config'), e('plugins', 'core'), e('plugins', 'utils'), e('core', 'parser'),
    e('core', 'utils'), e('config', 'utils'), e('parser', 'utils')],
};

// A before/after pair: every change mark, an inferred box and wire, a forced-open and a forced-closed group.
const before = {
  id: 'before', slug: 'before', title: 'Shop: before',
  nodes: [
    n('customer', 'Customer', 'actor', 'browser'),
    g('shop', 'Shop'),
    n('web', 'Storefront', 'service', 'Next.js', 'shop'), n('catalog', 'Catalog', 'service', 'Node', 'shop'),
    n('legacy', 'Legacy search', 'service', 'PHP', 'shop'),
    g('data', 'Data'),
    n('catalogdb', 'Catalog DB', 'store', 'Postgres', 'data'), n('sessions', 'Sessions', 'store', 'Redis', 'data'),
    n('mail', 'Email provider', 'external', 'SMTP API'),
  ],
  edges: [
    e('customer', 'web', 'HTTPS'), e('web', 'catalog', 'browse'), e('web', 'legacy', 'search'),
    e('catalog', 'catalogdb', 'read'), e('legacy', 'catalogdb', 'LIKE query'), e('web', 'sessions', 'session'),
    e('web', 'mail', 'receipts'),
  ],
};
const after = {
  id: 'after', slug: 'after', title: 'Shop: after', compareTo: 'before',
  nodes: [
    n('customer', 'Customer', 'actor', 'browser'),
    g('shop', 'Shop', null, { open: true }),
    n('web', 'Storefront', 'service', 'Next.js', 'shop'),
    n('catalog', 'Catalog', 'service', 'Node', 'shop', { change: 'modified' }),
    n('legacy', 'Legacy search', 'service', 'PHP', 'shop', { change: 'deleted' }),
    n('search', 'Search', 'service', 'Go', 'shop', { change: 'added' }),
    g('data', 'Data', null, { open: false }),
    n('catalogdb', 'Catalog DB', 'store', 'Postgres', 'data'), n('sessions', 'Sessions', 'store', 'Redis', 'data'),
    n('searchidx', 'Search index', 'store', 'OpenSearch', 'data', { change: 'added' }),
    n('bus', 'Change feed', 'queue', 'Kafka', null, { change: 'added', inferred: true }),
    n('mail', 'Email provider', 'external', 'SMTP API'),
  ],
  edges: [
    e('customer', 'web', 'HTTPS'), e('web', 'catalog', 'browse'),
    e('web', 'legacy', 'search', 'sync', { change: 'deleted' }),
    e('web', 'search', 'search', 'sync', { change: 'added' }),
    e('catalog', 'catalogdb', 'read + write', 'sync', { change: 'modified' }),
    e('legacy', 'catalogdb', 'LIKE query', 'sync', { change: 'deleted' }),
    e('search', 'searchidx', 'query', 'sync', { change: 'added' }),
    e('catalog', 'bus', 'product changed', 'async', { change: 'added', inferred: true }),
    e('bus', 'search', 'reindex', 'async', { change: 'added', inferred: true }),
    e('web', 'sessions', 'session'), e('web', 'mail', 'receipts'),
  ],
};

// Golden page only (the layout belt does not loop over it): the cases that only a browser can judge.
// A group forced closed inside a group forced open, so the first paint has a closed group in an open one;
// a group with a change mark; an inferred group; and boxes that have a detail and a change mark.
const nested = {
  slug: 'nested', title: 'Video platform',
  nodes: [
    n('viewer', 'Viewer', 'actor', 'web player'),
    g('platform', 'Video platform', null, { open: true }),
    n('upload', 'Upload API', 'service', 'Go', 'platform', { change: 'modified' }),
    n('meta', 'Metadata DB', 'store', 'Postgres', 'platform', { change: 'modified' }),
    g('encode', 'Encoding', 'platform', { open: false, change: 'modified' }),
    n('split', 'Splitter', 'service', 'Rust', 'encode'),
    n('h265', 'H.265 encoder', 'service', 'Rust', 'encode', { change: 'added' }),
    n('chunks', 'Chunk store', 'store', 'S3', 'encode'),
    g('recs', 'Recommendations', 'platform', { inferred: true }),
    n('ranker', 'Ranker', 'service', 'Python', 'recs'),
    n('feats', 'Feature cache', 'store', 'Redis', 'recs', { inferred: true }),
    n('delivery', 'Delivery network', 'external', 'CDN'),
  ],
  edges: [
    e('viewer', 'upload', 'publish'), e('viewer', 'ranker', 'home feed'),
    e('upload', 'meta', 'write record', 'sync', { change: 'modified' }), e('upload', 'split', 'new upload'),
    e('split', 'h265', 'segments', 'sync', { change: 'added' }),
    e('h265', 'chunks', 'write chunks', 'sync', { change: 'added' }),
    e('chunks', 'delivery', 'origin pull'), e('ranker', 'meta', 'read titles'),
    e('ranker', 'feats', 'lookup', 'sync', { inferred: true }),
  ],
};

module.exports = { graphs: [small, medium, large, chain, twogroups, deps], pair: { before, after }, nested };
