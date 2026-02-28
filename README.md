# 🌐 WebDAV Server

A lightweight, Docker-based WebDAV server built on Apache httpd with flexible per-folder access control and multiple authentication options.

> **Pre-built image:** `ghcr.io/vaggeliskls/webdav-server:latest`
> **Documentation:** https://vaggeliskls.github.io/webdav-server/

## 📋 Prerequisites

- Docker 20.0+

## ✨ Key Features

- 🗂️ **Per-folder access control** — different folders can have different auth rules and user restrictions
- 🌍 **Public folders** — mix unauthenticated and authenticated folders on the same server
- 👤 **Per-user permissions** — restrict specific folders to specific users
- 🔐 **Multiple auth methods** — Basic, LDAP, OAuth/OIDC (or LDAP + Basic combined)
- ⚙️ **Configurable methods** — control read-only vs read-write access per folder
- 🌐 **CORS support** — configurable for web clients
- ❤️ **Health check endpoint** — optional `/_health` route
- 🔁 **Proxy-ready** — works behind Traefik or any reverse proxy

## 🚀 Quick Start

```bash
docker compose up --build
```

Access at http://localhost.

For more deployment scenarios see [Deployment Examples](docs/examples.md).

## 📁 Folder Permissions

The main configuration point. Controls which folders exist, who can access them, and whether they are read-only or read-write.

```env
# Format: "/path:users:mode" comma-separated
# users: public | * | alice bob (space-separated)
# mode:  ro (uses RO_METHODS) | rw (uses RW_METHODS)
FOLDER_PERMISSIONS="/public:public:ro,/shared:*:ro,/private:alice bob:rw,/admin:admin:rw"
```

Folders are auto-created at startup (`AUTO_CREATE_FOLDERS=true`).

Leave `FOLDER_PERMISSIONS` empty to fall back to single-root mode (all paths, one auth method).

## 🔐 Authentication

Set auth method via environment variables. Authentication applies to all non-public folders.

### 🔑 Basic Auth (bcrypt)

```env
BASIC_AUTH_ENABLED=true
BASIC_USERS="alice:alice123 bob:bob123"
```

### 🏢 LDAP

```env
LDAP_ENABLED=true
LDAP_URL=ldaps://ldap.example.com
LDAP_ATTRIBUTE=uid
LDAP_BASE_DN=ou=users,dc=example,dc=com
LDAP_BIND_DN=uid=searchuser,ou=users,dc=example,dc=com
LDAP_BIND_PASSWORD=securepassword
```

### ↩️ LDAP + Basic fallback

Set both flags to `true`. Apache tries LDAP first, falls back to the local user file if LDAP authentication fails.

```env
LDAP_ENABLED=true
BASIC_AUTH_ENABLED=true
```

### 🌐 OAuth / OpenID Connect

```env
OAUTH_ENABLED=true
OIDCProviderMetadataURL="http://keycloak/.well-known/openid-configuration"
OIDCRedirectURI="http://my-domain.local/redirect_uri"
OIDCCryptoPassphrase="passphrase"
OIDCClientID="webdav-client"
OIDCClientSecret="secret"
OIDCRemoteUserClaim="preferred_username"
OIDCScope="openid email profile"
```

> More provider examples: [mod_auth_openidc](https://github.com/OpenIDC/mod_auth_openidc)

## 🛠️ Method Control

```env
RO_METHODS="GET HEAD OPTIONS PROPFIND"
RW_METHODS="GET HEAD OPTIONS PROPFIND PUT DELETE MKCOL COPY MOVE LOCK UNLOCK PROPPATCH"
```

Override either variable to customise which HTTP methods are allowed per access mode.

See [WebDAV Methods Reference](docs/webdav-methods.md) for the full list of supported methods.

## 🧩 Optional Features

```env
# Configurable server hostname
SERVER_NAME=localhost

# CORS headers
CORS_ENABLED=false
CORS_ORIGIN=*

# Health check: GET /_health → 200 OK
HEALTH_CHECK_ENABLED=false
```

## 🔒 Security Testing

```bash
./tests/run-all.sh
```

See [Security Tests](docs/tests.md) for all scenarios and options.

## 📚 References

- [Use Cases](docs/use-cases.md)
- [Deployment Examples](docs/examples.md)
- [WebDAV Methods Reference](docs/webdav-methods.md)
- [Security Tests](docs/tests.md)
- [mod_auth_openidc](https://github.com/OpenIDC/mod_auth_openidc)
- [What is WebDAV?](https://www.jscape.com/blog/what-is-webdav)
