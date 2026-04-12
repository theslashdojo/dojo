---
name: reverse-proxy
description: Proxy HTTP/WebSocket traffic to backend servers with upstream groups, load balancing, and failover — use when putting nginx in front of application servers
---

# Nginx Reverse Proxy

Configure nginx to forward client requests to one or more backend application servers with load balancing, proper header forwarding, WebSocket support, and response caching.

## When to Use

- Putting nginx in front of a Node.js, Python, Go, or other application server
- Load balancing traffic across multiple backend instances
- Proxying WebSocket connections (chat, real-time updates)
- Caching upstream responses
- Setting up failover with backup servers
- Forwarding client IP and protocol information to backends

## Workflow

1. **Define upstream group** with backend server addresses and load balancing method
2. **Create server block** with `listen`, `server_name` (see [[nginx/config]])
3. **Add location block** with `proxy_pass http://upstream_name`
4. **Set proxy headers** for client identity forwarding
5. **Add WebSocket support** if needed (Upgrade/Connection headers)
6. **Configure timeouts and buffering** based on backend characteristics
7. **Validate and reload**: `nginx -t && nginx -s reload`

## Minimal Reverse Proxy

```nginx
server {
    listen 80;
    server_name example.com;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Load Balanced Reverse Proxy

```nginx
upstream app_backend {
    least_conn;
    server 10.0.0.1:3000 weight=5;
    server 10.0.0.2:3000 weight=3;
    server 10.0.0.3:3000 backup;
    keepalive 32;
}

server {
    listen 80;
    server_name example.com;

    location / {
        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "";

        # Failover
        proxy_next_upstream error timeout http_502 http_503;
        proxy_next_upstream_tries 3;
    }
}
```

## WebSocket Proxy

```nginx
location /ws/ {
    proxy_pass http://app_backend;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_read_timeout 86400s;
    proxy_send_timeout 86400s;
}
```

## Server-Sent Events (SSE)

```nginx
location /events/ {
    proxy_pass http://app_backend;
    proxy_http_version 1.1;
    proxy_set_header Connection "";
    proxy_buffering off;
    proxy_cache off;
    proxy_read_timeout 86400s;
}
```

## Load Balancing Methods

| Method | Directive | Best For |
|--------|-----------|----------|
| Round-robin | (default) | Equal servers, stateless apps |
| Least connections | `least_conn` | Variable request duration |
| IP hash | `ip_hash` | Session affinity without cookies |
| Hash | `hash $request_uri consistent` | Cache distribution, consistent hashing |
| Random | `random two least_conn` | Large server pools |

## Common Proxy Headers

Always set these so backends know about the real client:

```nginx
proxy_set_header Host $host;                                    # Original Host header
proxy_set_header X-Real-IP $remote_addr;                        # Client IP
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;    # Proxy chain
proxy_set_header X-Forwarded-Proto $scheme;                     # http or https
```

## Edge Cases

- **Trailing slash matters**: `proxy_pass http://backend/` strips the location prefix; `proxy_pass http://backend` preserves it
- **WebSocket idle timeout**: Default `proxy_read_timeout 60s` will close idle WebSocket connections — increase to `86400s` or higher
- **Upstream keepalive**: Clear the Connection header (`proxy_set_header Connection ""`) and set `proxy_http_version 1.1` to enable keepalive to backends
- **Large request bodies**: Set `client_max_body_size` in the server block (default 1m) — file uploads will fail with 413 without this
- **Buffering vs streaming**: Disable `proxy_buffering` for SSE/streaming endpoints, keep enabled for normal requests
- **IP hash with `down`**: When removing a server from an `ip_hash` upstream, mark it `down` instead of deleting — this preserves hash distribution for remaining servers

## Script

Generate a complete reverse proxy config:

```bash
SITE_NAME=myapp \
SERVER_NAME=example.com \
BACKEND_SERVERS="127.0.0.1:3000,127.0.0.1:3001" \
LB_METHOD=least-conn \
WEBSOCKET_PATH=/ws/ \
./scripts/setup-reverse-proxy.sh
```
