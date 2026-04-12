#!/usr/bin/env bash
# Generate nginx reverse proxy config with upstream, load balancing, and optional WebSocket support
# Required: SITE_NAME, SERVER_NAME, BACKEND_SERVERS
# Optional: LB_METHOD, WEBSOCKET_PATH, ENABLE_CACHE, NGINX_CONF_DIR
set -euo pipefail

SITE_NAME="${SITE_NAME:?SITE_NAME is required (e.g., myapp)}"
SERVER_NAME="${SERVER_NAME:?SERVER_NAME is required (e.g., example.com)}"
BACKEND_SERVERS="${BACKEND_SERVERS:?BACKEND_SERVERS is required (comma-separated, e.g., 127.0.0.1:3000,127.0.0.1:3001)}"
LB_METHOD="${LB_METHOD:-round-robin}"
WEBSOCKET_PATH="${WEBSOCKET_PATH:-}"
ENABLE_CACHE="${ENABLE_CACHE:-false}"
NGINX_CONF_DIR="${NGINX_CONF_DIR:-/etc/nginx}"
LISTEN_PORT="${LISTEN_PORT:-80}"

# Determine config path
if [ -d "${NGINX_CONF_DIR}/sites-available" ]; then
    CONFIG_PATH="${NGINX_CONF_DIR}/sites-available/${SITE_NAME}.conf"
else
    CONFIG_PATH="${NGINX_CONF_DIR}/conf.d/${SITE_NAME}.conf"
fi

UPSTREAM_NAME="${SITE_NAME}_backend"

# Build upstream block
build_upstream() {
    local lb_directive=""
    case "$LB_METHOD" in
        least-conn|least_conn)
            lb_directive="    least_conn;"
            ;;
        ip-hash|ip_hash)
            lb_directive="    ip_hash;"
            ;;
        random)
            lb_directive="    random two least_conn;"
            ;;
        round-robin|"")
            lb_directive=""
            ;;
        *)
            echo "WARNING: Unknown LB method '${LB_METHOD}', using round-robin"
            lb_directive=""
            ;;
    esac

    echo "upstream ${UPSTREAM_NAME} {"
    if [ -n "$lb_directive" ]; then
        echo "$lb_directive"
    fi

    IFS=',' read -ra SERVERS <<< "$BACKEND_SERVERS"
    local server_count=${#SERVERS[@]}

    for server in "${SERVERS[@]}"; do
        server=$(echo "$server" | xargs)  # trim whitespace
        if [ -n "$server" ]; then
            echo "    server ${server};"
        fi
    done

    echo "    keepalive 32;"
    echo "}"
}

# Build cache config
build_cache() {
    if [ "$ENABLE_CACHE" = "true" ]; then
        cat <<'CACHE'
proxy_cache_path /var/cache/nginx/UPSTREAM_NAME levels=1:2 keys_zone=UPSTREAM_NAME_cache:10m max_size=1g inactive=60m;
CACHE
    fi
}

# Build WebSocket location
build_websocket_location() {
    if [ -n "$WEBSOCKET_PATH" ]; then
        cat <<WSBLOCK

    # WebSocket proxy
    location ${WEBSOCKET_PATH} {
        proxy_pass http://${UPSTREAM_NAME};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
WSBLOCK
    fi
}

# Build cache location directives
build_cache_directives() {
    if [ "$ENABLE_CACHE" = "true" ]; then
        cat <<CACHEDIR
        proxy_cache ${UPSTREAM_NAME}_cache;
        proxy_cache_valid 200 60m;
        proxy_cache_valid 404 10m;
        proxy_cache_bypass \$http_cache_control;
        proxy_cache_key "\$scheme\$request_method\$host\$request_uri";
        add_header X-Cache-Status \$upstream_cache_status;
CACHEDIR
    fi
}

echo "Generating reverse proxy config: ${CONFIG_PATH}"

# Backup existing config
if [ -f "$CONFIG_PATH" ]; then
    cp "$CONFIG_PATH" "${CONFIG_PATH}.bak"
    echo "Backed up existing config to ${CONFIG_PATH}.bak"
fi

# Generate the config
{
    # Cache path (if enabled)
    if [ "$ENABLE_CACHE" = "true" ]; then
        echo "proxy_cache_path /var/cache/nginx/${UPSTREAM_NAME} levels=1:2 keys_zone=${UPSTREAM_NAME}_cache:10m max_size=1g inactive=60m;"
        echo ""
    fi

    # Upstream block
    build_upstream
    echo ""

    # Server block
    cat <<SERVERBLOCK
server {
    listen ${LISTEN_PORT};
    listen [::]:${LISTEN_PORT};
    server_name ${SERVER_NAME};

    # Proxy settings
    location / {
        proxy_pass http://${UPSTREAM_NAME};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Connection "";

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        # Buffering
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;

        # Failover
        proxy_next_upstream error timeout http_502 http_503 http_504;
        proxy_next_upstream_tries 3;
        proxy_next_upstream_timeout 10s;

SERVERBLOCK

    # Cache directives (inside location block)
    build_cache_directives

    echo "    }"

    # WebSocket location
    build_websocket_location

    # Close server block
    cat <<'SERVEREND'

    # Security: block dotfiles
    location ~ /\. {
        deny all;
    }
}
SERVEREND
} > "$CONFIG_PATH"

echo "Config written to ${CONFIG_PATH}"
echo ""
echo "Upstream: ${UPSTREAM_NAME}"
echo "Backend servers: ${BACKEND_SERVERS}"
echo "Load balancing: ${LB_METHOD}"
[ -n "$WEBSOCKET_PATH" ] && echo "WebSocket path: ${WEBSOCKET_PATH}"
[ "$ENABLE_CACHE" = "true" ] && echo "Caching: enabled"

# Enable site if using sites-available model
if [ -d "${NGINX_CONF_DIR}/sites-available" ] && [ -d "${NGINX_CONF_DIR}/sites-enabled" ]; then
    LINK="${NGINX_CONF_DIR}/sites-enabled/${SITE_NAME}.conf"
    if [ ! -L "$LINK" ]; then
        ln -s "$CONFIG_PATH" "$LINK"
        echo "Site enabled: ${LINK}"
    fi
fi

# Validate
echo ""
echo "Validating configuration..."
if nginx -t 2>&1; then
    echo "Configuration is valid"
    echo "To apply: nginx -s reload"
else
    echo "ERROR: Configuration is invalid — check the output above"
    exit 1
fi
