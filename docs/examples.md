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

## 4. 🔄 Basic + Digest (dual auth support)

Support both Basic and Digest authentication. Digest is used as primary, with Basic as fallback for clients that don't support Digest.

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
      DIGEST_AUTH_ENABLED: "true"
      BASIC_USERS: "alice:alice123 bob:bob123"
```

Clients can use either method:

```bash
# Use Basic auth (curl's default)
curl -u alice:alice123 http://localhost/files/

# Use Digest auth (more secure)
curl -u alice:alice123 --digest http://localhost/files/

# Let curl auto-negotiate (prefers Digest)
curl -u alice:alice123 --anyauth http://localhost/files/
```

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

  traefik:
    image: traefik:v3.6.9
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
    ports:
      - "80:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - proxy

networks:
  proxy:
    driver: bridge
```

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
