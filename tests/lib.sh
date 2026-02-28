#!/bin/sh
# Shared helpers for WebDAV local test scenarios
# Source this file from each scenario script:
#   . "$(dirname "$0")/lib.sh"

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
SKIP=0

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
print_header() {
    echo ""
    printf "${BLUE}══════════════════════════════════════════${NC}\n"
    printf "${BLUE}  %s${NC}\n" "$1"
    printf "${BLUE}══════════════════════════════════════════${NC}\n"
}

pass() {
    printf "  ${GREEN}[PASS]${NC} %s\n" "$1"
    PASS=$((PASS + 1))
}

fail() {
    printf "  ${RED}[FAIL]${NC} %s\n" "$1"
    FAIL=$((FAIL + 1))
}

skip() {
    printf "  ${YELLOW}[SKIP]${NC} %s\n" "$1"
    SKIP=$((SKIP + 1))
}

info() {
    printf "  ${YELLOW}      ${NC} %s\n" "$1"
}

print_summary() {
    echo ""
    printf "${BLUE}══════════════════════════════════════════${NC}\n"
    printf "  Results: ${GREEN}%d passed${NC}  ${RED}%d failed${NC}  ${YELLOW}%d skipped${NC}\n" \
        "$PASS" "$FAIL" "$SKIP"
    printf "${BLUE}══════════════════════════════════════════${NC}\n"
    echo ""
}

# ---------------------------------------------------------------------------
# HTTP helpers
# ---------------------------------------------------------------------------
http_status() {
    curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 5 \
        --max-time 10 \
        "$@"
}

assert_status_in() {
    local description="$1"
    local expected_list="$2"   # space-separated e.g. "401 403"
    shift 2
    local actual
    actual=$(http_status "$@")
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
# Docker helpers
# ---------------------------------------------------------------------------
CONTAINER_NAME=""

# Register a trap so the container is always removed on exit
setup_cleanup() {
    CONTAINER_NAME="$1"
    trap 'teardown_container' EXIT INT TERM
}

teardown_container() {
    if [ -n "$CONTAINER_NAME" ]; then
        printf "\n${YELLOW}Stopping container: %s${NC}\n" "$CONTAINER_NAME"
        docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    fi
}

wait_for_server() {
    local url="$1"
    local retries="${2:-15}"
    local i=1
    printf "  Waiting for server at %s" "$url"
    while [ "$i" -le "$retries" ]; do
        if curl -sf "$url" >/dev/null 2>&1; then
            printf " ready\n"
            return 0
        fi
        printf "."
        sleep 2
        i=$((i + 1))
    done
    printf "\n"
    printf "${RED}ERROR: server did not become ready at %s${NC}\n" "$url"
    docker logs "$CONTAINER_NAME" 2>/dev/null || true
    exit 1
}

# Print container logs (call on failure)
dump_logs() {
    printf "\n${RED}Container logs (%s):${NC}\n" "$CONTAINER_NAME"
    docker logs "$CONTAINER_NAME" 2>&1 || true
}
