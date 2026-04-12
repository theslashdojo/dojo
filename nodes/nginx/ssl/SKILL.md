---
name: ssl
description: Configure SSL/TLS certificates, HTTPS termination, and secure cipher suites on nginx — use when enabling HTTPS, installing certificates, or setting up Let's Encrypt
---

# Nginx SSL/TLS Configuration

Configure HTTPS on nginx with proper certificate setup, secure protocol/cipher selection, OCSP stapling, and automated certificate provisioning via Let's Encrypt.

## When to Use

- Enabling HTTPS on an nginx server
- Installing SSL/TLS certificates (Let's Encrypt, commercial, or self-signed)
- Configuring secure TLS protocol versions and cipher suites
- Setting up HTTP-to-HTTPS redirects
- Automating certificate renewal with certbot
- Adding security headers (HSTS, CSP)
- Generating self-signed certificates for development

## Workflow

1. **Obtain certificate** — Let's Encrypt (certbot), commercial CA, or self-signed
2. **Configure server block** with `listen 443 ssl` and certificate paths
3. **Set protocols and ciphers** — TLSv1.2 + TLSv1.3 only
4. **Enable session caching** for performance
5. **Enable OCSP stapling** for revocation checks
6. **Add HTTP-to-HTTPS redirect** — separate server block on port 80
7. **Add security headers** — HSTS, X-Content-Type-Options, etc.
8. **Validate and reload**: `nginx -t && nginx -s reload`
9. **Test**: `curl -vI https://yourdomain.com`

## Let's Encrypt (Recommended for Production)

```bash
# Install certbot with nginx plugin
sudo apt update && sudo apt install -y certbot python3-certbot-nginx

# Obtain cert and auto-configure nginx (interactive)
sudo certbot --nginx -d example.com -d www.example.com

# Non-interactive mode
sudo certbot --nginx -d example.com --non-interactive --agree-tos -m admin@example.com

# Test automatic renewal
sudo certbot renew --dry-run

# Check renewal timer
sudo systemctl status certbot.timer
```

## Full Manual SSL Config

```nginx
# HTTP → HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;

    # Allow ACME challenge for certbot renewal
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name example.com www.example.com;

    # Certificates
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    # Protocols and ciphers
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers off;

    # Session caching
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets on;

    # OCSP stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/letsencrypt/live/example.com/chain.pem;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options DENY always;

    # Your application
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Self-Signed Certificate (Development Only)

```bash
# Create directory
sudo mkdir -p /etc/nginx/ssl

# Generate self-signed cert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/selfsigned.key \
  -out /etc/nginx/ssl/selfsigned.crt \
  -subj "/C=US/ST=Dev/L=Local/O=Dev/CN=localhost"

# Optional: generate DH parameters
openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048
```

## SSL Reusable Snippet

Create `/etc/nginx/snippets/ssl-params.conf`:

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers HIGH:!aNULL:!MD5;
ssl_prefer_server_ciphers off;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;
ssl_session_tickets on;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

Then include in server blocks: `include snippets/ssl-params.conf;`

## Testing SSL

```bash
# Check certificate details
openssl s_client -connect example.com:443 -servername example.com </dev/null 2>/dev/null | \
  openssl x509 -text -noout

# Check expiration
echo | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null | \
  openssl x509 -enddate -noout

# Test OCSP stapling
openssl s_client -connect example.com:443 -status </dev/null 2>&1 | grep "OCSP"

# Test with curl
curl -vI https://example.com 2>&1 | grep -E 'SSL|TLS|certificate|HTTP/'
```

## Edge Cases

- **Certificate chain order**: `ssl_certificate` must contain server cert FIRST, then intermediates. Root CA is optional (browsers have it)
- **SNI required**: Multiple SSL sites on one IP require SNI. Use `ssl_reject_handshake on` on the default server to reject non-SNI requests
- **HSTS preload**: Only add `preload` to HSTS if you're ready to commit — removal from the preload list takes months
- **Certbot renewal hook**: Certbot auto-reloads nginx after renewal via `--deploy-hook "nginx -s reload"`
- **Port 80 required for certbot**: The HTTP-01 challenge needs port 80 accessible. Use DNS-01 challenge if port 80 is blocked
- **Self-signed warning**: Browsers show security warnings for self-signed certs. Use `mkcert` for local development to avoid this
- **DH parameters**: Not strictly needed with modern TLS 1.3, but `ssl_dhparam` improves security for TLS 1.2 DHE ciphers

## Script

Set up SSL automatically:

```bash
# Let's Encrypt
SERVER_NAME=example.com EMAIL=admin@example.com SSL_MODE=letsencrypt ./scripts/setup-ssl.sh

# Self-signed (development)
SERVER_NAME=localhost SSL_MODE=selfsigned ./scripts/setup-ssl.sh
```
