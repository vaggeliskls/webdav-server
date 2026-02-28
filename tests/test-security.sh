#!/bin/sh
# WebDAV Server Security Test Suite
# Usage: ./test-security.sh [base_url] [options]
#
# Examples:
#   ./test-security.sh
#   ./test-security.sh http://localhost:80
#   ./test-security.sh http://localhost:80 --user alice:alice123 --folder /private

set -e

# ---------------------------------------------------------------------------
# Configuration (can be overridden via args or env)
# ---------------------------------------------------------------------------
BASE_URL="${1:-http://localhost:80}"
TEST_USER="${WEBDAV_TEST_USER:-alice:alice123}"
TEST_USER2="${WEBDAV_TEST_USER2:-bob:bob123}"
PUBLIC_FOLDER="${WEBDAV_PUBLIC_FOLDER:-/public}"
PRIVATE_FOLDER="${WEBDAV_PRIVATE_FOLDER:-/private}"
SHARED_FOLDER="${WEBDAV_SHARED_FOLDER:-/shared}"

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No colour

PASS=0
FAIL=0
SKIP=0

# ---------------------------------------------------------------------------
# Helpers
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

# Run a curl request and return the HTTP status code
http_status() {
    curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 5 \
        --max-time 10 \
        "$@"
}

# Assert that a request returns an expected HTTP status
assert_status() {
    local description="$1"
    local expected="$2"
    shift 2
    local actual
    actual=$(http_status "$@")
    if [ "$actual" = "$expected" ]; then
        pass "$description (HTTP $actual)"
    else
        fail "$description — expected HTTP $expected, got HTTP $actual"
        info "curl: $*"
    fi
}

# Assert that a request returns one of several acceptable statuses
assert_status_in() {
    local description="$1"
    local expected_list="$2"  # space-separated list e.g. "401 403"
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
    info "curl: $*"
}

# Check server is reachable before running tests
check_server() {
    if ! curl -s -o /dev/null --connect-timeout 5 "$BASE_URL"; then
        printf "${RED}ERROR: Cannot reach server at %s${NC}\n" "$BASE_URL"
        printf "Start the server first:  docker compose up -d\n"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Test suites
# ---------------------------------------------------------------------------

test_unauthenticated_access() {
    print_header "Unauthenticated Access"

    # Protected folder must deny unauthenticated requests
    assert_status_in \
        "Private folder rejects no-credentials request" \
        "401 403" \
        -X PROPFIND "${BASE_URL}${PRIVATE_FOLDER}/"

    assert_status_in \
        "Private folder rejects no-credentials GET" \
        "401 403" \
        -X GET "${BASE_URL}${PRIVATE_FOLDER}/"

    # Public folder must allow unauthenticated read
    assert_status_in \
        "Public folder allows unauthenticated GET" \
        "200 207 301 302" \
        -X GET "${BASE_URL}${PUBLIC_FOLDER}/"
}

test_wrong_credentials() {
    print_header "Wrong Credentials"

    assert_status_in \
        "Wrong password rejected on private folder" \
        "401 403" \
        -u "alice:wrongpassword" \
        -X GET "${BASE_URL}${PRIVATE_FOLDER}/"

    assert_status_in \
        "Non-existent user rejected" \
        "401 403" \
        -u "nobody:nothing" \
        -X GET "${BASE_URL}${PRIVATE_FOLDER}/"
}

test_valid_credentials() {
    print_header "Valid Credentials"

    assert_status_in \
        "Authorised user can GET private folder" \
        "200 207 301" \
        -u "$TEST_USER" \
        -X GET "${BASE_URL}${PRIVATE_FOLDER}/"

    assert_status_in \
        "Authorised user can PROPFIND private folder" \
        "207" \
        -u "$TEST_USER" \
        -X PROPFIND \
        -H "Depth: 0" \
        "${BASE_URL}${PRIVATE_FOLDER}/"
}

test_method_restrictions() {
    print_header "HTTP Method Restrictions"

    # TRACE should always be blocked (Apache disables it by default)
    assert_status_in \
        "TRACE method blocked" \
        "405 403 501" \
        -X TRACE "${BASE_URL}/"

    # DELETE on a read-only public folder must be denied
    assert_status_in \
        "DELETE blocked on read-only public folder (no auth)" \
        "401 403 405" \
        -X DELETE "${BASE_URL}${PUBLIC_FOLDER}/test"

    assert_status_in \
        "DELETE blocked on read-only public folder (with auth)" \
        "403 405" \
        -u "$TEST_USER" \
        -X DELETE "${BASE_URL}${PUBLIC_FOLDER}/test"

    # PUT on a read-only folder must be denied
    assert_status_in \
        "PUT blocked on read-only folder" \
        "401 403 405" \
        -X PUT \
        -d "test" \
        "${BASE_URL}${PUBLIC_FOLDER}/injected.txt"
}

test_write_permissions() {
    print_header "Write Permissions (rw folder)"

    local tmpfile="test-$(date +%s).txt"

    # Authorised user can upload a file
    status=$(http_status \
        -u "$TEST_USER" \
        -X PUT \
        -H "Content-Type: text/plain" \
        --data-binary "security test content" \
        "${BASE_URL}${PRIVATE_FOLDER}/${tmpfile}")

    if [ "$status" = "201" ] || [ "$status" = "204" ]; then
        pass "Authorised user can PUT file to rw folder (HTTP $status)"

        # Authorised user can delete the file they just created
        assert_status_in \
            "Authorised user can DELETE their own file from rw folder" \
            "204 200" \
            -u "$TEST_USER" \
            -X DELETE \
            "${BASE_URL}${PRIVATE_FOLDER}/${tmpfile}"
    elif [ "$status" = "403" ] || [ "$status" = "405" ]; then
        info "PUT returned $status — folder may be configured as read-only; skipping write tests"
        SKIP=$((SKIP + 2))
    else
        fail "Unexpected status $status for PUT to rw folder"
    fi
}

test_path_traversal() {
    print_header "Path Traversal Attempts"

    # Attempt to escape data directory via ../
    assert_status_in \
        "Path traversal ../ blocked" \
        "400 403 404" \
        "${BASE_URL}${PRIVATE_FOLDER}/../../../etc/passwd"

    assert_status_in \
        "Path traversal URL-encoded blocked" \
        "400 403 404" \
        "${BASE_URL}${PRIVATE_FOLDER}/..%2F..%2F..%2Fetc%2Fpasswd"

    assert_status_in \
        "Double-encoded path traversal blocked" \
        "400 401 403 404" \
        "${BASE_URL}${PRIVATE_FOLDER}/..%252F..%252Fetc%252Fpasswd"

    # Attempt to read Apache config files
    assert_status_in \
        "Apache config not exposed via WebDAV root" \
        "400 403 404" \
        "${BASE_URL}/../conf/httpd.conf"
}

test_user_isolation() {
    print_header "User Isolation (cross-folder access)"

    # User 2 should not be able to access User 1's private folder
    # (only relevant if folder is restricted to specific users, not *)
    status=$(http_status \
        -u "$TEST_USER2" \
        -X GET \
        "${BASE_URL}${PRIVATE_FOLDER}/")

    case "$status" in
        200|207|301)
            info "User2 has access — folder may be configured for '*' (all users); check FOLDER_PERMISSIONS"
            skip "User isolation — folder open to all authenticated users"
            ;;
        401|403)
            pass "User2 cannot access User1's private folder (HTTP $status)"
            ;;
        *)
            fail "Unexpected status $status for User2 accessing private folder"
            ;;
    esac
}

test_security_headers() {
    print_header "Security Headers"

    headers=$(curl -s -I --connect-timeout 5 "${BASE_URL}/")

    check_header() {
        local header="$1"
        if echo "$headers" | grep -qi "$header"; then
            pass "Header present: $header"
        else
            skip "Header missing: $header (consider adding to virtualhost.conf)"
        fi
    }

    check_header "X-Content-Type-Options"
    check_header "X-Frame-Options"
    check_header "Referrer-Policy"

    # If CORS is enabled, check CORS header
    if echo "$headers" | grep -qi "Access-Control-Allow-Origin"; then
        pass "CORS header present: Access-Control-Allow-Origin"
    else
        skip "CORS header not present (expected if CORS_ENABLED=false)"
    fi
}

test_health_check() {
    print_header "Health Check Endpoint"

    status=$(http_status "${BASE_URL}/_health")
    if [ "$status" = "200" ]; then
        pass "Health check endpoint responds 200"
    elif [ "$status" = "404" ]; then
        skip "Health check not found — expected if HEALTH_CHECK_ENABLED=false"
    else
        fail "Health check returned unexpected HTTP $status"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
printf "${BLUE}\n"
printf "  WebDAV Security Test Suite\n"
printf "  Target: %s\n" "$BASE_URL"
printf "  User1:  %s\n" "$TEST_USER"
printf "  User2:  %s\n" "$TEST_USER2"
printf "${NC}\n"

check_server

test_unauthenticated_access
test_wrong_credentials
test_valid_credentials
test_method_restrictions
test_write_permissions
test_path_traversal
test_user_isolation
test_security_headers
test_health_check

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf "${BLUE}══════════════════════════════════════════${NC}\n"
printf "  Results: ${GREEN}%d passed${NC}  ${RED}%d failed${NC}  ${YELLOW}%d skipped${NC}\n" \
    "$PASS" "$FAIL" "$SKIP"
printf "${BLUE}══════════════════════════════════════════${NC}\n"
echo ""

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
