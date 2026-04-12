#!/usr/bin/env bash
# Configure SSL/TLS on nginx with Let's Encrypt or self-signed certificates
# Required: SERVER_NAME
# Optional: SSL_MODE (letsencrypt|selfsigned), EMAIL, CERT_PATH, KEY_PATH, NGINX_CONF_DIR
set -euo pipefail

SERVER_NAME="${SERVER_NAME:?SERVER_NAME is required (e.g., example.com)}"
SSL_MODE="${SSL_MODE:-letsencrypt}"
EMAIL="${EMAIL:-}"
CERT_PATH="${CERT_PATH:-}"
KEY_PATH="${KEY_PATH:-}"
NGINX_CONF_DIR="${NGINX_CONF_DIR:-/etc/nginx}"
SITE_NAME="${SITE_NAME:-${SERVER_NAME}}"

# Sanitize site name for filenames
SITE_NAME_SAFE=$(echo "$SITE_NAME" | sed 's/[^a-zA-Z0-9._-]/_/g')

# Determine config path
if [ -d "${NGINX_CONF_DIR}/sites-available" ]; then
    CONFIG_PATH="${NGINX_CONF_DIR}/sites-available/${SITE_NAME_SAFE}-ssl.conf"
else
    CONFIG_PATH="${NGINX_CONF_DIR}/conf.d/${SITE_NAME_SAFE}-ssl.conf"
fi

setup_selfsigned() {
    local ssl_dir="${NGINX_CONF_DIR}/ssl"
    mkdir -p "$ssl_dir"

    CERT_PATH="${ssl_dir}/${SITE_NAME_SAFE}.crt"
    KEY_PATH="${ssl_dir}/${SITE_NAME_SAFE}.key"
    local dhparam_path="${ssl_dir}/dhparam.pem"

    if [ -f "$CERT_PATH" ] && [ -f "$KEY_PATH" ]; then
        echo "Self-signed certificate already exists at ${CERT_PATH}"
    else
        echo "Generating self-signed certificate for ${SERVER_NAME}..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$KEY_PATH" \
            -out "$CERT_PATH" \
            -subj "/C=US/ST=Development/L=Local/O=Dev/CN=${SERVER_NAME}"
        echo "Certificate: ${CERT_PATH}"
        echo "Key: ${KEY_PATH}"
    fi

    # Generate DH parameters if not present
    if [ ! -f "$dhparam_path" ]; then
        echo "Generating DH parameters (this may take a moment)..."
        openssl dhparam -out "$dhparam_path" 2048
    fi

    TRUSTED_CERT_PATH="$CERT_PATH"
    DHPARAM_PATH="$dhparam_path"
}

setup_letsencrypt() {
    if ! command -v certbot &>/dev/null; then
        echo "certbot not found. Installing..."
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y certbot python3-certbot-nginx
        elif command -v yum &>/dev/null; then
            sudo yum install -y certbot python3-certbot-nginx
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y certbot python3-certbot-nginx
        else
            echo "ERROR: Cannot install certbot — install manually and retry"
            exit 1
        fi
    fi

    if [ -z "$EMAIL" ]; then
        echo "ERROR: EMAIL is required for Let's Encrypt registration"
        echo "Set EMAIL=admin@example.com"
        exit 1
    fi

    echo "Obtaining Let's Encrypt certificate for ${SERVER_NAME}..."
    sudo certbot --nginx \
        -d "$SERVER_NAME" \
        --non-interactive \
        --agree-tos \
        -m "$EMAIL" \
        --redirect

    CERT_PATH="/etc/letsencrypt/live/${SERVER_NAME}/fullchain.pem"
    KEY_PATH="/etc/letsencrypt/live/${SERVER_NAME}/privkey.pem"
    TRUSTED_CERT_PATH="/etc/letsencrypt/live/${SERVER_NAME}/chain.pem"
    DHPARAM_PATH=""

    echo "Certificate: ${CERT_PATH}"
    echo "Key: ${KEY_PATH}"
    echo ""
    echo "Auto-renewal is configured via systemd timer."
    echo "Test with: sudo certbot renew --dry-run"
    return
}

write_ssl_config() {
    echo "Writing SSL configuration to ${CONFIG_PATH}..."

    if [ -f "$CONFIG_PATH" ]; then
        cp "$CONFIG_PATH" "${CONFIG_PATH}.bak"
        echo "Backed up existing config to ${CONFIG_PATH}.bak"
    fi

    local dhparam_directive=""
    if [ -n "${DHPARAM_PATH:-}" ] && [ -f "${DHPARAM_PATH:-}" ]; then
        dhparam_directive="    ssl_dhparam ${DHPARAM_PATH};"
    fi

    local trusted_cert_directive=""
    if [ -n "${TRUSTED_CERT_PATH:-}" ] && [ -f "${TRUSTED_CERT_PATH:-}" ]; then
        trusted_cert_directive="    ssl_trusted_certificate ${TRUSTED_CERT_PATH};"
    fi

    cat > "$CONFIG_PATH" <<SSLCONF
# HTTP → HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name ${SERVER_NAME};

    # Allow ACME challenge for certificate renewal
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name ${SERVER_NAME};

    # Certificates
    ssl_certificate ${CERT_PATH};
    ssl_certificate_key ${KEY_PATH};

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
${trusted_cert_directive}
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

${dhparam_directive}

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options DENY always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;

    # Application — configure your proxy_pass or root here
    location / {
        root /var/www/${SITE_NAME_SAFE};
        index index.html;
        try_files \$uri \$uri/ =404;
    }

    # Block dotfiles
    location ~ /\\. {
        deny all;
    }

    # Logging
    access_log /var/log/nginx/${SITE_NAME_SAFE}-ssl.access.log;
    error_log /var/log/nginx/${SITE_NAME_SAFE}-ssl.error.log;
}
SSLCONF

    echo "SSL config written to ${CONFIG_PATH}"
}

# Main
case "$SSL_MODE" in
    letsencrypt)
        setup_letsencrypt
        # certbot --nginx handles config writing, so skip manual config
        echo ""
        echo "Let's Encrypt setup complete."
        echo "Certbot has automatically configured nginx."
        ;;
    selfsigned)
        setup_selfsigned
        write_ssl_config
        ;;
    custom)
        if [ -z "$CERT_PATH" ] || [ -z "$KEY_PATH" ]; then
            echo "ERROR: CERT_PATH and KEY_PATH are required for custom mode"
            exit 1
        fi
        TRUSTED_CERT_PATH=""
        DHPARAM_PATH=""
        write_ssl_config
        ;;
    *)
        echo "ERROR: Unknown SSL_MODE '${SSL_MODE}'. Use: letsencrypt, selfsigned, or custom"
        exit 1
        ;;
esac

# Enable site if using sites-available model
if [ -d "${NGINX_CONF_DIR}/sites-available" ] && [ -d "${NGINX_CONF_DIR}/sites-enabled" ] && [ -f "$CONFIG_PATH" ]; then
    LINK="${NGINX_CONF_DIR}/sites-enabled/${SITE_NAME_SAFE}-ssl.conf"
    if [ ! -L "$LINK" ]; then
        ln -s "$CONFIG_PATH" "$LINK"
        echo "Site enabled: ${LINK}"
    fi
fi

# Validate config
echo ""
echo "Validating nginx configuration..."
if nginx -t 2>&1; then
    echo "Configuration is valid"
    echo "To apply: nginx -s reload"
else
    echo "WARNING: Configuration has errors — review the output above"
fi

# Show certificate info
if [ -f "$CERT_PATH" ]; then
    echo ""
    echo "Certificate details:"
    openssl x509 -in "$CERT_PATH" -noout -subject -enddate 2>/dev/null || true
fi
