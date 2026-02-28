#!/bin/sh
# Scenario 3: Per-user folder isolation
# Mirrors the "test-user-isolation" job in .github/workflows/security-tests.yml
#
# Usage:
#   ./tests/scenario-3-user-isolation.sh            # build image then test
#   ./tests/scenario-3-user-isolation.sh --no-build  # skip docker build

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$SCRIPT_DIR/lib.sh"

PORT="${WEBDAV_PORT:-8080}"
BASE_URL="http://localhost:${PORT}"
IMAGE="${WEBDAV_IMAGE:-webdav-test}"
CONTAINER="webdav-scenario-3"

# ---------------------------------------------------------------------------
printf "${BLUE}\n"
printf "  Scenario 3: Per-user folder isolation\n"
printf "  Target: %s\n" "$BASE_URL"
printf "${NC}\n"

# Parse flags
NO_BUILD=0
for arg in "$@"; do
    case "$arg" in --no-build) NO_BUILD=1 ;; esac
done

# Build
if [ "$NO_BUILD" -eq 0 ]; then
    echo "Building image: $IMAGE"
    docker build -t "$IMAGE" "$REPO_ROOT"
fi

# Start container
setup_cleanup "$CONTAINER"

docker run -d --name "$CONTAINER" \
    -p "${PORT}:8080" \
    -e SERVER_NAME=localhost \
    -e FOLDER_PERMISSIONS="/alice:alice:rw,/bob:bob:rw,/shared:*:ro" \
    -e AUTO_CREATE_FOLDERS=true \
    -e BASIC_AUTH_ENABLED=true \
    -e BASIC_USERS="alice:alice123 bob:bob123" \
    -e HEALTH_CHECK_ENABLED=true \
    "$IMAGE"

wait_for_server "${BASE_URL}/_health"

# ---------------------------------------------------------------------------
# Tests (mirrors CI inline steps exactly)
# ---------------------------------------------------------------------------
print_header "Alice can access her own folder"
assert_status_in \
    "alice can GET /alice/" \
    "200 207" \
    -u alice:alice123 \
    "${BASE_URL}/alice/"

print_header "Bob cannot access Alice's folder"
assert_status_in \
    "bob is denied access to /alice/" \
    "403 401" \
    -u bob:bob123 \
    "${BASE_URL}/alice/"

print_header "Alice cannot access Bob's folder"
assert_status_in \
    "alice is denied access to /bob/" \
    "403 401" \
    -u alice:alice123 \
    "${BASE_URL}/bob/"

print_header "Both users can read shared folder"
for user in "alice:alice123" "bob:bob123"; do
    assert_status_in \
        "$user can GET /shared/" \
        "200 207" \
        -u "$user" \
        "${BASE_URL}/shared/"
done

# ---------------------------------------------------------------------------
print_summary

if [ "$FAIL" -gt 0 ]; then
    dump_logs
    exit 1
fi
