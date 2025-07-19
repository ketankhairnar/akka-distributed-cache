#!/bin/bash

# Akka Distributed Cache - Test Operations Script
# Updated for JSON API support

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
NODES=(
    "http://localhost:8080"
    "http://localhost:8081"
    "http://localhost:8082"
)

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print colored output
print_test() {
    echo -e "${CYAN}[TEST $((++TESTS_RUN))]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

print_failure() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Safe curl wrapper with timeout and error handling
safe_curl() {
    local method="$1"
    local url="$2"
    local data="$3"
    local content_type="$4"
    local timeout="${5:-10}"

    if [ -n "$data" ]; then
        if [ -n "$content_type" ]; then
            curl -s --connect-timeout 3 --max-time "$timeout" -X "$method" "$url" -H "Content-Type: $content_type" -d "$data" 2>/dev/null
        else
            curl -s --connect-timeout 3 --max-time "$timeout" -X "$method" "$url" -d "$data" 2>/dev/null
        fi
    else
        curl -s --connect-timeout 3 --max-time "$timeout" -X "$method" "$url" 2>/dev/null
    fi
}

# Safe curl with status code
safe_curl_with_status() {
    local method="$1"
    local url="$2"
    local data="$3"
    local content_type="$4"

    if [ -n "$data" ]; then
        if [ -n "$content_type" ]; then
            curl -s --connect-timeout 3 --max-time 10 -w "HTTPSTATUS:%{http_code}" -X "$method" "$url" -H "Content-Type: $content_type" -d "$data" 2>/dev/null
        else
            curl -s --connect-timeout 3 --max-time 10 -w "HTTPSTATUS:%{http_code}" -X "$method" "$url" -d "$data" 2>/dev/null
        fi
    else
        curl -s --connect-timeout 3 --max-time 10 -w "HTTPSTATUS:%{http_code}" -X "$method" "$url" 2>/dev/null
    fi
}

# Function to check if cluster is ready
check_cluster_health() {
    print_info "Checking cluster health..."

    local healthy_nodes=0
    local total_nodes=0

    for i in "${!NODES[@]}"; do
        local node="${NODES[$i]}"
        ((total_nodes++))

        local response=$(safe_curl "GET" "$node/admin/status")
        if [ $? -eq 0 ] && echo "$response" | grep -q "Cache Node Status"; then
            print_success "Node $((i+1)) is healthy: $node"
            ((healthy_nodes++))
        else
            print_warning "Node $((i+1)) is not responding: $node"
        fi
    done

    if [ $healthy_nodes -eq $total_nodes ]; then
        print_success "All $total_nodes cluster nodes are healthy"
    elif [ $healthy_nodes -gt 0 ]; then
        print_warning "$healthy_nodes/$total_nodes nodes are healthy"
    else
        print_failure "No cluster nodes are responding"
        return 1
    fi

    return 0
}

# Function to test basic operations with JSON API
test_basic_operations() {
    print_info "=== Testing Basic Cache Operations (JSON API) ==="

    local base_url="${NODES[0]}"

    # Test PUT operation with JSON
    print_test "PUT operation (JSON format)"
    local put_result=$(safe_curl "PUT" "$base_url/cache/test-key" '{"value":"test-value"}' "application/json")

    if [ $? -eq 0 ] && echo "$put_result" | grep -q "successful"; then
        print_success "PUT operation successful"
    else
        print_failure "PUT operation failed - response: '$put_result'"
    fi

    # Brief pause for consistency
    sleep 1

    # Test GET operation (should return JSON)
    print_test "GET operation (expects JSON response)"
    local get_result=$(safe_curl "GET" "$base_url/cache/test-key")

    if [ $? -eq 0 ] && echo "$get_result" | grep -q '"value".*"test-value"'; then
        print_success "GET operation successful - retrieved JSON: $get_result"
    else
        print_failure "GET operation failed - expected JSON with 'test-value', got: '$get_result'"
    fi

    # Test GET from different node (if available and healthy)
    if [ ${#NODES[@]} -gt 1 ]; then
        print_test "GET from different node"
        local get_result2=$(safe_curl "GET" "${NODES[1]}/cache/test-key")

        if [ $? -eq 0 ] && echo "$get_result2" | grep -q '"value".*"test-value"'; then
            print_success "Data correctly accessible from multiple nodes"
        elif [ $? -ne 0 ]; then
            print_warning "Second node not available - testing single node only"
        else
            print_failure "Data not properly accessible from second node - got: '$get_result2'"
        fi
    fi

    # Test DELETE operation
    print_test "DELETE operation"
    local delete_result=$(safe_curl "DELETE" "$base_url/cache/test-key")

    if [ $? -eq 0 ] && echo "$delete_result" | grep -q "successful"; then
        print_success "DELETE operation successful"
    else
        print_failure "DELETE operation failed - response: '$delete_result'"
    fi

    # Verify deletion
    print_test "Verify deletion"
    local delete_check=$(safe_curl_with_status "GET" "$base_url/cache/test-key")

    if [ $? -eq 0 ] && echo "$delete_check" | grep -q "HTTPSTATUS:404"; then
        print_success "Key successfully deleted (404 response)"
    else
        print_failure "Key not properly deleted - response: '$delete_check'"
    fi
}

# Function to test multiple key operations with JSON
test_multiple_keys() {
    print_info "=== Testing Multiple Key Operations (JSON) ==="

    local base_url="${NODES[0]}"

    # Insert multiple keys with JSON format
    local successful_puts=0
    for i in {1..5}; do
        print_test "PUT key$i (JSON)"
        local json_data="{\"value\":\"value$i\"}"
        local result=$(safe_curl "PUT" "$base_url/cache/key$i" "$json_data" "application/json")

        if [ $? -eq 0 ] && echo "$result" | grep -q "successful"; then
            print_success "key$i stored successfully"
            ((successful_puts++))
        else
            print_failure "Failed to store key$i - response: '$result'"
        fi
    done

    # Retrieve all keys (should return JSON)
    local successful_gets=0
    for i in {1..5}; do
        local result=$(safe_curl "GET" "$base_url/cache/key$i")
        if [ $? -eq 0 ] && echo "$result" | grep -q "\"value\":\"value$i\""; then
            ((successful_gets++))
        fi
    done

    print_test "Multiple key retrieval (JSON responses)"
    if [ $successful_gets -eq 5 ]; then
        print_success "All 5 keys retrieved successfully"
    else
        print_failure "Only $successful_gets/5 keys retrieved successfully"
    fi

    # Cleanup test keys
    for i in {1..5}; do
        safe_curl "DELETE" "$base_url/cache/key$i" >/dev/null 2>&1
    done
}

# Function to test admin endpoints
test_admin_endpoints() {
    print_info "=== Testing Admin Endpoints ==="

    local base_url="${NODES[0]}"

    # Test root endpoint
    print_test "Root health check"
    local root_result=$(safe_curl "GET" "$base_url/")
    if [ $? -eq 0 ] && [ -n "$root_result" ]; then
        print_success "Root endpoint working"
    else
        print_failure "Root endpoint failed"
    fi

    # Test admin status
    print_test "Admin status endpoint"
    local status_result=$(safe_curl "GET" "$base_url/admin/status")

    if [ $? -eq 0 ] && echo "$status_result" | grep -q "Cache Node Status"; then
        print_success "Admin status endpoint working"
    else
        print_failure "Admin status endpoint failed"
    fi

    # Test admin health
    print_test "Admin health endpoint"
    local health_result=$(safe_curl "GET" "$base_url/admin/health")

    if [ $? -eq 0 ] && [ "$health_result" = "OK" ]; then
        print_success "Admin health endpoint working"
    else
        print_failure "Admin health endpoint failed - response: '$health_result'"
    fi

    # Test API documentation
    print_test "API documentation endpoint"
    local api_result=$(safe_curl "GET" "$base_url/api")

    if [ $? -eq 0 ] && echo "$api_result" | grep -q "JSON Format"; then
        print_success "API documentation endpoint working (shows JSON format)"
    else
        print_failure "API documentation endpoint failed"
    fi
}

# Function to test error cases
test_error_cases() {
    print_info "=== Testing Error Cases ==="

    local base_url="${NODES[0]}"

    # Test GET non-existent key
    print_test "GET non-existent key"
    local result=$(safe_curl_with_status "GET" "$base_url/cache/non-existent-key")

    if [ $? -eq 0 ] && echo "$result" | grep -q "HTTPSTATUS:404"; then
        print_success "Correctly returns 404 for non-existent key"
    else
        print_failure "Unexpected response for non-existent key: '$result'"
    fi

    # Test PUT with invalid JSON
    print_test "PUT with invalid JSON"
    local invalid_result=$(safe_curl_with_status "PUT" "$base_url/cache/invalid-test" '{"invalid":"json"' "application/json")

    if [ $? -eq 0 ] && (echo "$invalid_result" | grep -q "HTTPSTATUS:400" || echo "$invalid_result" | grep -q "HTTPSTATUS:422"); then
        print_success "Correctly handles invalid JSON"
    else
        print_warning "Server accepted invalid JSON or returned unexpected status: '$invalid_result'"
    fi

    # Test PUT without "value" field
    print_test "PUT without required 'value' field"
    local no_value_result=$(safe_curl_with_status "PUT" "$base_url/cache/no-value-test" '{"data":"test"}' "application/json")

    if [ $? -eq 0 ] && (echo "$no_value_result" | grep -q "HTTPSTATUS:400" || echo "$no_value_result" | grep -q "HTTPSTATUS:422"); then
        print_success "Correctly rejects JSON without 'value' field"
    else
        print_warning "Server handling of missing 'value' field: '$no_value_result'"
    fi
}

# Function to show test summary
show_summary() {
    echo
    print_info "=== Test Summary ==="
    echo -e "${BLUE}Total Tests:${NC} $TESTS_RUN"
    echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
    echo -e "${RED}Failed:${NC} $TESTS_FAILED"

    local success_rate=0
    if [ $TESTS_RUN -gt 0 ]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi

    echo -e "${BLUE}Success Rate:${NC} $success_rate%"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed! JSON API is working perfectly!${NC}"
        echo
        echo -e "${YELLOW}JSON API Examples:${NC}"
        echo "  curl -X PUT http://localhost:8080/cache/hello \\"
        echo "       -H 'Content-Type: application/json' \\"
        echo "       -d '{\"value\":\"world\"}'"
        echo "  curl http://localhost:8080/cache/hello"
        echo "  curl http://localhost:8080/admin/status"
        return 0
    elif [ $success_rate -ge 80 ]; then
        echo -e "${YELLOW}⚠️  Most tests passed, but some issues found${NC}"
        echo -e "${YELLOW}   JSON API is mostly functional but needs attention${NC}"
        return 1
    else
        echo -e "${RED}❌ Multiple test failures detected${NC}"
        echo
        echo -e "${YELLOW}Troubleshooting JSON API:${NC}"
        echo "  1. Check if Jackson dependencies are properly loaded"
        echo "  2. Verify Content-Type: application/json header"
        echo "  3. Test manually with proper JSON format"
        return 1
    fi
}

# Main execution
main() {
    echo -e "${BLUE}Akka Distributed Cache - JSON API Test Suite${NC}"
    echo -e "${BLUE}=============================================${NC}"
    echo

    # Check if primary node is available
    print_info "Checking primary node availability..."
    local health_check=$(safe_curl "GET" "${NODES[0]}/")

    if [ $? -eq 0 ] && [ -n "$health_check" ]; then
        print_success "Primary node is responding"
    else
        print_failure "Primary node not responding at ${NODES[0]}"
        print_info "Please start the cache server first:"
        print_info "  ./scripts/start-single.sh    # For single node"
        print_info "  ./scripts/start-cluster.sh start  # For full cluster"
        exit 1
    fi

    echo

    # Check cluster health
    check_cluster_health
    echo

    # Run test suites
    echo "🧪 Running JSON API test suite..."
    echo

    test_basic_operations
    echo

    test_multiple_keys
    echo

    test_admin_endpoints
    echo

    test_error_cases

    # Show summary
    show_summary
}

# Trap for cleanup
trap 'print_warning "Test interrupted"; exit 130' INT TERM

# Run main function
main "$@"