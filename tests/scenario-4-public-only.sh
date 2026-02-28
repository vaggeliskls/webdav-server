#!/bin/sh
# Scenario 4: Fully public server (no auth)
# Mirrors the "test-public-only" job in .github/workflows/security-tests.yml
#
# Usage:
#   ./tests/scenario-4-public-only.sh            # build image then test
#   ./tests/scenario-4-public-only.sh --no-build  # skip docker build

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$SCRIPT_DIR/lib.sh"

PORT="${WEBDAV_PORT:-8080}"
BASE_URL="http://localhost:${PORT}"
IMAGE="${WEBDAV_IMAGE:-webdav-test}"
CONTAINER="webdav-scenario-4"

# ---------------------------------------------------------------------------
printf "${BLUE}\n"
printf "  Scenario 4: Public server (no auth)\n"
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
    -e FOLDER_PERMISSIONS="/files:public:ro" \
    -e AUTO_CREATE_FOLDERS=true \
    -e HEALTH_CHECK_ENABLED=true \
    "$IMAGE"

wait_for_server "${BASE_URL}/_health"

# ---------------------------------------------------------------------------
# Tests (mirrors CI inline steps exactly)
# ---------------------------------------------------------------------------
print_header "Public folder accessible without credentials"
assert_status_in \
    "Unauthenticated GET /files/ is allowed" \
    "200 207" \
    "${BASE_URL}/files/"

print_header "PUT blocked on public read-only folder"
assert_status_in \
    "PUT blocked on read-only /files/ (no auth)" \
    "403 405" \
    -X PUT -d "test" \
    "${BASE_URL}/files/inject.txt"

# ---------------------------------------------------------------------------
print_summary

if [ "$FAIL" -gt 0 ]; then
    dump_logs
    exit 1
fi
