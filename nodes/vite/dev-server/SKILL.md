---
name: dev-server
description: Start and configure Vite's dev server — use when running local development, setting up API proxying, configuring HMR, enabling HTTPS, or integrating with Express/Connect
---

# Vite Dev Server

Start, configure, and troubleshoot Vite's lightning-fast development server.

## When to Use

- Starting a local development server for a Vite project
- Proxying API requests to a backend during development
- Fixing HMR (Hot Module Replacement) issues
- Enabling HTTPS for local development
- Exposing the dev server to the local network (Docker, WSL2, mobile testing)
- Integrating Vite into an existing Express/Connect server (middleware mode)
- Restricting which files the dev server can serve
- Speeding up initial page load with warmup

## Quick Reference

```bash
# Start dev server (all equivalent)
vite
vite dev
vite serve

# Common flags
vite --host 0.0.0.0          # expose to network
vite --host                   # shorthand for 0.0.0.0
vite --port 3000              # custom port
vite --open                   # open browser
vite --open /dashboard        # open specific path
vite --strictPort             # fail if port taken (default: auto-increment)
vite --force                  # re-bundle dependencies
vite --config vite.custom.ts  # custom config file
```

## Workflow: Configure Host and Port

```typescript
// vite.config.ts
import { defineConfig } from 'vite'

export default defineConfig({
  server: {
    host: '0.0.0.0',      // or true — expose to all interfaces
    port: 3000,            // default: 5173
    strictPort: true,      // error if port in use
    open: true,            // open browser on start
  }
})
```

Use `host: '0.0.0.0'` or `host: true` when:
- Running in Docker (container localhost is not host localhost)
- Running in WSL2 and accessing from Windows browser
- Testing on mobile devices on the same network
- Running in GitHub Codespaces or cloud dev environments

## Workflow: Proxy API Requests

Route `/api` requests to a backend during development:

```typescript
export default defineConfig({
  server: {
    proxy: {
      // /api/users -> http://localhost:4000/api/users
      '/api': 'http://localhost:4000',
    }
  }
})
```

Rewrite paths so `/api/users` hits `http://localhost:4000/users`:

```typescript
export default defineConfig({
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:4000',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ''),
      }
    }
  }
})
```

Proxy WebSocket connections:

```typescript
export default defineConfig({
  server: {
    proxy: {
      '/socket.io': {
        target: 'ws://localhost:4000',
        ws: true,
      }
    }
  }
})
```

Proxy with regex matching and custom headers:

```typescript
export default defineConfig({
  server: {
    proxy: {
      '^/fallback/.*': {
        target: 'http://localhost:4000',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/fallback/, ''),
      },
      '/secure': {
        target: 'https://localhost:4443',
        secure: false,      // accept self-signed backend certs
        configure: (proxy) => {
          proxy.on('proxyReq', (proxyReq, req) => {
            proxyReq.setHeader('X-Forwarded-For', req.socket.remoteAddress)
          })
        },
      }
    }
  }
})
```

Note: proxy rules only apply to the dev server. Configure nginx/Caddy for production.

## Workflow: Configure HMR

HMR works automatically for CSS, Vue SFCs, React (with plugin), and Svelte. Configure the WebSocket connection when behind a reverse proxy:

```typescript
export default defineConfig({
  server: {
    hmr: {
      protocol: 'wss',       // use wss behind HTTPS proxy
      host: 'myapp.dev',     // external hostname
      clientPort: 443,       // port the browser connects to
    }
  }
})
```

Disable the error overlay:

```typescript
export default defineConfig({
  server: {
    hmr: {
      overlay: false,
    }
  }
})
```

Disable HMR entirely:

```typescript
export default defineConfig({
  server: {
    hmr: false,
  }
})
```

### HMR Troubleshooting Checklist

1. **HMR WebSocket not connecting** — Check firewall, set `server.hmr.host` explicitly. Behind a reverse proxy, set `clientPort` to the external port.
2. **Full page reloads instead of hot update** — The changed module has no HMR boundary. Ensure the framework plugin is installed (`@vitejs/plugin-react`, `@vitejs/plugin-vue`, etc.).
3. **HMR slow on large projects** — Add frequently imported modules to `server.warmup.clientFiles`.
4. **WebSocket blocked by corporate proxy** — Try setting `server.hmr.protocol: 'wss'` and routing through port 443.
5. **Changes not detected at all** — Check `server.watch` options. In Docker bind mounts, set `usePolling: true`.

## Workflow: Enable HTTPS

With mkcert (trusted local certificates):

```bash
brew install mkcert    # macOS; use choco/scoop on Windows
mkcert -install
mkdir -p certs
mkcert -key-file certs/localhost-key.pem -cert-file certs/localhost-cert.pem localhost 127.0.0.1 ::1
```

```typescript
import fs from 'node:fs'
import { defineConfig } from 'vite'

export default defineConfig({
  server: {
    https: {
      key: fs.readFileSync('certs/localhost-key.pem'),
      cert: fs.readFileSync('certs/localhost-cert.pem'),
    }
  }
})
```

Quick self-signed certs (no mkcert):

```typescript
import basicSsl from '@vitejs/plugin-basic-ssl'

export default defineConfig({
  plugins: [basicSsl()],
})
```

Install with: `npm i -D @vitejs/plugin-basic-ssl`

## Workflow: Middleware Mode (Express Integration)

Mount Vite as middleware in a custom Node.js server for SSR or complex backends:

```typescript
import express from 'express'
import { createServer as createViteServer } from 'vite'
import fs from 'node:fs'

async function start() {
  const app = express()

  const vite = await createViteServer({
    server: { middlewareMode: true },
    appType: 'custom',
  })

  app.use(vite.middlewares)

  app.get('/api/data', (req, res) => {
    res.json({ ok: true })
  })

  app.use('*', async (req, res) => {
    const url = req.originalUrl
    const template = await vite.transformIndexHtml(
      url, fs.readFileSync('index.html', 'utf-8'))
    const { render } = await vite.ssrLoadModule('/src/entry-server.tsx')
    const html = template.replace('<!--ssr-outlet-->', await render(url))
    res.status(200).set({ 'Content-Type': 'text/html' }).end(html)
  })

  app.listen(3000, () => console.log('http://localhost:3000'))
}
start()
```

Key points:
- Set `middlewareMode: true` and `appType: 'custom'`
- Vite does NOT start its own HTTP server
- Use `vite.transformIndexHtml()` for HTML processing
- Use `vite.ssrLoadModule()` to import server-side modules with HMR
- Call `vite.close()` on shutdown

## Workflow: File System Restrictions

```typescript
export default defineConfig({
  server: {
    fs: {
      strict: true,
      allow: [
        '/path/to/shared-packages',   // allow outside project root
      ],
      deny: [
        '.env', '.env.*',
        '*.pem', '*.key',
        '**/.git/**',
      ],
    }
  }
})
```

`deny` is checked before `allow`. Default deny: dotfiles. Default allow: project root, workspace root, symlinked deps.

## Workflow: Warmup Modules

Pre-transform files at startup to reduce first-load latency:

```typescript
export default defineConfig({
  server: {
    warmup: {
      clientFiles: [
        './src/main.tsx',
        './src/components/**/*.tsx',
      ],
      ssrFiles: [
        './src/entry-server.tsx',
      ],
    }
  }
})
```

Only warm files that are imported early. Warming too many wastes startup time.

## Workflow: Watch Options (Docker / NFS)

```typescript
export default defineConfig({
  server: {
    watch: {
      usePolling: true,     // required for Docker bind mounts, NFS, WSL2 cross-FS
      interval: 100,        // polling interval in ms
    }
  }
})
```

## Edge Cases

- **Docker**: Use `host: '0.0.0.0'`, `watch: { usePolling: true }`. Ensure port is mapped in docker-compose (`ports: ["5173:5173"]`). HMR WebSocket also needs the port exposed.
- **WSL2**: If accessing from Windows browser, set `host: '0.0.0.0'`. File watching across Windows/Linux filesystems requires `usePolling: true`.
- **Network exposure**: `host: '0.0.0.0'` binds to all interfaces. Use `server.allowedHosts` to restrict which hostnames are accepted, preventing DNS rebinding attacks.
- **Port conflicts**: By default Vite auto-increments the port. Set `strictPort: true` to fail instead, useful in CI or scripted setups.
- **CORS**: Defaults to allowing all origins. For fine-grained control, pass an object to `server.cors` with `origin`, `methods`, `credentials`.
- **SharedArrayBuffer**: Requires `Cross-Origin-Embedder-Policy: require-corp` and `Cross-Origin-Opener-Policy: same-origin` headers — set via `server.headers`.
- **monorepo**: `server.fs.allow` auto-includes the workspace root. If a linked package is outside the workspace, add its path explicitly.
- **Multiple proxies on same path**: Later entries override earlier ones. Use `configure` hook for conditional routing logic.
