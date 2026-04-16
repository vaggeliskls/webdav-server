#!/bin/sh
# Scenario 6: WebDAV write operations smoke test
# Verifies that the lock database is functional and all write methods succeed.
#
# Usage:
#   ./tests/scenario-6-write-ops.sh            # build image then test
#   ./tests/scenario-6-write-ops.sh --no-build  # skip docker build

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$SCRIPT_DIR/lib.sh"

PORT="${WEBDAV_PORT:-8080}"
BASE_URL="http://localhost:${PORT}"
IMAGE="${WEBDAV_IMAGE:-webdav-test}"
CONTAINER="webdav-scenario-6"
USER="alice:alice123"

# ---------------------------------------------------------------------------
printf "${BLUE}\n"
printf "  Scenario 6: Write Operations & Lock Database\n"
printf "  Target: %s\n" "$BASE_URL"
printf "${NC}\n"

NO_BUILD=0
for arg in "$@"; do
    case "$arg" in --no-build) NO_BUILD=1 ;; esac
done

if [ "$NO_BUILD" -eq 0 ]; then
    echo "Building image: $IMAGE"
    docker build -t "$IMAGE" "$REPO_ROOT"
fi

setup_cleanup "$CONTAINER"

docker run -d --name "$CONTAINER" \
    -p "${PORT}:8080" \
    -e SERVER_NAME=localhost \
    -e FOLDER_PERMISSIONS="/data:alice:rw" \
    -e AUTO_CREATE_FOLDERS=true \
    -e BASIC_AUTH_ENABLED=true \
    -e BASIC_USERS="alice:alice123" \
    -e HEALTH_CHECK_ENABLED=true \
    "$IMAGE"

wait_for_server "${BASE_URL}/_health"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Returns HTTP status; never fails the script
raw_status() {
    curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$@"
}

# Assert write succeeds (2xx) and never returns 500 (lock DB failure)
assert_write() {
    local description="$1"
    local expected_list="$2"
    shift 2
    local actual
    actual=$(raw_status "$@")
    if [ "$actual" = "500" ]; then
        fail "$description — HTTP 500 (lock database failure)"
        return
    fi
    for code in $expected_list; do
        if [ "$actual" = "$code" ]; then
            pass "$description (HTTP $actual)"
            return
        fi
    done
    fail "$description — expected one of [$expected_list], got HTTP $actual"
    info "curl args: $*"
}

# ---------------------------------------------------------------------------
print_header "Write Operations"

TMPFILE="locktest-$(date +%s).txt"
assert_write \
    "PUT creates a file" \
    "201 204" \
    -u "$USER" -X PUT \
    -H "Content-Type: text/plain" \
    --data-binary "write ops test" \
    "${BASE_URL}/data/${TMPFILE}"

# MKCOL
assert_write \
    "MKCOL creates a directory" \
    "201" \
    -u "$USER" -X MKCOL \
    "${BASE_URL}/data/testdir-$(date +%s)/"

COPYDIR="copytest-$(date +%s)"
MOVEDIR="movetest-$(date +%s)"

# PUT a source file for COPY / MOVE
SRC="src-$(date +%s).txt"
raw_status -u "$USER" -X PUT \
    -H "Content-Type: text/plain" \
    --data-binary "copy/move source" \
    "${BASE_URL}/data/${SRC}" >/dev/null

# COPY
assert_write \
    "COPY duplicates a file" \
    "201 204" \
    -u "$USER" -X COPY \
    -H "Destination: ${BASE_URL}/data/${COPYDIR}.txt" \
    "${BASE_URL}/data/${SRC}"

# MOVE
assert_write \
    "MOVE renames a file" \
    "201 204" \
    -u "$USER" -X MOVE \
    -H "Destination: ${BASE_URL}/data/${MOVEDIR}.txt" \
    "${BASE_URL}/data/${SRC}"

# LOCK
LOCK_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 5 --max-time 10 \
    -u "$USER" -X LOCK \
    -H "Content-Type: application/xml" \
    -H "Depth: 0" \
    -H "Timeout: Second-30" \
    --data '<?xml version="1.0" encoding="utf-8"?>
<D:lockinfo xmlns:D="DAV:">
  <D:lockscope><D:exclusive/></D:lockscope>
  <D:locktype><D:write/></D:locktype>
  <D:owner><D:href>test</D:href></D:owner>
</D:lockinfo>' \
    "${BASE_URL}/data/${TMPFILE}")

if [ "$LOCK_RESPONSE" = "500" ]; then
    fail "LOCK — HTTP 500 (lock database failure)"
elif [ "$LOCK_RESPONSE" = "200" ] || [ "$LOCK_RESPONSE" = "201" ]; then
    pass "LOCK acquires exclusive lock (HTTP $LOCK_RESPONSE)"
else
    fail "LOCK — expected 200/201, got HTTP $LOCK_RESPONSE"
fi

# PROPPATCH and DELETE use a separate unlocked file
PROPFILE="proptest-$(date +%s).txt"
raw_status -u "$USER" -X PUT \
    -H "Content-Type: text/plain" \
    --data-binary "proppatch source" \
    "${BASE_URL}/data/${PROPFILE}" >/dev/null

assert_write \
    "PROPPATCH sets a custom property" \
    "207" \
    -u "$USER" -X PROPPATCH \
    -H "Content-Type: application/xml" \
    --data '<?xml version="1.0" encoding="utf-8"?>
<D:propertyupdate xmlns:D="DAV:" xmlns:Z="http://ns.example.com/">
  <D:set><D:prop><Z:smoketest>1</Z:smoketest></D:prop></D:set>
</D:propertyupdate>' \
    "${BASE_URL}/data/${PROPFILE}"

assert_write \
    "DELETE removes a file" \
    "204" \
    -u "$USER" -X DELETE \
    "${BASE_URL}/data/${PROPFILE}"

# ---------------------------------------------------------------------------
print_summary

if [ "$FAIL" -gt 0 ]; then
    dump_logs
    exit 1
fi
