# Security Tests

All test scripts live in [`tests/`](../tests/) and mirror the CI scenarios in [`.github/workflows/security-tests.yml`](../.github/workflows/security-tests.yml) exactly — what passes locally will pass in CI.

## Run all scenarios

```bash
./tests/run-all.sh             # build image, then run all 4 scenarios
./tests/run-all.sh --no-build  # skip build (image already exists)
./tests/run-all.sh 1 3         # run only specific scenarios
```

## Run a single scenario

| Script | What it tests |
|--------|--------------|
| [`tests/scenario-1-basic-auth.sh`](../tests/scenario-1-basic-auth.sh) | Public + Basic Auth private folder — full suite |
| [`tests/scenario-2-readonly.sh`](../tests/scenario-2-readonly.sh) | All folders read-only — writes blocked |
| [`tests/scenario-3-user-isolation.sh`](../tests/scenario-3-user-isolation.sh) | Per-user folder isolation — cross-access denied |
| [`tests/scenario-4-public-only.sh`](../tests/scenario-4-public-only.sh) | No auth — public readable, PUT blocked |

```bash
./tests/scenario-2-readonly.sh            # build + test
./tests/scenario-2-readonly.sh --no-build # skip build
```

Each script manages its own container lifecycle: it starts the container, waits for the health endpoint, runs the assertions, and cleans up on exit (even on failure).

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

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WEBDAV_IMAGE` | `webdav-test` | Docker image tag used by all scripts |
| `WEBDAV_PORT` | `8080` | Host port bound to the container |
