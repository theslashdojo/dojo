---
name: config
description: Write, validate, and reload nginx configuration files — use when creating server blocks, virtual hosts, location routing, or managing nginx config lifecycle
---

# Nginx Configuration

Write, validate, enable, and reload nginx configuration files. Covers server blocks, location matching, directive syntax, and the config management lifecycle.

## When to Use

- Creating a new site/virtual host configuration
- Adding location blocks for routing rules
- Setting up static file serving
- Configuring logging formats
- Tuning nginx performance directives
- Enabling/disabling sites on Debian/Ubuntu systems

## Workflow

1. **Create config file** in `/etc/nginx/conf.d/SITENAME.conf` or `/etc/nginx/sites-available/SITENAME`
2. **Write server block** with `listen`, `server_name`, and `location` directives
3. **Validate syntax** with `nginx -t`
4. **Enable site** (if using sites-available model): `ln -s /etc/nginx/sites-available/SITENAME /etc/nginx/sites-enabled/`
5. **Reload nginx**: `nginx -s reload`

## Basic Server Block Template

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;

    root /var/www/example.com;
    index index.html;

    # Static file serving with SPA fallback
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API reverse proxy
    location /api/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Static assets with long cache
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff2)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # Block dotfiles
    location ~ /\. {
        deny all;
    }

    # Custom error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
}
```

## Location Matching

Nginx evaluates locations in this order:

1. **`= /exact`** — exact match, stops immediately
2. **`^~ /prefix`** — longest prefix, skips regex check
3. **`~ /regex`** — case-sensitive regex, first match wins
4. **`~* /regex`** — case-insensitive regex, first match wins
5. **`/prefix`** — longest prefix match (lowest priority)

## Config Validation

Always validate before reloading:

```bash
# Test syntax only
nginx -t

# Test and show full resolved configuration
nginx -T

# Find the active config file
nginx -V 2>&1 | grep 'conf-path'
```

If `nginx -t` fails, check the error message — it includes the file path and line number.

## Common Patterns

### HTTP to HTTPS Redirect

```nginx
server {
    listen 80;
    server_name example.com www.example.com;
    return 301 https://$host$request_uri;
}
```

### Upload Size Limit

```nginx
server {
    client_max_body_size 50m;  # default is 1m
}
```

### Rate Limiting

```nginx
http {
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

    server {
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://backend;
        }
    }
}
```

### Gzip Compression

```nginx
http {
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;
    gzip_min_length 256;
    gzip_vary on;
}
```

## Edge Cases

- **Default server**: If no `server_name` matches, nginx uses the first server block or the one marked `default_server` on the `listen` directive
- **Trailing slashes in proxy_pass**: `proxy_pass http://backend/` (with trailing slash) strips the matching location prefix; without it, the full URI is forwarded
- **Config file ordering**: `conf.d/*.conf` files are loaded alphabetically — prefix with numbers to control order (e.g., `00-default.conf`)
- **Duplicate listen directives**: Two server blocks can't both be `default_server` on the same port
- **Include paths**: Relative paths in `include` are relative to the nginx config directory, not the including file

## Script

The `manage-config.sh` script automates site config creation, validation, and reload. Run with:

```bash
SITE_NAME=myapp SERVER_NAME=example.com BACKEND_URL=http://127.0.0.1:3000 ./scripts/manage-config.sh
```
