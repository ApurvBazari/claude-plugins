import { readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';

export function findMentions(needle, sourceFilePath) {
  const dir = dirname(resolve(sourceFilePath));
  const sourceAbs = resolve(sourceFilePath);
  const hits = [];

  let entries;
  try { entries = readdirSync(dir); } catch { return hits; }

  for (const name of entries) {
    if (!name.endsWith('.md')) continue;
    const full = join(dir, name);
    if (resolve(full) === sourceAbs) continue;
    try {
      const stat = statSync(full);
      if (!stat.isFile()) continue;
      const text = readFileSync(full, 'utf8');
      if (text.includes(needle)) hits.push({ file: full });
    } catch { /* unreadable — skip */ }
  }
  return hits;
}
