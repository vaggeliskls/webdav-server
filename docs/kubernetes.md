# ☸️ Kubernetes / Helm Examples

Deploy the WebDAV server on Kubernetes using the Helm chart.

## Install the chart

All published chart versions are available at [ghcr.io/vaggeliskls/charts/webdav-server](https://github.com/vaggeliskls/webdav-server/pkgs/container/charts%2Fwebdav-server).

```bash
# From OCI registry (GitHub Packages)
helm install webdav oci://ghcr.io/vaggeliskls/charts/webdav-server \
  --version 0.1.0 \
  -n webdav --create-namespace

# From local source
helm install webdav ./kubernetes \
  -n webdav --create-namespace
```

---

## 1. 🌍 Public read-only server (no auth)

```bash
helm install webdav oci://ghcr.io/vaggeliskls/webdav-server-chart \
  -n webdav --create-namespace \
  --set folderPermissions="/files:public:ro" \
  --set autoCreateFolders=true \
  --set basicAuth.enabled=false \
  --set ingress.enabled=true \
  --set ingress.host=webdav.example.com
```

Or with a values file:

```yaml
# values-public.yaml
folderPermissions: "/files:public:ro"
autoCreateFolders: true
basicAuth:
  enabled: false
ingress:
  enabled: true
  host: webdav.example.com
```

```bash
helm install webdav oci://ghcr.io/vaggeliskls/webdav-server-chart \
  -n webdav --create-namespace \
  -f values-public.yaml
```

---

## 2. 🔑 Basic Auth — single private folder

```yaml
# values-basic-auth.yaml
folderPermissions: "/files:*:rw"
autoCreateFolders: true
basicAuth:
  enabled: true
  users: "alice:alice123 bob:bob123"
ingress:
  enabled: true
  host: webdav.example.com
```

```bash
helm install webdav oci://ghcr.io/vaggeliskls/webdav-server-chart \
  -n webdav --create-namespace \
  -f values-basic-auth.yaml
```

---

## 3. 📁 Per-user isolated folders

Each user can only access their own folder. A shared read-only folder is available to all.

```yaml
# values-user-isolation.yaml
folderPermissions: "/alice:alice:rw,/bob:bob:rw,/shared:*:ro"
autoCreateFolders: true
basicAuth:
  enabled: true
  users: "alice:alice123 bob:bob123"
ingress:
  enabled: true
  host: webdav.example.com
```

---

## 4. 🔒 Public + private folders (mixed access)

```yaml
# values-mixed.yaml
folderPermissions: "/public:public:ro,/private:alice:rw"
autoCreateFolders: true
basicAuth:
  enabled: true
  users: "alice:alice123"
ingress:
  enabled: true
  host: webdav.example.com
```

---

## 5. 🌐 Behind an ingress controller

### Traefik

```yaml
# values-traefik.yaml
serverName: webdav.example.com
ingress:
  enabled: true
  host: webdav.example.com
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
```

### nginx

```yaml
# values-nginx.yaml
serverName: webdav.example.com
ingress:
  enabled: true
  host: webdav.example.com
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
```

---

## 6. 🔐 TLS (HTTPS)

```yaml
# values-tls.yaml
serverName: webdav.example.com
ingress:
  enabled: true
  host: webdav.example.com
  tls:
    enabled: true
    secretName: webdav-tls
```

Provide the TLS secret separately:

```bash
kubectl create secret tls webdav-tls \
  --cert=tls.crt \
  --key=tls.key \
  -n webdav
```

---

## 7. 💾 Custom storage size and class

```yaml
# values-storage.yaml
persistence:
  enabled: true
  storageClass: "fast-ssd"
  size: 50Gi
```

---

## 8. 🔬 LDAP Authentication

```yaml
# values-ldap.yaml
folderPermissions: "/files:*:rw"
basicAuth:
  enabled: false
ldap:
  enabled: true
  url: "ldaps://ldap.example.com"
  attribute: "uid"
  baseDN: "ou=users,dc=example,dc=com"
  bindDN: "uid=searchuser,ou=users,dc=example,dc=com"
  bindPassword: "securepassword"
ingress:
  enabled: true
  host: webdav.example.com
```

---

## Upgrading

```bash
helm upgrade webdav oci://ghcr.io/vaggeliskls/charts/webdav-server \
  --version 0.1.1 \
  -n webdav \
  -f my-values.yaml
```

## Uninstalling

```bash
helm uninstall webdav -n webdav
# PVC is retained by default — delete manually if no longer needed
kubectl delete pvc webdav-data -n webdav
```
