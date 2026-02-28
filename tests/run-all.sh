#!/bin/sh
# Run all WebDAV security test scenarios locally.
# Mirrors every job in .github/workflows/security-tests.yml
#
# Usage:
#   ./tests/run-all.sh             # build image once, then run all scenarios
#   ./tests/run-all.sh --no-build  # skip docker build (image must already exist)
#   ./tests/run-all.sh 1 3         # run only scenarios 1 and 3
#
# Environment variables:
#   WEBDAV_IMAGE   docker image tag  (default: webdav-test)
#   WEBDAV_PORT    host port to bind (default: 8080)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

IMAGE="${WEBDAV_IMAGE:-webdav-test}"

# ---------------------------------------------------------------------------
# Parse args: collect --no-build flag and optional scenario numbers
# ---------------------------------------------------------------------------
NO_BUILD_FLAG=""
SCENARIOS=""

for arg in "$@"; do
    case "$arg" in
        --no-build) NO_BUILD_FLAG="--no-build" ;;
        [0-9]*)     SCENARIOS="$SCENARIOS $arg" ;;
        *)
            printf "${RED}Unknown argument: %s${NC}\n" "$arg"
            printf "Usage: %s [--no-build] [1 2 3 ...]\n" "$0"
            exit 1
            ;;
    esac
done

# Default: auto-discover all scenario-N-*.sh scripts in order
if [ -z "$SCENARIOS" ]; then
    for f in "$SCRIPT_DIR"/scenario-[0-9]*.sh; do
        [ -f "$f" ] || continue
        num=$(basename "$f" | sed 's/scenario-\([0-9]*\)-.*/\1/')
        SCENARIOS="$SCENARIOS $num"
    done
fi

# ---------------------------------------------------------------------------
# Build once (unless --no-build)
# ---------------------------------------------------------------------------
if [ -z "$NO_BUILD_FLAG" ]; then
    printf "${BLUE}Building image: %s${NC}\n" "$IMAGE"
    docker build -t "$IMAGE" "$REPO_ROOT"
    printf "${GREEN}Build complete.${NC}\n\n"
fi

# ---------------------------------------------------------------------------
# Run selected scenarios
# ---------------------------------------------------------------------------
TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_SCENARIOS=""

run_scenario() {
    local num="$1"
    local script="$SCRIPT_DIR/scenario-${num}-"*".sh"

    # Resolve glob (one match expected)
    local resolved
    resolved=$(ls $script 2>/dev/null | head -1)

    if [ -z "$resolved" ]; then
        printf "${RED}Scenario %s: script not found (%s)${NC}\n" "$num" "$script"
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
        FAILED_SCENARIOS="$FAILED_SCENARIOS $num"
        return
    fi

    printf "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "${BLUE}  Running scenario %s: %s${NC}\n" "$num" "$(basename "$resolved" .sh)"
    printf "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    if sh "$resolved" --no-build; then
        TOTAL_PASS=$((TOTAL_PASS + 1))
        printf "${GREEN}  Scenario %s PASSED${NC}\n\n" "$num"
    else
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
        FAILED_SCENARIOS="$FAILED_SCENARIOS $num"
        printf "${RED}  Scenario %s FAILED${NC}\n\n" "$num"
    fi
}

for s in $SCENARIOS; do
    run_scenario "$s"
done

# ---------------------------------------------------------------------------
# Overall summary
# ---------------------------------------------------------------------------
printf "${BLUE}══════════════════════════════════════════${NC}\n"
printf "  Overall: ${GREEN}%d scenario(s) passed${NC}  ${RED}%d scenario(s) failed${NC}\n" \
    "$TOTAL_PASS" "$TOTAL_FAIL"
if [ -n "$FAILED_SCENARIOS" ]; then
    printf "  Failed scenarios:%s\n" "$FAILED_SCENARIOS"
fi
printf "${BLUE}══════════════════════════════════════════${NC}\n"
echo ""

[ "$TOTAL_FAIL" -eq 0 ]
