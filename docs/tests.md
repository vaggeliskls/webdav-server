# Security Tests

All test scripts live in [`tests/`](../tests/) and mirror the CI scenarios in [`.github/workflows/security-tests.yml`](../.github/workflows/security-tests.yml) exactly — what passes locally will pass in CI.

## Run all scenarios

```bash
./tests/run-all.sh             # build image, then run all scenarios
./tests/run-all.sh --no-build  # skip build (image already exists)
./tests/run-all.sh 1 3         # run only specific scenarios
```

New scenario scripts are picked up automatically — no changes to `run-all.sh` needed.

## Scenarios

| Script | What it tests | Extra dependencies |
|--------|--------------|-------------------|
| [`tests/scenario-1-basic-auth.sh`](../tests/scenario-1-basic-auth.sh) | Public + Basic Auth private folder — full suite + user exclusion | — |
| [`tests/scenario-2-readonly.sh`](../tests/scenario-2-readonly.sh) | All folders read-only — writes blocked | — |
| [`tests/scenario-3-user-isolation.sh`](../tests/scenario-3-user-isolation.sh) | Per-user folder isolation — cross-access denied | — |
| [`tests/scenario-4-public-only.sh`](../tests/scenario-4-public-only.sh) | No auth — public readable, PUT blocked | — |
| [`tests/scenario-5-ldap.sh`](../tests/scenario-5-ldap.sh) | LDAP authentication — valid/invalid credentials, per-user isolation | `osixia/openldap` (pulled automatically) |

```bash
./tests/scenario-5-ldap.sh            # build + test
./tests/scenario-5-ldap.sh --no-build # skip build
```

Each script manages its own container lifecycle: it starts the container(s), waits for the health endpoint, runs the assertions, and cleans up on exit (even on failure). Scenario 5 also creates and removes a dedicated Docker network for LDAP communication.

### Scenario 1 — Basic Auth: public + private

**Config:** `/public:public:ro,/private:alice bob:rw,/shared:*:ro`

Runs the full [`test-security.sh`](../tests/test-security.sh) suite. Then spins up a dedicated container with `/shared:* !charlie:ro` to verify user exclusion in isolation:

| Assertion | Expected |
|-----------|----------|
| `alice` (not excluded) `GET /shared/` | `200` or `207` |
| `bob` (not excluded) `GET /shared/` | `200` or `207` |
| `charlie` (excluded, valid credentials) `GET /shared/` | `403` |
| Unauthenticated `GET /shared/` | `401` |

> The exclusion container is separate so charlie's credentials don't interfere with the main security suite. `403` (forbidden) distinguishes an authenticated-but-excluded user from `401` (unauthenticated).

### Scenario 2 — Read-only folders

**Config:** `/public:public:ro,/private:*:ro`

Verifies that `ro` mode blocks all write methods even for authenticated users.

| Assertion | Expected |
|-----------|----------|
| Unauthenticated request to `/private/` | `401` or `403` |
| Authenticated `GET /private/` | `200` or `207` |
| Authenticated `PUT /private/test.txt` | `403` or `405` |

### Scenario 3 — Per-user folder isolation

**Config:** `/alice:alice:rw,/bob:bob:rw,/shared:*:ro`

Verifies that users can only access their own folders and cannot reach other users' folders.

| Assertion | Expected |
|-----------|----------|
| `alice GET /alice/` | `200` or `207` |
| `bob GET /alice/` | `403` or `401` |
| `alice GET /bob/` | `403` or `401` |
| `alice GET /shared/` | `200` or `207` |
| `bob GET /shared/` | `200` or `207` |

### Scenario 4 — Public server (no auth)

**Config:** `/files:public:ro`

Verifies that public folders work without credentials and that write methods are still blocked by `ro` mode.

| Assertion | Expected |
|-----------|----------|
| `GET /files/` (no credentials) | `200` or `207` |
| `PUT /files/inject.txt` (no credentials) | `403` or `405` |

### Scenario 5 — LDAP authentication

**Config:** `/public:public:ro,/private:alice bob:rw,/alice:alice:rw,/bob:bob:rw`

Spins up an `osixia/openldap` container alongside WebDAV on a shared Docker network, seeds two test users (`alice`, `bob`), then verifies LDAP credential validation and per-user isolation.

| Assertion | Expected |
|-----------|----------|
| No credentials on `/private/` | `401` or `403` |
| Wrong LDAP password | `401` or `403` |
| Non-existent LDAP user | `401` or `403` |
| `alice` with correct LDAP password — `GET /private/` | `200` or `207` |
| `alice` `PUT` to `/private/` | `201` or `204` |
| `bob GET /alice/` | `401` or `403` |
| `alice GET /bob/` | `401` or `403` |

## Full security suite

[`tests/test-security.sh`](../tests/test-security.sh) is used by scenario 1 and can also be pointed at any already-running server:

```bash
./tests/test-security.sh http://localhost:8080
```

Covers:

- Unauthenticated access blocked on protected folders
- Wrong credentials rejected
- Valid credentials accepted
- HTTP method restrictions (TRACE, DELETE, PUT on read-only)
- Write permissions on read-write folders
- Path traversal attempts (`../`, URL-encoded, double-encoded)
- User isolation (cross-folder access denied)
- Security headers (`X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`)
- Health check endpoint

## Permission model

Access control uses an **allowlist with optional exclusions**. The `users` field in `FOLDER_PERMISSIONS` controls who can access a folder:

| Value | Meaning |
|-------|---------|
| `public` | No authentication required |
| `*` | Any authenticated user |
| `alice bob` | Only the named users (space-separated) |
| `* !charlie` | Any authenticated user except `charlie` |
| `* !charlie !dave` | Any authenticated user except `charlie` and `dave` |

Prefix a username with `!` to exclude that specific user. Exclusions are only meaningful alongside `*` (all users). Under the hood, exclusions generate a `<RequireAll>` block with `Require valid-user` and one `Require not user <name>` per excluded user.

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WEBDAV_IMAGE` | `webdav-test` | Docker image tag used by all scripts |
| `WEBDAV_PORT` | `8080` | Host port bound to the container |
