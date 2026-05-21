import { spawnSync } from 'node:child_process';
import { dirname } from 'node:path';

function gitOk(args, cwd) {
  const r = spawnSync('git', args, { cwd, encoding: 'utf8' });
  return r.status === 0 ? r.stdout.trim() : null;
}

export function getProvenance(filePath) {
  const cwd = dirname(filePath);
  const date = gitOk(
    ['log', '--diff-filter=A', '--reverse', '--format=%cs', '--', filePath],
    cwd
  )?.split('\n')[0] ?? null;
  const authorsRaw = gitOk(['log', '--format=%an', '--', filePath], cwd);
  const authors = authorsRaw
    ? [...new Set(authorsRaw.split('\n').filter(Boolean))]
    : [];
  const branch = gitOk(['rev-parse', '--abbrev-ref', 'HEAD'], cwd);
  const dirty = gitOk(['status', '--porcelain', '--', filePath], cwd);

  return {
    date,
    authors,
    branch: branch && branch !== 'HEAD' ? branch : null,
    dirty: !!(dirty && dirty.length > 0),
  };
}
