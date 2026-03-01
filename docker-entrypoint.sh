#!/bin/sh
set -e

CONF_DIR="/usr/local/apache2/conf"
DAV_DIR="/var/lib/dav"
FOLDERS_CONF="${CONF_DIR}/webdav-folders.conf"

RO_METHODS="${RO_METHODS:-GET HEAD OPTIONS PROPFIND}"
RW_METHODS="${RW_METHODS:-GET HEAD OPTIONS PROPFIND PUT DELETE MKCOL COPY MOVE LOCK UNLOCK PROPPATCH}"

# ---------------------------------------------------------------------------
# Write the auth directives block for a protected directory.
# Depends on the active auth method (LDAP / OAuth / Basic).
# ---------------------------------------------------------------------------
write_auth_directives() {
    local file="$1"

    if [ "$LDAP_ENABLED" = "true" ] && [ "$BASIC_AUTH_ENABLED" = "true" ]; then
        # Combined: try LDAP first, fall back to local Basic Auth file
        echo "--> Combined LDAP + Basic auth (provider chaining)"
        cat >> "$file" << EOF
    AuthType Basic
    AuthName "WebDAV"
    AuthBasicProvider ldap file
    AuthLDAPURL "${LDAP_URL}/${LDAP_BASE_DN}?${LDAP_ATTRIBUTE}"
    AuthLDAPBindDN "${LDAP_BIND_DN}"
    AuthLDAPBindPassword "${LDAP_BIND_PASSWORD}"
    AuthUserFile "${DAV_DIR}/user.passwd"
EOF

    elif [ "$LDAP_ENABLED" = "true" ]; then
        cat >> "$file" << EOF
    AuthType Basic
    AuthName "WebDAV"
    AuthBasicProvider ldap
    AuthLDAPURL "${LDAP_URL}/${LDAP_BASE_DN}?${LDAP_ATTRIBUTE}"
    AuthLDAPBindDN "${LDAP_BIND_DN}"
    AuthLDAPBindPassword "${LDAP_BIND_PASSWORD}"
EOF

    elif [ "$OAUTH_ENABLED" = "true" ]; then
        # Only AuthType goes inside the Directory block.
        # OIDC global directives are injected into the VirtualHost by apply_oauth_config.
        cat >> "$file" << 'EOF'
    AuthType openid-connect
EOF

    else
        # Basic Auth (default)
        cat >> "$file" << EOF
    AuthType Basic
    AuthName "WebDAV"
    AuthUserFile "${DAV_DIR}/user.passwd"
EOF
    fi
}

# ---------------------------------------------------------------------------
# Write a Require line for a given users value and auth type.
#   users: "*"          → Require valid-user
#   users: "alice bob"  → Require user alice bob  (Basic)
#                       → Require ldap-user alice bob  (LDAP)
#                       → <RequireAny> Require claim ... (OAuth)
#   users: "* !charlie" → <RequireAll> valid-user + Require not user charlie
#
# Tokens prefixed with "!" are exclusions and generate "Require not" directives
# wrapped in a <RequireAll> block alongside the allow directive.
# ---------------------------------------------------------------------------
write_require() {
    local file="$1"
    local users="$2"
    local indent="$3"

    # Split tokens into allow_list and exclude_list (! prefix = exclude).
    # Disable glob expansion so a bare "*" in $users is not expanded to filenames.
    local allow_list=""
    local exclude_list=""
    set -f
    for u in $users; do
        case "$u" in
            !*) exclude_list="${exclude_list} ${u#!}" ;;
            *)  allow_list="${allow_list} ${u}" ;;
        esac
    done
    set +f
    allow_list="${allow_list# }"
    exclude_list="${exclude_list# }"

    if [ -n "$exclude_list" ]; then
        # Use <RequireAll> + <RequireNone> for exclusions.
        #
        # "Require not user X" returns NEUTRAL for non-X users, which causes
        # <RequireAll> to fail. <RequireNone> returns GRANTED when none of its
        # inner directives match — the correct semantics for exclusion.
        local claim="${OIDCRemoteUserClaim:-preferred_username}"
        echo "${indent}<RequireAll>" >> "$file"

        # Allow directive (empty allow_list or "*" both mean any valid user)
        if [ -z "$allow_list" ] || [ "$allow_list" = "*" ]; then
            echo "${indent}    Require valid-user" >> "$file"
        elif [ "$LDAP_ENABLED" = "true" ]; then
            echo "${indent}    Require ldap-user ${allow_list}" >> "$file"
        elif [ "$OAUTH_ENABLED" = "true" ]; then
            for u in $allow_list; do
                echo "${indent}    Require claim ${claim}:${u}" >> "$file"
            done
        else
            echo "${indent}    Require user ${allow_list}" >> "$file"
        fi

        # <RequireNone> returns GRANTED when none of its directives match,
        # and DENIED when any matches — exactly the "exclude these users" logic.
        echo "${indent}    <RequireNone>" >> "$file"
        for u in $exclude_list; do
            if [ "$LDAP_ENABLED" = "true" ]; then
                echo "${indent}        Require ldap-user ${u}" >> "$file"
            elif [ "$OAUTH_ENABLED" = "true" ]; then
                echo "${indent}        Require claim ${claim}:${u}" >> "$file"
            else
                echo "${indent}        Require user ${u}" >> "$file"
            fi
        done
        echo "${indent}    </RequireNone>" >> "$file"

        echo "${indent}</RequireAll>" >> "$file"
        return
    fi

    # No exclusions — original behaviour
    if [ "$users" = "*" ]; then
        echo "${indent}Require valid-user" >> "$file"
        return
    fi

    if [ "$LDAP_ENABLED" = "true" ]; then
        echo "${indent}Require ldap-user ${users}" >> "$file"
    elif [ "$OAUTH_ENABLED" = "true" ]; then
        local claim="${OIDCRemoteUserClaim:-preferred_username}"
        if [ "$(echo "$users" | wc -w)" -eq 1 ]; then
            echo "${indent}Require claim ${claim}:${users}" >> "$file"
        else
            echo "${indent}<RequireAny>" >> "$file"
            for u in $users; do
                echo "${indent}    Require claim ${claim}:${u}" >> "$file"
            done
            echo "${indent}</RequireAny>" >> "$file"
        fi
    else
        echo "${indent}Require user ${users}" >> "$file"
    fi
}

# ---------------------------------------------------------------------------
# Generate a single <Directory> block for one folder entry.
#   $1 = absolute directory path
#   $2 = users value  ("public" | "*" | "alice bob")
#   $3 = methods string (RO or RW)
# ---------------------------------------------------------------------------
write_directory_block() {
    local dir_path="$1"
    local users="$2"
    local methods="$3"

    cat >> "$FOLDERS_CONF" << EOF
<Directory "${dir_path}">
    Dav On
    Options +Indexes
EOF

    if [ "$users" = "public" ]; then
        cat >> "$FOLDERS_CONF" << EOF
    <Limit ${methods}>
        Require all granted
    </Limit>
    <LimitExcept ${methods}>
        Require all denied
    </LimitExcept>
EOF
    else
        write_auth_directives "$FOLDERS_CONF"
        # Return 403 (not 401) when a valid user is denied by authorization,
        # so excluded users get a clear Forbidden rather than a re-auth challenge.
        echo "    AuthzSendForbiddenOnFailure On" >> "$FOLDERS_CONF"
        cat >> "$FOLDERS_CONF" << EOF
    <Limit ${methods}>
EOF
        write_require "$FOLDERS_CONF" "$users" "        "
        cat >> "$FOLDERS_CONF" << EOF
    </Limit>
    <LimitExcept ${methods}>
        Require all denied
    </LimitExcept>
EOF
    fi

    echo "</Directory>" >> "$FOLDERS_CONF"
    echo "" >> "$FOLDERS_CONF"
}

# ---------------------------------------------------------------------------
# Generate the per-folder config file.
# If FOLDER_PERMISSIONS is set, parse it.
# Otherwise fall back to a single root block (backward compat).
# ---------------------------------------------------------------------------
generate_folders_config() {
    > "$FOLDERS_CONF"

    if [ -z "$FOLDER_PERMISSIONS" ]; then
        # ---- Backward-compatible single root block -------------------------
        echo "--> FOLDER_PERMISSIONS not set — using single root directory with global auth"

        cat >> "$FOLDERS_CONF" << EOF
<Directory "${DAV_DIR}/data/">
    Dav On
    Options +Indexes
EOF
        if [ "$LDAP_ENABLED" = "true" ]; then
            echo "--> LDAP auth enabled"
            write_auth_directives "$FOLDERS_CONF"
            cat >> "$FOLDERS_CONF" << EOF
    <Limit ${RO_METHODS}>
        Require valid-user
    </Limit>
    <LimitExcept ${RO_METHODS}>
        Require all denied
    </LimitExcept>
EOF
        elif [ "$OAUTH_ENABLED" = "true" ]; then
            echo "--> OAuth/OIDC auth enabled"
            write_auth_directives "$FOLDERS_CONF"
            cat >> "$FOLDERS_CONF" << EOF
    <Limit ${RO_METHODS}>
        Require valid-user
    </Limit>
    <LimitExcept ${RO_METHODS}>
        Require all denied
    </LimitExcept>
EOF
        elif [ "$BASIC_AUTH_ENABLED" = "true" ]; then
            echo "--> Basic auth enabled"
            write_auth_directives "$FOLDERS_CONF"
            cat >> "$FOLDERS_CONF" << EOF
    <Limit ${RO_METHODS}>
        Require valid-user
    </Limit>
    <LimitExcept ${RO_METHODS}>
        Require all denied
    </LimitExcept>
EOF
        else
            echo "--> No authentication — public access"
            cat >> "$FOLDERS_CONF" << EOF
    <Limit ${RO_METHODS}>
        Require all granted
    </Limit>
    <LimitExcept ${RO_METHODS}>
        Require all denied
    </LimitExcept>
EOF
        fi

        echo "</Directory>" >> "$FOLDERS_CONF"
        return
    fi

    # ---- Parse FOLDER_PERMISSIONS -----------------------------------------
    # Format: "/path:users:mode,/path2:users2:mode2"
    # users: public | * | alice bob
    # mode:  ro | rw
    echo "--> Generating per-folder access config from FOLDER_PERMISSIONS"

    echo "$FOLDER_PERMISSIONS" | tr ',' '\n' | while IFS=':' read -r FOLDER_PATH FOLDER_USERS FOLDER_MODE; do
        # Strip surrounding whitespace
        FOLDER_PATH=$(echo "$FOLDER_PATH" | tr -d ' ')
        FOLDER_MODE=$(echo "$FOLDER_MODE" | tr -d ' ')

        DIR_PATH="${DAV_DIR}/data${FOLDER_PATH}"

        # Auto-create folder if requested
        if [ "${AUTO_CREATE_FOLDERS:-true}" = "true" ]; then
            mkdir -p "$DIR_PATH"
        fi

        # Resolve methods
        if [ "$FOLDER_MODE" = "rw" ]; then
            METHODS="$RW_METHODS"
        else
            METHODS="$RO_METHODS"
        fi

        echo "--> Folder ${FOLDER_PATH}: users=[${FOLDER_USERS}] mode=${FOLDER_MODE}"
        write_directory_block "$DIR_PATH" "$FOLDER_USERS" "$METHODS"
    done
}

# ---------------------------------------------------------------------------
# Build the Basic Auth password file using htpasswd (bcrypt).
# ---------------------------------------------------------------------------
generate_passwd_file() {
    rm -f "${DAV_DIR}/user.passwd"
    touch "${DAV_DIR}/user.passwd"
    echo "$BASIC_USERS" | tr ' ' '\n' | while IFS=':' read -r USERNAME PASSWORD; do
        [ -z "$USERNAME" ] && continue
        htpasswd -B -b "${DAV_DIR}/user.passwd" "$USERNAME" "$PASSWORD"
        echo "--> Added user: ${USERNAME}"
    done
}

# ---------------------------------------------------------------------------
# Inject OIDC global directives into the VirtualHost block.
# These cannot appear inside <Directory> blocks — VirtualHost level only.
# ---------------------------------------------------------------------------
apply_oauth_config() {
    if [ "$OAUTH_ENABLED" = "true" ]; then
        echo "--> OAuth/OIDC enabled — injecting OIDC directives into VirtualHost"
        local oidc_directives=""
        for var in $(env | grep "^OIDC" | cut -d'=' -f1); do
            var_value=$(eval echo \$$var)
            oidc_directives="${oidc_directives}    ${var} \"${var_value}\"\n"
        done
        sed -i "s|</VirtualHost>|${oidc_directives}</VirtualHost>|" \
            "${CONF_DIR}/virtualhost.conf"
    fi
}

# ---------------------------------------------------------------------------
# Apply CORS headers to virtualhost config if enabled.
# ---------------------------------------------------------------------------
apply_cors() {
    if [ "${CORS_ENABLED:-false}" = "true" ]; then
        echo "--> CORS enabled (origin: ${CORS_ORIGIN:-*})"
        sed -i "s|</VirtualHost>|    Header always set Access-Control-Allow-Origin \"${CORS_ORIGIN:-*}\"\n    Header always set Access-Control-Allow-Methods \"GET,PUT,DELETE,PROPFIND,OPTIONS,MKCOL,COPY,MOVE,LOCK,UNLOCK,HEAD\"\n    Header always set Access-Control-Allow-Headers \"Authorization,Content-Type,Depth,Destination,Overwrite,DAV,If\"\n    Header always set Access-Control-Allow-Credentials \"true\"\n</VirtualHost>|" \
            "${CONF_DIR}/virtualhost.conf"
    fi
}

# ---------------------------------------------------------------------------
# Add a health check endpoint if enabled.
# ---------------------------------------------------------------------------
apply_health_check() {
    if [ "${HEALTH_CHECK_ENABLED:-false}" = "true" ]; then
        echo "--> Health check enabled at /_health"
        echo "OK" > "${DAV_DIR}/health.html"
        sed -i "s|</VirtualHost>|    Alias /_health ${DAV_DIR}/health.html\n    <Location /_health>\n        Require all granted\n    </Location>\n</VirtualHost>|" \
            "${CONF_DIR}/virtualhost.conf"
    fi
}

# ---------------------------------------------------------------------------
# Block browser access if enabled (returns 403 for Mozilla/* User-Agents).
# ---------------------------------------------------------------------------
apply_browser_block() {
    if [ "${BROWSER_ACCESS_BLOCKED:-false}" = "true" ]; then
        echo "--> Browser access blocked (BROWSER_ACCESS_BLOCKED=true)"
        sed -i "s|</VirtualHost>|    SetEnvIf User-Agent \"Mozilla\" block_browser\n    <Location />\n        Order Allow,Deny\n        Allow from all\n        Deny from env=block_browser\n    </Location>\n</VirtualHost>|" \
            "${CONF_DIR}/virtualhost.conf"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Process config templates
envsubst < "${CONF_DIR}/webdav.conf.template"      > "${CONF_DIR}/webdav.conf"
envsubst < "${CONF_DIR}/virtualhost.conf.template" > "${CONF_DIR}/virtualhost.conf"

# Generate per-folder Apache config
generate_folders_config

# Set up Basic Auth password file if needed
if [ "$BASIC_AUTH_ENABLED" = "true" ] && [ -z "$FOLDER_PERMISSIONS" ]; then
    generate_passwd_file
elif [ -n "$FOLDER_PERMISSIONS" ] && [ "$BASIC_AUTH_ENABLED" = "true" ]; then
    generate_passwd_file
elif [ -n "$FOLDER_PERMISSIONS" ] && [ "$LDAP_ENABLED" != "true" ] && [ "$OAUTH_ENABLED" != "true" ]; then
    # FOLDER_PERMISSIONS set but no explicit auth — generate passwd for any non-public folders
    generate_passwd_file
fi

# Apply optional features to virtualhost
apply_oauth_config
apply_cors
apply_health_check
apply_browser_block

# Load mod_auth_openidc globally when OAuth is enabled.
# LoadModule must be at server level, not inside Directory blocks.
if [ "$OAUTH_ENABLED" = "true" ]; then
    MODULE_SRC="/usr/lib/apache2/modules/mod_auth_openidc.so"
    MODULE_DST="${CONF_DIR}/../modules/mod_auth_openidc.so"
    if [ -f "$MODULE_SRC" ] && [ ! -f "$MODULE_DST" ]; then
        ln -s "$MODULE_SRC" "$MODULE_DST"
    fi
    if ! grep -q "auth_openidc_module" "${CONF_DIR}/httpd.conf"; then
        echo "LoadModule auth_openidc_module modules/mod_auth_openidc.so" >> "${CONF_DIR}/httpd.conf"
    fi
fi

# Include configs in main httpd.conf (append on each start — use a guard to prevent duplicates)
if ! grep -q "Include conf/webdav.conf" "${CONF_DIR}/httpd.conf"; then
    echo "Include conf/webdav.conf"      >> "${CONF_DIR}/httpd.conf"
    echo "Include conf/virtualhost.conf" >> "${CONF_DIR}/httpd.conf"
fi

exec "$@"
