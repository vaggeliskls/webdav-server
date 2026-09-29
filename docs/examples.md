# 📖 Examples

A collection of ready-to-use configurations for common deployment scenarios.

---

## 1. 🌍 Public read-only server (no auth)

Expose a single folder publicly with read-only access. No credentials required.

```yaml
# docker-compose.yml
services:
  webdav:
    image: ghcr.io/vaggeliskls/webdav-server:latest
    ports:
      - "80:8080"
    environment:
      SERVER_NAME: localhost
      FOLDER_PERMISSIONS: "/files:public:ro"
      AUTO_CREATE_FOLDERS: "true"
```

---

## 2. 🔑 Basic Auth — single private folder

All users share the same credentials file. Any authenticated user can access `/files` with full read-write.

```yaml
# docker-compose.yml
services:
  webdav:
    image: ghcr.io/vaggeliskls/webdav-server:latest
    ports:
      - "80:8080"
    volumes:
      - ./data:/var/lib/dav/data
    environment:
      SERVER_NAME: localhost
      FOLDER_PERMISSIONS: "/files:*:rw"
      AUTO_CREATE_FOLDERS: "true"
      BASIC_AUTH_ENABLED: "true"
      BASIC_USERS: "alice:alice123 bob:bob123"
```

Access the server:

```bash
# Basic authentication (curl's default)
curl -u alice:alice123 http://localhost/files/

# Upload a file
curl -u alice:alice123 -T myfile.txt http://localhost/files/myfile.txt

# Create a directory
curl -u alice:alice123 -X MKCOL http://localhost/files/newfolder/
```

---

## 3. � Digest Auth — enhanced security

Use Digest authentication for improved security. Passwords are never sent in plain text over the network.

```yaml
# docker-compose.yml
services:
  webdav:
    image: ghcr.io/vaggeliskls/webdav-server:latest
    ports:
      - "80:8080"
    volumes:
      - ./data:/var/lib/dav/data
    environment:
      SERVER_NAME: localhost
      FOLDER_PERMISSIONS: "/files:*:rw"
      AUTO_CREATE_FOLDERS: "true"
      DIGEST_AUTH_ENABLED: "true"
      BASIC_USERS: "alice:alice123 bob:bob123"
```

Access the server with Digest authentication:

```bash
# Force Digest authentication
curl -u alice:alice123 --digest http://localhost/files/

# Upload a file
curl -u alice:alice123 --digest -T myfile.txt http://localhost/files/myfile.txt

# Auto-negotiate (curl will choose Digest automatically)
curl -u alice:alice123 --anyauth http://localhost/files/
```

---

## 4. 🔄 Basic vs Digest — choosing one

Apache's file-based Basic and Digest auth use incompatible password file formats and cannot run simultaneously on the same resource. You must enable one or the other.

**Use Basic** (recommended when behind HTTPS — simpler, universally supported):

```yaml
environment:
  BASIC_AUTH_ENABLED: "true"
  DIGEST_AUTH_ENABLED: "false"
  BASIC_USERS: "alice:alice123 bob:bob123"
```

```bash
curl -u alice:alice123 http://localhost/files/
```

**Use Digest** (credentials never sent in plaintext — useful without HTTPS):

```yaml
environment:
  BASIC_AUTH_ENABLED: "false"
  DIGEST_AUTH_ENABLED: "true"
  BASIC_USERS: "alice:alice123 bob:bob123"
```

```bash
curl --digest -u alice:alice123 http://localhost/files/
```

> **Note:** If both `BASIC_AUTH_ENABLED` and `DIGEST_AUTH_ENABLED` are set to `true`, Basic takes precedence.

---

## 5. �🗂️ Mixed public + private folders

A public read-only area alongside a private read-write folder restricted to specific users.

```yaml
# docker-compose.yml
services:
  webdav:
    image: ghcr.io/vaggeliskls/webdav-server:latest
    ports:
      - "80:8080"
    volumes:
      - ./data:/var/lib/dav/data
    environment:
      SERVER_NAME: localhost
      FOLDER_PERMISSIONS: "/public:public:ro,/private:alice:rw"
      AUTO_CREATE_FOLDERS: "true"
      BASIC_AUTH_ENABLED: "true"
      BASIC_USERS: "alice:alice123"
```

- `GET http://localhost/public/` → accessible without credentials
- `GET http://localhost/private/` → requires `alice:alice123`
- `PUT http://localhost/private/file.txt` → allowed for alice (rw)
- `PUT http://localhost/public/file.txt` → blocked (ro)

---

## 4. 👥 Per-user folder isolation

Each user gets their own private folder. A shared area is available to all authenticated users.

```yaml
# docker-compose.yml
services:
  webdav:
    image: ghcr.io/vaggeliskls/webdav-server:latest
    ports:
      - "80:8080"
    volumes:
      - ./data:/var/lib/dav/data
    environment:
      SERVER_NAME: localhost
      FOLDER_PERMISSIONS: "/shared:*:ro,/alice:alice:rw,/bob:bob:rw"
      AUTO_CREATE_FOLDERS: "true"
      BASIC_AUTH_ENABLED: "true"
      BASIC_USERS: "alice:alice123 bob:bob123"
```

- `/shared` — read-only for any authenticated user
- `/alice`  — read-write for `alice` only
- `/bob`    — read-write for `bob` only

---

## 5. 🚫 Exclude specific users from a folder

Allow all authenticated users to access a folder except one or more explicitly blocked users.

```yaml
# docker-compose.yml
services:
  webdav:
    image: ghcr.io/vaggeliskls/webdav-server:latest
    ports:
      - "80:8080"
    volumes:
      - ./data:/var/lib/dav/data
    environment:
      SERVER_NAME: localhost
      FOLDER_PERMISSIONS: "/shared:* !charlie:ro,/private:alice bob:rw"
      AUTO_CREATE_FOLDERS: "true"
      BASIC_AUTH_ENABLED: "true"
      BASIC_USERS: "alice:alice123 bob:bob123 charlie:charlie123"
```

- `GET http://localhost/shared/` with `alice` or `bob` → allowed
- `GET http://localhost/shared/` with `charlie` → `403 Forbidden`
- Multiple exclusions: `"* !charlie !dave"`

---

## 6. 🏢 LDAP authentication

Authenticate users against an LDAP/Active Directory server. All authenticated users can access `/files`.

```yaml
# docker-compose.yml
services:
  webdav:
    image: ghcr.io/vaggeliskls/webdav-server:latest
    ports:
      - "80:8080"
    volumes:
      - ./data:/var/lib/dav/data
    environment:
      SERVER_NAME: mydomain.local
      FOLDER_PERMISSIONS: "/files:*:rw"
      AUTO_CREATE_FOLDERS: "true"
      LDAP_ENABLED: "true"
      LDAP_URL: "ldaps://ldap.mydomain.local"
      LDAP_ATTRIBUTE: "uid"
      LDAP_BASE_DN: "ou=users,dc=mydomain,dc=local"
      LDAP_BIND_DN: "uid=searchuser,ou=users,dc=mydomain,dc=local"
      LDAP_BIND_PASSWORD: "securepassword"
```

---

## 7. 🔀 LDAP with Basic Auth fallback

Apache tries LDAP first. If LDAP is unreachable or the user is not found, it falls back to the local password file.

```yaml
# docker-compose.yml
services:
  webdav:
    image: ghcr.io/vaggeliskls/webdav-server:latest
    ports:
      - "80:8080"
    volumes:
      - ./data:/var/lib/dav/data
    environment:
      SERVER_NAME: mydomain.local
      FOLDER_PERMISSIONS: "/files:*:rw"
      AUTO_CREATE_FOLDERS: "true"
      LDAP_ENABLED: "true"
      LDAP_URL: "ldaps://ldap.mydomain.local"
      LDAP_ATTRIBUTE: "uid"
      LDAP_BASE_DN: "ou=users,dc=mydomain,dc=local"
      LDAP_BIND_DN: "uid=searchuser,ou=users,dc=mydomain,dc=local"
      LDAP_BIND_PASSWORD: "securepassword"
      BASIC_AUTH_ENABLED: "true"
      BASIC_USERS: "localadmin:adminpass"
```

---

## 8. 🔁 Behind Traefik reverse proxy

Expose the server via Traefik with rate limiting. The `webdav` container is not directly port-exposed.

```yaml
# docker-compose.yml
services:
  webdav:
    image: ghcr.io/vaggeliskls/webdav-server:latest
    volumes:
      - ./data:/var/lib/dav/data
    networks:
      - proxy
    environment:
      SERVER_NAME: files.mydomain.com
      FOLDER_PERMISSIONS: "/files:*:rw"
      AUTO_CREATE_FOLDERS: "true"
      BASIC_AUTH_ENABLED: "true"
      BASIC_USERS: "alice:alice123"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.webdav.rule=Host(`files.mydomain.com`)"
      - "traefik.http.routers.webdav.entrypoints=web"
      - "traefik.http.services.webdav.loadbalancer.server.port=8080"
      # --- Rate limiting + connection cap (per client IP) ------------------
      - "traefik.http.middlewares.webdav-ratelimit.ratelimit.average=20"
      - "traefik.http.middlewares.webdav-ratelimit.ratelimit.burst=40"
      - "traefik.http.middlewares.webdav-ratelimit.ratelimit.period=1s"
      - "traefik.http.middlewares.webdav-inflight.inflightreq.amount=50"
      - "traefik.http.routers.webdav.middlewares=webdav-ratelimit,webdav-inflight"

  traefik:
    image: traefik:v3.6.9
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
    ports:
      - "80:80"
    volumes:
      # Read-only: Traefik only needs to read the Docker API, never write it.
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - proxy

networks:
  proxy:
    driver: bridge
```

> **Tuning:** `average`/`burst`/`period` throttle the request *rate* per client
> IP; `inflightreq.amount` caps *simultaneous* in-flight requests. The limit is
> keyed on the direct client IP by default — only add an
> `ipstrategy.depth` if a CDN/proxy sits **in front of** Traefik, otherwise a
> spoofed `X-Forwarded-For` can bypass it.

---

## 9. 🔐 OAuth / OIDC with Dex

Log in through a [Dex](https://dexidp.io/) identity provider (which can itself federate GitHub, LDAP, Google, …). Any user who signs in through Dex can access `/files`.

**1. Register the WebDAV server as a client in the Dex config:**

```yaml
# dex config.yaml
issuer: https://dex.example.com

staticClients:
  - id: webdav-client
    name: WebDAV
    secret: <random-client-secret>   # e.g. openssl rand -hex 24
    redirectURIs:
      - https://files.example.com/files/redirect_uri
```

**2. Point the WebDAV server at Dex:**

```yaml
# docker-compose.yml
services:
  webdav:
    image: ghcr.io/vaggeliskls/webdav-server:latest
    ports:
      - "80:8080"
    volumes:
      - ./data:/var/lib/dav/data
    environment:
      SERVER_NAME: files.example.com
      FOLDER_PERMISSIONS: "/files:*:rw"
      AUTO_CREATE_FOLDERS: "true"
      OAUTH_ENABLED: "true"
      OIDCProviderMetadataURL: "https://dex.example.com/.well-known/openid-configuration"
      OIDCRedirectURI: "https://files.example.com/files/redirect_uri"
      OIDCCryptoPassphrase: "<random-passphrase>"   # e.g. openssl rand -hex 32
      OIDCClientID: "webdav-client"
      OIDCClientSecret: "<random-client-secret>"    # same value as in the Dex config
      OIDCRemoteUserClaim: "email"
      OIDCScope: "openid email profile"
```

Open `https://files.example.com/files/` in a browser. You are redirected to Dex, and after logging in you land back on the folder listing.

> **Notes**
> - `OIDCProviderMetadataURL` is Dex's `issuer` + `/.well-known/openid-configuration`. It must match the issuer exactly (Dex is often served under `/dex`, e.g. `https://example.com/dex`), and it must be reachable from both the container and the browser.
> - `OIDCRedirectURI` must be inside a folder that uses OIDC auth (here `/files`). A redirect URI outside every `FOLDER_PERMISSIONS` entry returns 403 after login. It must also be listed in the Dex client's `redirectURIs`.
> - Dex always provides the `email` claim, but `preferred_username` depends on the connector (the local password DB, for example, does not set it). With `OIDCRemoteUserClaim: "email"`, list emails to restrict folders: `"/files:alice@example.com bob@example.com:rw"`.
> - OIDC is a browser login flow. WebDAV clients such as Windows Explorer, macOS Finder or rclone cannot complete the redirect, so use Basic/LDAP auth for them.
> - For local testing, `http://localhost/files/redirect_uri` works as a redirect URI. If Dex runs on the same machine, use `http://host.docker.internal:5556/dex` as the issuer, because `localhost` inside the container is the container itself.

---

## 11. 🧩 With CORS and health check

Enable CORS for web clients and expose a health check endpoint for uptime monitoring.

```yaml
# docker-compose.yml
services:
  webdav:
    image: ghcr.io/vaggeliskls/webdav-server:latest
    ports:
      - "80:8080"
    volumes:
      - ./data:/var/lib/dav/data
    environment:
      SERVER_NAME: localhost
      FOLDER_PERMISSIONS: "/files:*:rw"
      AUTO_CREATE_FOLDERS: "true"
      BASIC_AUTH_ENABLED: "true"
      BASIC_USERS: "alice:alice123"
      CORS_ENABLED: "true"
      CORS_ORIGIN: "https://myapp.example.com"
      HEALTH_CHECK_ENABLED: "true"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/_health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
```

```bash
# Health check
curl http://localhost/_health   # → 200 OK
```

---

## Using an `.env` file

For any example above you can extract environment variables into an `.env` file and reference it with `env_file`:

```env
# .env
SERVER_NAME=localhost
FOLDER_PERMISSIONS=/public:public:ro,/private:alice:rw
AUTO_CREATE_FOLDERS=true
BASIC_AUTH_ENABLED=true
BASIC_USERS=alice:alice123 bob:bob123
CORS_ENABLED=false
HEALTH_CHECK_ENABLED=false
```

```yaml
# docker-compose.yml
services:
  webdav:
    image: ghcr.io/vaggeliskls/webdav-server:latest
    ports:
      - "80:8080"
    volumes:
      - ./data:/var/lib/dav/data
    env_file:
      - .env
```
