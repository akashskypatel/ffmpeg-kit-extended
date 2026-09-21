import {createServer} from 'node:http';
import {readFile, stat} from 'node:fs/promises';
import path from 'node:path';

const root = path.resolve(process.argv[2] ?? 'build/web');
const port = Number(process.argv[3] ?? 8080);
const contentTypes = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
  '.woff2': 'font/woff2',
};

function filePathFor(requestUrl) {
  const pathname = decodeURIComponent(
    new URL(requestUrl, 'http://127.0.0.1').pathname,
  );
  const relativePath = pathname === '/' ? 'index.html' : pathname.slice(1);
  const filePath = path.resolve(root, relativePath);
  const relativeToRoot = path.relative(root, filePath);
  if (relativeToRoot.startsWith('..') || path.isAbsolute(relativeToRoot)) {
    return null;
  }
  return filePath;
}

const server = createServer(async (request, response) => {
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    response.writeHead(405, {'content-type': 'text/plain; charset=utf-8'});
    response.end('Method Not Allowed');
    return;
  }

  let filePath;
  try {
    filePath = filePathFor(request.url ?? '/');
  } catch {
    response.writeHead(400, {'content-type': 'text/plain; charset=utf-8'});
    response.end('Bad Request');
    return;
  }
  if (filePath === null) {
    response.writeHead(403, {'content-type': 'text/plain; charset=utf-8'});
    response.end('Forbidden');
    return;
  }

  try {
    const fileStats = await stat(filePath);
    if (!fileStats.isFile()) throw new Error('Not a file');
    const headers = {
      'content-type': contentTypes[path.extname(filePath)] ?? 'application/octet-stream',
      'cross-origin-embedder-policy': 'require-corp',
      'cross-origin-opener-policy': 'same-origin',
      'cross-origin-resource-policy': 'same-origin',
    };
    response.writeHead(200, headers);
    if (request.method === 'HEAD') {
      response.end();
    } else {
      response.end(await readFile(filePath));
    }
  } catch {
    response.writeHead(404, {'content-type': 'text/plain; charset=utf-8'});
    response.end('Not Found');
  }
});

server.listen(port, '127.0.0.1', () => {
  console.log(`Serving ${root} at http://127.0.0.1:${port}`);
});
