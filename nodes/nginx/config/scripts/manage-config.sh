#!/usr/bin/env bash
# Manage nginx site configuration: create, validate, enable, reload
# Required: SITE_NAME, SERVER_NAME
# Optional: LISTEN_PORT (default 80), BACKEND_URL, ROOT_DIR, NGINX_CONF_DIR (default /etc/nginx)
set -euo pipefail

NGINX_CONF_DIR="${NGINX_CONF_DIR:-/etc/nginx}"
SITE_NAME="${SITE_NAME:?SITE_NAME is required (e.g., myapp)}"
SERVER_NAME="${SERVER_NAME:?SERVER_NAME is required (e.g., example.com)}"
LISTEN_PORT="${LISTEN_PORT:-80}"
BACKEND_URL="${BACKEND_URL:-}"
ROOT_DIR="${ROOT_DIR:-}"
ACTION="${ACTION:-create}"

CONF_DIR="${NGINX_CONF_DIR}/conf.d"
SITES_AVAILABLE="${NGINX_CONF_DIR}/sites-available"
SITES_ENABLED="${NGINX_CONF_DIR}/sites-enabled"

# Detect config model: conf.d vs sites-available
if [ -d "$SITES_AVAILABLE" ]; then
    CONFIG_PATH="${SITES_AVAILABLE}/${SITE_NAME}.conf"
    USE_SITES_MODEL=true
else
    CONFIG_PATH="${CONF_DIR}/${SITE_NAME}.conf"
    USE_SITES_MODEL=false
fi

create_config() {
    echo "Creating nginx config: ${CONFIG_PATH}"

    if [ -f "$CONFIG_PATH" ]; then
        echo "WARNING: ${CONFIG_PATH} already exists. Backing up to ${CONFIG_PATH}.bak"
        cp "$CONFIG_PATH" "${CONFIG_PATH}.bak"
    fi

    # Build location block based on whether we're proxying or serving static files
    if [ -n "$BACKEND_URL" ]; then
        LOCATION_BLOCK="    location / {
        proxy_pass ${BACKEND_URL};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Connection \"\";
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }"
    elif [ -n "$ROOT_DIR" ]; then
        LOCATION_BLOCK="    root ${ROOT_DIR};
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # Cache static assets
    location ~* \\.(css|js|png|jpg|jpeg|gif|ico|svg|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control \"public, immutable\";
    }"
    else
        echo "ERROR: Either BACKEND_URL or ROOT_DIR must be set"
        exit 1
    fi

    cat > "$CONFIG_PATH" <<NGINX_CONF
server {
    listen ${LISTEN_PORT};
    listen [::]:${LISTEN_PORT};
    server_name ${SERVER_NAME};

${LOCATION_BLOCK}

    # Security: block dotfiles
    location ~ /\\. {
        deny all;
    }

    # Logging
    access_log /var/log/nginx/${SITE_NAME}.access.log;
    error_log /var/log/nginx/${SITE_NAME}.error.log;
}
NGINX_CONF

    echo "Config written to ${CONFIG_PATH}"
}

enable_site() {
    if [ "$USE_SITES_MODEL" = true ]; then
        if [ ! -f "$CONFIG_PATH" ]; then
            echo "ERROR: Config file ${CONFIG_PATH} does not exist"
            exit 1
        fi
        LINK_PATH="${SITES_ENABLED}/${SITE_NAME}.conf"
        if [ -L "$LINK_PATH" ]; then
            echo "Site already enabled: ${LINK_PATH}"
        else
            ln -s "$CONFIG_PATH" "$LINK_PATH"
            echo "Site enabled: ${LINK_PATH} -> ${CONFIG_PATH}"
        fi
    else
        echo "Using conf.d model — configs are auto-enabled"
    fi
}

disable_site() {
    if [ "$USE_SITES_MODEL" = true ]; then
        LINK_PATH="${SITES_ENABLED}/${SITE_NAME}.conf"
        if [ -L "$LINK_PATH" ]; then
            rm "$LINK_PATH"
            echo "Site disabled: removed ${LINK_PATH}"
        else
            echo "Site is not enabled: ${LINK_PATH}"
        fi
    else
        echo "Using conf.d model — rename or remove ${CONFIG_PATH} to disable"
    fi
}

validate_config() {
    echo "Validating nginx configuration..."
    if nginx -t 2>&1; then
        echo "Configuration is valid"
        return 0
    else
        echo "ERROR: Configuration is invalid"
        return 1
    fi
}

reload_nginx() {
    if validate_config; then
        echo "Reloading nginx..."
        nginx -s reload
        echo "Nginx reloaded successfully"
    else
        echo "ERROR: Not reloading — fix config errors first"
        exit 1
    fi
}

case "${ACTION}" in
    create)
        create_config
        enable_site
        validate_config
        echo ""
        echo "To apply: nginx -s reload"
        ;;
    enable)
        enable_site
        validate_config
        ;;
    disable)
        disable_site
        validate_config
        ;;
    validate)
        validate_config
        ;;
    reload)
        reload_nginx
        ;;
    *)
        echo "Usage: ACTION=create|enable|disable|validate|reload $0"
        echo ""
        echo "Environment variables:"
        echo "  SITE_NAME     - Site name (required)"
        echo "  SERVER_NAME   - Hostname (required)"
        echo "  LISTEN_PORT   - Port (default: 80)"
        echo "  BACKEND_URL   - Backend for proxy_pass"
        echo "  ROOT_DIR      - Document root for static files"
        echo "  ACTION        - create|enable|disable|validate|reload"
        exit 1
        ;;
esac
