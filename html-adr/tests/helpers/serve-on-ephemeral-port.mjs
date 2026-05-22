/**
 * Serve a directory over HTTP on an OS-assigned port.
 *
 * Returns { port, close } where:
 *   - port:  the port the OS assigned (use http://127.0.0.1:${port}/<file>)
 *   - close: async function that shuts the server down
 *
 * Used by render-runtime.smoke.mjs to exercise rendered HTML in a browser
 * over http:// (rather than file://), matching how reviewers actually open
 * the files via Live Server / a dev preview server.
 *
 * Listening on 127.0.0.1 only — never bind to all interfaces from a test.
 */
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { join, extname } from 'node:path';

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js':   'application/javascript; charset=utf-8',
  '.css':  'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg':  'image/svg+xml',
};

export async function serveOnEphemeralPort(rootDir) {
  const server = createServer(async (req, res) => {
    try {
      const url = new URL(req.url, 'http://127.0.0.1');
      let path = url.pathname;
      if (path === '/' || path.endsWith('/')) path += 'index.html';
      const filePath = join(rootDir, path);
      const st = await stat(filePath);
      if (!st.isFile()) { res.writeHead(404); res.end('not file'); return; }
      const body = await readFile(filePath);
      res.writeHead(200, { 'content-type': MIME[extname(filePath)] || 'application/octet-stream' });
      res.end(body);
    } catch (e) {
      res.writeHead(404);
      res.end(String(e?.message || e));
    }
  });

  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  const close = () => new Promise((resolve) => server.close(resolve));
  return { port, close };
}
