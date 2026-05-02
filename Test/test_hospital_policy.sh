#!/usr/bin/env bash
# ============================================================
# Hospital OPA Policy - Manual Test Runner
# ============================================================
# Usage:
#   1. Set your app URLs (or use defaults)
#   2. Write test cases using the test_opa() function
#   3. Run: bash hospital_test_manual.sh
#
# The test_opa() function sends requests THROUGH the apps (not direct OPA).
# It compares HTTP status codes and prints Pass/Fail.
#
# Example test case:
#   test_opa "GET" "doctor" "/hospital/doctor/patients" "200" "Doctor lists patients"
# ============================================================

set -uo pipefail

# ─── CONFIG ───
DOCTOR_URL="${DOCTOR_URL:-http://localhost:5000}"
CLERK_URL="${CLERK_URL:-http://localhost:3000}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0

# ============================================================
# CORE FUNCTION: test_opa
# ============================================================
# Arguments:
#   $1 = HTTP method (GET, POST, PUT, DELETE, PATCH)
#   $2 = Role header value (doctor, clerk, patient, admin, anonymous, "")
#   $3 = Full endpoint path (e.g., /hospital/doctor/patients)
#   $4 = Expected HTTP status code (200, 201, 403, 404, etc.)
#   $5 = Test case name / description
#   $6 = (Optional) JSON request body. Use "" for empty.
#   $7 = (Optional) Target app: "doctor" or "clerk". Auto-detected if omitted.
# ============================================================
test_opa() {
    local method="$1"
    local role="$2"
    local endpoint="$3"
    local expected="$4"
    local test_name="$5"
    local body="${6:-}"
    local target_app="${7:-}"

    # Auto-detect target app from endpoint if not provided
    if [ -z "$target_app" ]; then
        if [[ "$endpoint" == /hospital/doctor* ]] || [[ "$endpoint" == /hospital/recipes ]]; then
            target_app="doctor"
        elif [[ "$endpoint" == /hospital/clerk* ]]; then
            target_app="clerk"
        else
            target_app="doctor"  # default fallback
        fi
    fi

    # Build URL
    local base_url
    if [ "$target_app" == "clerk" ]; then
        base_url="$CLERK_URL"
    else
        base_url="$DOCTOR_URL"
    fi

    local url="${base_url}${endpoint}"

    # Build curl command
    local curl_cmd=(curl -s -o /dev/null -w "%{http_code}")

    if [ -n "$role" ]; then
        curl_cmd+=(-H "X-User-Role: $role")
    fi

    if [ -n "$body" ]; then
        curl_cmd+=(-H "Content-Type: application/json")
        curl_cmd+=(-d "$body")
    fi

    # Execute request
    local actual
    actual=$("${curl_cmd[@]}" -X "$method" "$url" 2>/dev/null)

    # Evaluate
    if [ "$actual" == "$expected" ]; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
        echo -e "       ${CYAN}$method${NC} $endpoint | role=${YELLOW}${role:-none}${NC} | status=${GREEN}$actual${NC}"
        ((PASS++))
    else
        echo -e "${RED}[FAIL]${NC} $test_name"
        echo -e "       ${CYAN}$method${NC} $endpoint | role=${YELLOW}${role:-none}${NC} | expected=${GREEN}$expected${NC} got=${RED}$actual${NC}"
        ((FAIL++))
    fi
}

# ============================================================
# SUMMARY FUNCTION (call at end of your test cases)
# ============================================================
print_summary() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Test Summary${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Passed:  $PASS${NC}"
    echo -e "${RED}  Failed:  $FAIL${NC}"
    echo -e "  Total:    $((PASS + FAIL))"
    echo ""

    if [ $FAIL -eq 0 ]; then
        echo -e "${GREEN}  ✓ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Some tests failed!${NC}"
        return 1
    fi
}

# ============================================================
# WRITE YOUR TEST CASES BELOW
# ============================================================
# Copy/paste these examples, modify them, or write your own.
# ============================================================

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Hospital Policy Tests - Manual Runner${NC}"
echo -e "${BLUE}============================================================${NC}"
echo -e "${CYAN}Doctor App:${NC} $DOCTOR_URL"
echo -e "${CYAN}Clerk App:${NC}  $CLERK_URL"
echo ""

# ───────────────────────────────────────────────────────────
# EXAMPLE 1: Health checks (no auth needed)
# ───────────────────────────────────────────────────────────
echo -e "${YELLOW}--- Health Checks ---${NC}"

test_opa "GET" "" "/healthz" "200" "Doctor app health check" "" "doctor"
test_opa "GET" "" "/healthz" "200" "Clerk app health check" "" "clerk"

sleep 1
# ───────────────────────────────────────────────────────────
# EXAMPLE 2: Doctor routes
# ───────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}--- Doctor Routes ---${NC}"

test_opa "GET" "doctor" "/hospital/doctor/patients" "200" "Doctor lists patients"
test_opa "GET" "doctor" "/hospital/doctor/patients/1" "200" "Doctor views patient 1"
test_opa "GET" "" "/hospital/doctor/patients" "403" "Anonymous denied from doctor routes"
test_opa "GET" "clerk" "/hospital/doctor/patients" "403" "Clerk denied from doctor routes"
test_opa "GET" "patient" "/hospital/doctor/patients" "403" "Patient denied from doctor routes"
test_opa "GET" "admin" "/hospital/doctor/patients" "403" "Admin denied from doctor routes"


sleep 1
# ───────────────────────────────────────────────────────────
# EXAMPLE 3: Recipes - Doctor permissions
# ───────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}--- Recipes: Doctor ---${NC}"

test_opa "GET" "doctor" "/hospital/recipes" "200" "Doctor GET recipes"
test_opa "POST" "doctor" "/hospital/recipes" "201" "Doctor creates recipe" '{"doctor_id":1,"patient_id":1,"title":"X-Ray","price":200}'
test_opa "PUT" "doctor" "/hospital/recipes" "405" "Doctor PUT denied" '{"recipe_id":1,"status":"paid"}'
test_opa "DELETE" "doctor" "/hospital/recipes" "405" "Doctor DELETE denied"
test_opa "PATCH" "doctor" "/hospital/recipes" "405" "Doctor PATCH denied"

sleep 1
# ───────────────────────────────────────────────────────────
# EXAMPLE 4: Recipes - Anonymous / Other roles
# ───────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}--- Recipes: Anonymous / Others ---${NC}"

test_opa "GET" "" "/hospital/recipes" "403" "Anonymous GET recipes denied"
test_opa "POST" "" "/hospital/recipes" "403" "Anonymous POST recipes denied"
test_opa "GET" "patient" "/hospital/recipes" "403" "Patient GET recipes denied"
test_opa "GET" "clerk" "/hospital/recipes" "403" "Clerk GET recipes denied"

sleep 1
# ───────────────────────────────────────────────────────────
# EXAMPLE 5: Clerk routes (no hours check version)
# If using WITH hours, change expected 200 -> 403 after hours
# ───────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}--- Clerk Routes ---${NC}"

test_opa "GET" "clerk" "/hospital/clerk/recipes" "200" "Clerk lists recipes with flow" "" "clerk"
test_opa "GET" "clerk" "/hospital/clerk/flow" "200" "Clerk views flow dashboard" "" "clerk"
test_opa "PUT" "clerk" "/hospital/recipes" "200" "Clerk updates recipe" '{"recipe_id":1,"status":"paid"}' "clerk"

sleep 1
# ───────────────────────────────────────────────────────────
# EXAMPLE 6: Clerk denied cases (always denied)
# ───────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}--- Clerk Denied Cases ---${NC}"

test_opa "POST" "clerk" "/hospital/recipes" "404" "Clerk POST recipes denied" '{"title":"Hack"}' "clerk"
test_opa "GET" "clerk" "/hospital/recipes" "404" "Clerk GET /hospital/recipes denied" "" "clerk"
test_opa "GET" "" "/hospital/clerk/recipes" "403" "Anonymous clerk route denied" "" "clerk"
test_opa "GET" "doctor" "/hospital/clerk/recipes" "403" "Doctor clerk route denied" "" "clerk"


sleep 1
# ───────────────────────────────────────────────────────────
# EXAMPLE 7: Cross-app 404s
# ───────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}--- Cross-App 404s ---${NC}"

test_opa "GET" "clerk" "/hospital/clerk/recipes" "404" "Clerk route on doctor app" "" "doctor"
test_opa "GET" "doctor" "/hospital/doctor/patients" "404" "Doctor route on clerk app" "" "clerk"

sleep 1
# ============================================================
# PRINT SUMMARY
# ============================================================
print_summary
