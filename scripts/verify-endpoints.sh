#!/bin/bash

# Quick endpoint verification script
# Usage: ./scripts/verify-endpoints.sh [base_url]

BASE_URL=${1:-"http://localhost:8080"}

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🔍 Testing Akka Cache Endpoints${NC}"
echo -e "${BLUE}===============================${NC}"
echo -e "Base URL: $BASE_URL"
echo

test_endpoint() {
    local method=$1
    local path=$2
    local data=$3
    local expected_status=$4
    local description=$5

    echo -e "${BLUE}Testing:${NC} $description"
    echo -e "${YELLOW}  $method $BASE_URL$path${NC}"

    if [ -n "$data" ]; then
        echo -e "${YELLOW}  Data: '$data'${NC}"
        response=$(curl -s -w "HTTPSTATUS:%{http_code}" -X "$method" "$BASE_URL$path" -d "$data")
    else
        response=$(curl -s -w "HTTPSTATUS:%{http_code}" -X "$method" "$BASE_URL$path")
    fi

    # Extract HTTP status and body
    http_status=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    body=$(echo "$response" | sed -e 's/HTTPSTATUS:.*//g')

    if [ "$http_status" = "$expected_status" ]; then
        echo -e "${GREEN}  ✅ Status: $http_status${NC}"
        if [ -n "$body" ]; then
            echo -e "${GREEN}  📤 Response: $body${NC}"
        fi
    else
        echo -e "${RED}  ❌ Status: $http_status (expected $expected_status)${NC}"
        if [ -n "$body" ]; then
            echo -e "${RED}  📤 Response: $body${NC}"
        fi
    fi
    echo
}

# Test all endpoints
echo -e "${BLUE}=== Testing All Endpoints ===${NC}"
echo

# 1. Root health check
test_endpoint "GET" "/" "" "200" "Root health check"

# 2. API documentation
test_endpoint "GET" "/api" "" "200" "API documentation"

# 3. Admin endpoints
test_endpoint "GET" "/admin" "" "200" "Admin root"
test_endpoint "GET" "/admin/status" "" "200" "Admin status (detailed)"
test_endpoint "GET" "/admin/health" "" "200" "Admin health (simple)"

# 4. Cache operations
test_endpoint "PUT" "/cache/test-key" "test-value" "200" "Cache PUT operation"
test_endpoint "GET" "/cache/test-key" "" "200" "Cache GET operation"
test_endpoint "DELETE" "/cache/test-key" "" "200" "Cache DELETE operation"
test_endpoint "GET" "/cache/test-key" "" "404" "Cache GET after delete (should be 404)"

# 5. Error cases
test_endpoint "GET" "/cache/nonexistent" "" "404" "GET nonexistent key"
test_endpoint "GET" "/invalid-path" "" "404" "Invalid path"

echo -e "${BLUE}=== Quick Reference ===${NC}"
echo -e "${GREEN}Working endpoints:${NC}"
echo -e "  GET  $BASE_URL/                 - Health check"
echo -e "  GET  $BASE_URL/api              - API docs"
echo -e "  GET  $BASE_URL/admin/status     - Node status"
echo -e "  GET  $BASE_URL/admin/health     - Simple health"
echo -e "  PUT  $BASE_URL/cache/{key}      - Store value"
echo -e "  GET  $BASE_URL/cache/{key}      - Get value"
echo -e "  DELETE $BASE_URL/cache/{key}    - Delete value"
echo

echo -e "${YELLOW}💡 Try these commands:${NC}"
echo -e "  curl $BASE_URL/"
echo -e "  curl $BASE_URL/admin/status"
echo -e "  curl -X PUT $BASE_URL/cache/hello -d 'world'"
echo -e "  curl $BASE_URL/cache/hello"