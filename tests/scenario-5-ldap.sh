#!/bin/sh
# Scenario 5: LDAP authentication
# Mirrors a would-be "test-ldap" job in .github/workflows/security-tests.yml
#
# Spins up an osixia/openldap container alongside WebDAV on a shared Docker
# network, then verifies that only valid LDAP credentials are accepted.
#
# Usage:
#   ./tests/scenario-5-ldap.sh            # build image then test
#   ./tests/scenario-5-ldap.sh --no-build  # skip docker build

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$SCRIPT_DIR/lib.sh"

PORT="${WEBDAV_PORT:-8080}"
BASE_URL="http://localhost:${PORT}"
IMAGE="${WEBDAV_IMAGE:-webdav-test}"

CONTAINER="webdav-scenario-5"
LDAP_CONTAINER="ldap-scenario-5"
NETWORK="webdav-ldap-test-5"

# ---------------------------------------------------------------------------
# LDAP settings (osixia/openldap defaults)
# ---------------------------------------------------------------------------
LDAP_DOMAIN="example.org"
LDAP_BASE_DN="dc=example,dc=org"
LDAP_ADMIN_DN="cn=admin,dc=example,dc=org"
LDAP_ADMIN_PASSWORD="adminpassword"
LDAP_PORT=389

# ---------------------------------------------------------------------------
printf "${BLUE}\n"
printf "  Scenario 5: LDAP authentication\n"
printf "  Target: %s\n" "$BASE_URL"
printf "${NC}\n"

# Parse flags
NO_BUILD=0
for arg in "$@"; do
    case "$arg" in --no-build) NO_BUILD=1 ;; esac
done

# ---------------------------------------------------------------------------
# Custom cleanup — two containers + one network
# ---------------------------------------------------------------------------
teardown_all() {
    printf "\n${YELLOW}Cleaning up containers and network...${NC}\n"
    docker rm -f "$CONTAINER"      >/dev/null 2>&1 || true
    docker rm -f "$LDAP_CONTAINER" >/dev/null 2>&1 || true
    docker network rm "$NETWORK"   >/dev/null 2>&1 || true
}
trap 'teardown_all' EXIT INT TERM

# ---------------------------------------------------------------------------
# Build WebDAV image
# ---------------------------------------------------------------------------
if [ "$NO_BUILD" -eq 0 ]; then
    echo "Building image: $IMAGE"
    docker build -t "$IMAGE" "$REPO_ROOT"
fi

# ---------------------------------------------------------------------------
# Create isolated network
# ---------------------------------------------------------------------------
echo "Creating network: $NETWORK"
docker network create "$NETWORK" >/dev/null

# ---------------------------------------------------------------------------
# Start OpenLDAP
# ---------------------------------------------------------------------------
echo "Starting OpenLDAP container: $LDAP_CONTAINER"
docker run -d --name "$LDAP_CONTAINER" \
    --network "$NETWORK" \
    -e LDAP_ORGANISATION="Example" \
    -e LDAP_DOMAIN="$LDAP_DOMAIN" \
    -e LDAP_ADMIN_PASSWORD="$LDAP_ADMIN_PASSWORD" \
    osixia/openldap:1.5.0

# ---------------------------------------------------------------------------
# Wait for LDAP to be ready
# ---------------------------------------------------------------------------
wait_for_ldap() {
    local retries=20
    local i=1
    printf "  Waiting for LDAP"
    while [ "$i" -le "$retries" ]; do
        if docker exec "$LDAP_CONTAINER" \
            ldapsearch -x \
                -H "ldap://localhost:${LDAP_PORT}" \
                -b "$LDAP_BASE_DN" \
                -D "$LDAP_ADMIN_DN" \
                -w "$LDAP_ADMIN_PASSWORD" \
                "(objectClass=*)" >/dev/null 2>&1; then
            printf " ready\n"
            return 0
        fi
        printf "."
        sleep 2
        i=$((i + 1))
    done
    printf "\n"
    printf "${RED}ERROR: LDAP did not become ready${NC}\n"
    docker logs "$LDAP_CONTAINER" 2>/dev/null || true
    exit 1
}

wait_for_ldap

# ---------------------------------------------------------------------------
# Seed test users via LDIF
# ---------------------------------------------------------------------------
echo "  Adding test users to LDAP"
printf 'dn: ou=users,%s\nobjectClass: organizationalUnit\nou: users\n\ndn: uid=alice,ou=users,%s\nobjectClass: inetOrgPerson\ncn: alice\nsn: alice\nuid: alice\nuserPassword: alice123\n\ndn: uid=bob,ou=users,%s\nobjectClass: inetOrgPerson\ncn: bob\nsn: bob\nuid: bob\nuserPassword: bob123\n' \
    "$LDAP_BASE_DN" "$LDAP_BASE_DN" "$LDAP_BASE_DN" \
    | docker exec -i "$LDAP_CONTAINER" \
        ldapadd -x \
            -H "ldap://localhost:${LDAP_PORT}" \
            -D "$LDAP_ADMIN_DN" \
            -w "$LDAP_ADMIN_PASSWORD"

# ---------------------------------------------------------------------------
# Start WebDAV connected to the same network
# ---------------------------------------------------------------------------
CONTAINER_NAME="$CONTAINER"   # used by lib.sh dump_logs
docker run -d --name "$CONTAINER" \
    --network "$NETWORK" \
    -p "${PORT}:8080" \
    -e SERVER_NAME=localhost \
    -e FOLDER_PERMISSIONS="/public:public:ro,/private:alice bob:rw,/alice:alice:rw,/bob:bob:rw" \
    -e AUTO_CREATE_FOLDERS=true \
    -e LDAP_ENABLED=true \
    -e LDAP_URL="ldap://${LDAP_CONTAINER}:${LDAP_PORT}" \
    -e LDAP_ATTRIBUTE=uid \
    -e LDAP_BASE_DN="ou=users,${LDAP_BASE_DN}" \
    -e LDAP_BIND_DN="$LDAP_ADMIN_DN" \
    -e LDAP_BIND_PASSWORD="$LDAP_ADMIN_PASSWORD" \
    -e HEALTH_CHECK_ENABLED=true \
    "$IMAGE"

wait_for_server "${BASE_URL}/_health"

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------
print_header "Unauthenticated Access"
assert_status_in \
    "No credentials rejected on private folder" \
    "401 403" \
    "${BASE_URL}/private/"

print_header "Wrong Credentials"
assert_status_in \
    "Wrong LDAP password rejected" \
    "401 403" \
    -u alice:wrongpassword \
    "${BASE_URL}/private/"

assert_status_in \
    "Non-existent LDAP user rejected" \
    "401 403" \
    -u nobody:nothing \
    "${BASE_URL}/private/"

print_header "Valid LDAP Credentials"
assert_status_in \
    "alice can GET /private/ with correct LDAP password" \
    "200 207" \
    -u alice:alice123 \
    "${BASE_URL}/private/"

assert_status_in \
    "bob can GET /private/ with correct LDAP password" \
    "200 207" \
    -u bob:bob123 \
    "${BASE_URL}/private/"

assert_status_in \
    "Public folder accessible without credentials" \
    "200 207" \
    "${BASE_URL}/public/"

print_header "Write Permissions (rw folder)"
TMPFILE="ldap-test-$(date +%s).txt"
STATUS=$(http_status \
    -u alice:alice123 \
    -X PUT \
    -H "Content-Type: text/plain" \
    --data-binary "ldap auth test" \
    "${BASE_URL}/private/${TMPFILE}")

if [ "$STATUS" = "201" ] || [ "$STATUS" = "204" ]; then
    pass "alice can PUT file to /private/ (HTTP $STATUS)"
    assert_status_in \
        "alice can DELETE her own file from /private/" \
        "200 204" \
        -u alice:alice123 -X DELETE \
        "${BASE_URL}/private/${TMPFILE}"
else
    fail "Unexpected PUT status $STATUS for alice on /private/"
fi

print_header "Per-user Folder Isolation (LDAP)"
assert_status_in \
    "alice can access /alice/" \
    "200 207" \
    -u alice:alice123 \
    "${BASE_URL}/alice/"

assert_status_in \
    "bob cannot access /alice/" \
    "401 403" \
    -u bob:bob123 \
    "${BASE_URL}/alice/"

assert_status_in \
    "alice cannot access /bob/" \
    "401 403" \
    -u alice:alice123 \
    "${BASE_URL}/bob/"

# ---------------------------------------------------------------------------
print_summary

if [ "$FAIL" -gt 0 ]; then
    dump_logs
    exit 1
fi
