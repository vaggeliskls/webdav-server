#!/bin/sh
# Scenario 1: Public read-only folder + Basic Auth private folder
# Mirrors the "test-basic-auth" job in .github/workflows/security-tests.yml
#
# Usage:
#   ./tests/scenario-1-basic-auth.sh            # build image then test
#   ./tests/scenario-1-basic-auth.sh --no-build  # skip docker build

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$SCRIPT_DIR/lib.sh"

PORT="${WEBDAV_PORT:-8080}"
BASE_URL="http://localhost:${PORT}"
IMAGE="${WEBDAV_IMAGE:-webdav-test}"
CONTAINER="webdav-scenario-1"

# ---------------------------------------------------------------------------
printf "${BLUE}\n"
printf "  Scenario 1: Basic Auth — public + private\n"
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

# Start container (cleanup registered via trap)
setup_cleanup "$CONTAINER"

docker run -d --name "$CONTAINER" \
    -p "${PORT}:8080" \
    -e SERVER_NAME=localhost \
    -e FOLDER_PERMISSIONS="/public:public:ro,/private:alice bob:rw,/shared:*:ro" \
    -e AUTO_CREATE_FOLDERS=true \
    -e BASIC_AUTH_ENABLED=true \
    -e BASIC_USERS="alice:alice123 bob:bob123" \
    -e HEALTH_CHECK_ENABLED=true \
    "$IMAGE"

wait_for_server "${BASE_URL}/_health"

# ---------------------------------------------------------------------------
# Run the full security test suite (same as CI)
# ---------------------------------------------------------------------------
export WEBDAV_TEST_USER="alice:alice123"
export WEBDAV_TEST_USER2="bob:bob123"
export WEBDAV_PUBLIC_FOLDER="/public"
export WEBDAV_PRIVATE_FOLDER="/private"
export WEBDAV_SHARED_FOLDER="/shared"

set +e
"$SCRIPT_DIR/test-security.sh" "$BASE_URL"
EXIT_CODE=$?
set -e

if [ "$EXIT_CODE" -ne 0 ]; then
    dump_logs
    exit "$EXIT_CODE"
fi
