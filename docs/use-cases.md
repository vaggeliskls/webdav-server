# 💡 Use Cases

An overview of common scenarios where this WebDAV server fits well.

---

## 🗄️ Self-hosted File Server (NAS alternative)

Replace cloud storage (Dropbox, Google Drive) with a self-hosted server you fully control.

- Mount the server as a network drive on any OS (see below)
- Store documents, media, backups without third-party access
- Use per-user folders to separate personal data
- Keep a public read-only folder for shared assets

**Relevant config:**
```env
FOLDER_PERMISSIONS="/shared:*:ro,/alice:alice:rw,/bob:bob:rw"
BASIC_AUTH_ENABLED=true
BASIC_USERS="alice:alice123 bob:bob123"
```

---

## 🖥️ Network Drive on Your OS

WebDAV is natively supported on all major operating systems — no extra software required.

### Windows
1. Open **File Explorer** → **This PC** → **Map network drive**
2. Enter `http://your-server/files/` as the folder
3. Check **Connect using different credentials**, enter your username/password

Or via command line:
```cmd
net use Z: http://your-server/files/ /user:alice alice123
```

### macOS
1. **Finder** → **Go** → **Connect to Server** (`⌘K`)
2. Enter `http://your-server/files/`
3. Enter credentials when prompted

Or via Terminal:
```bash
open 'http://alice:alice123@your-server/files/'
```

### Linux
Mount with `davfs2`:
```bash
sudo apt install davfs2
sudo mount -t davfs http://your-server/files/ /mnt/webdav
```

Or with GNOME Files (Nautilus): **Other Locations** → enter `dav://your-server/files/`

---

## 👥 Team Shared Storage

Provide a central file share for a team with role-based access:

- A public folder for announcements or shared resources (read-only for all)
- A shared workspace where all team members can read and write
- Private folders per user or department

```env
FOLDER_PERMISSIONS="/announcements:public:ro,/workspace:*:rw,/hr:alice:rw,/engineering:bob carol:rw"
BASIC_AUTH_ENABLED=true
BASIC_USERS="alice:pass1 bob:pass2 carol:pass3"
```

Integrate with LDAP to manage users centrally without maintaining a separate password file:
```env
LDAP_ENABLED=true
LDAP_URL=ldaps://ldap.company.com
LDAP_BASE_DN=ou=employees,dc=company,dc=com
```

---

## 💾 Backup Target

Many backup tools support WebDAV as a remote destination out of the box:

| Tool | WebDAV support |
|------|---------------|
| [Restic](https://restic.net) | via rclone WebDAV backend |
| [Rclone](https://rclone.org) | native WebDAV remote |
| [Duplicati](https://duplicati.com) | built-in WebDAV destination |
| [Veeam](https://veeam.com) | WebDAV repository |
| macOS Time Machine | via third-party tools |

Example Rclone config:
```ini
[webdav-backup]
type = webdav
url = http://your-server/backups/
vendor = other
user = alice
pass = alice123
```

```env
# Server side: dedicated backup folder
FOLDER_PERMISSIONS="/backups:alice:rw"
BASIC_AUTH_ENABLED=true
BASIC_USERS="alice:alice123"
```

---

## 📝 Document Collaboration

Office suites can open and save documents directly over WebDAV — no download/upload cycle needed.

| Application | How to open a WebDAV file |
|-------------|--------------------------|
| **LibreOffice** | File → Open → paste `http://server/docs/file.odt` |
| **Microsoft Office** | File → Open → enter the WebDAV URL |
| **OnlyOffice** | Connect a WebDAV folder as a storage provider |

Multiple users can share a folder and open documents directly, with each save going back to the server.

```env
FOLDER_PERMISSIONS="/docs:*:rw"
BASIC_AUTH_ENABLED=true
BASIC_USERS="alice:alice123 bob:bob123"
```

---

## 🌍 Static File Distribution (CDN-like)

Serve public read-only assets (images, installers, datasets, reports) without requiring credentials.

- No auth overhead for public consumers
- Combine with Traefik for HTTPS and caching headers
- Use the read-only mode to prevent accidental or malicious uploads

```env
FOLDER_PERMISSIONS="/releases:public:ro,/docs:public:ro"
```

---

## 🤖 CI/CD Artifact Storage

Use the server as a lightweight artifact repository in pipelines:

- Upload build artifacts after a successful build (`PUT`)
- Download them in downstream jobs (`GET`)
- Restrict write access to the CI service account; read access can be public or team-wide

```env
FOLDER_PERMISSIONS="/artifacts:ci-bot:rw,/artifacts:*:ro"
BASIC_AUTH_ENABLED=true
BASIC_USERS="ci-bot:secrettoken alice:alice123"
```

Example upload in a pipeline step:
```bash
curl -u ci-bot:secrettoken -T build/app.tar.gz http://your-server/artifacts/app-v1.2.tar.gz
```

---

## 📱 Mobile File Access

WebDAV is supported by many mobile apps for accessing files on the go:

| App | Platform |
|-----|----------|
| [Documents by Readdle](https://readdle.com/documents) | iOS |
| [FE File Explorer](https://www.skyjos.com/fileexplorer/) | iOS / Android |
| [Solid Explorer](https://neatbytes.com/solidexplorer/) | Android |
| [CX File Explorer](https://play.google.com/store/apps/details?id=com.cxinventor.file.explorer) | Android |

Point any of these to `http://your-server/files/` with your credentials to browse and sync files from your phone.

---

## 🧪 Local Development & Testing

Run a throwaway WebDAV server locally to test WebDAV client code or integrations:

```bash
docker run --rm -p 8080:8080 \
  -e FOLDER_PERMISSIONS="/test:*:rw" \
  -e BASIC_AUTH_ENABLED=true \
  -e BASIC_USERS="dev:dev" \
  ghcr.io/vaggeliskls/webdav-server:latest
```

- No persistent volume — data is lost on container stop (useful for clean test runs)
- Enable the health check endpoint (`HEALTH_CHECK_ENABLED=true`) for integration test readiness checks
- Test WebDAV method behaviour by adjusting `RO_METHODS` / `RW_METHODS`

---

## 🔒 SSO-protected Enterprise Storage

Integrate with an existing identity provider (Keycloak, Okta, Azure AD) via OAuth/OIDC so employees authenticate with their corporate credentials — no separate password management.

```env
FOLDER_PERMISSIONS="/company:*:rw"
OAUTH_ENABLED=true
OIDCProviderMetadataURL="https://sso.company.com/realms/corp/.well-known/openid-configuration"
OIDCClientID="webdav"
OIDCClientSecret="secret"
OIDCRedirectURI="https://files.company.com/redirect_uri"
OIDCRemoteUserClaim="preferred_username"
```
