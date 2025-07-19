#!/bin/bash

# Akka Distributed Cache - Cluster Startup Script
# Usage: ./scripts/start-cluster.sh [start|stop|restart|status|clean]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOGS_DIR="$PROJECT_DIR/logs"
PIDS_DIR="$PROJECT_DIR/pids"

# Node configurations
NODE1_AKKA_PORT=2551
NODE1_HTTP_PORT=8080

NODE2_AKKA_PORT=2552
NODE2_HTTP_PORT=8081

NODE3_AKKA_PORT=2553
NODE3_HTTP_PORT=8082

# Create necessary directories
mkdir -p "$LOGS_DIR" "$PIDS_DIR"

# Function to print colored output (fixed echo formatting)
print_status() {
    echo -e "${BLUE}[CLUSTER]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# Function to check if port is in use
check_port() {
    local port=$1
    if command -v lsof >/dev/null 2>&1; then
        lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1
    elif command -v netstat >/dev/null 2>&1; then
        netstat -ln 2>/dev/null | grep -q ":$port "
    else
        # Fallback: try to connect
        timeout 1 bash -c "</dev/tcp/localhost/$port" 2>/dev/null
    fi
}

# Function to kill process on port
kill_port() {
    local port=$1
    if command -v lsof >/dev/null 2>&1; then
        local pids=$(lsof -ti:$port 2>/dev/null || true)
        if [ -n "$pids" ]; then
            echo "$pids" | xargs kill -9 2>/dev/null || true
            return 0
        fi
    fi
    return 1
}

# Function to kill existing processes
cleanup_existing() {
    print_status "Cleaning up existing processes..."

    # Kill processes using our ports
    for port in $NODE1_HTTP_PORT $NODE2_HTTP_PORT $NODE3_HTTP_PORT $NODE1_AKKA_PORT $NODE2_AKKA_PORT $NODE3_AKKA_PORT; do
        if check_port $port; then
            print_warning "Killing process on port $port"
            kill_port $port || true
        fi
    done

    # Kill processes by PID files
    for pid_file in "$PIDS_DIR"/*.pid; do
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file" 2>/dev/null || echo "")
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                print_warning "Killing process with PID $pid"
                kill -TERM "$pid" 2>/dev/null || true
                sleep 2
                kill -9 "$pid" 2>/dev/null || true
            fi
            rm -f "$pid_file"
        fi
    done

    # Wait for cleanup
    sleep 3
    print_success "Cleanup completed"
}

# Function to verify Maven project
verify_project() {
    cd "$PROJECT_DIR"

    if [ ! -f "pom.xml" ]; then
        print_error "pom.xml not found in $PROJECT_DIR"
        return 1
    fi

    if [ ! -f "src/main/java/ai/akka/cache/DistributedCacheApplication.java" ]; then
        print_error "Main application class not found"
        print_error "Expected: src/main/java/ai/akka/cache/DistributedCacheApplication.java"
        return 1
    fi

    if [ ! -f "src/main/resources/application.conf" ]; then
        print_warning "application.conf not found in src/main/resources/"
        print_warning "This may cause configuration issues"
    fi

    return 0
}

# Function to compile project
compile_project() {
    print_status "Compiling project..."
    cd "$PROJECT_DIR"

    # Set MAVEN_OPTS for compilation as well
    export MAVEN_OPTS="--add-opens java.base/java.nio=ALL-UNNAMED --add-opens java.base/sun.nio.ch=ALL-UNNAMED"

    if mvn clean compile -q > "$LOGS_DIR/compile.log" 2>&1; then
        print_success "Project compiled successfully"
        return 0
    else
        print_error "Compilation failed. Check logs:"
        tail -10 "$LOGS_DIR/compile.log"
        return 1
    fi
}

# Function to start a node
start_node() {
    local node_num=$1
    local akka_port=$2
    local http_port=$3

    print_status "Starting Node $node_num (Akka: $akka_port, HTTP: $http_port)..."

    # Check if ports are available
    if check_port $akka_port; then
        print_error "Akka port $akka_port is already in use"
        return 1
    fi

    if check_port $http_port; then
        print_error "HTTP port $http_port is already in use"
        return 1
    fi

    # Start the node in background with JVM args for Java 11+ compatibility
    cd "$PROJECT_DIR"

    # Set MAVEN_OPTS for Java module access
    export MAVEN_OPTS="--add-opens java.base/java.nio=ALL-UNNAMED --add-opens java.base/sun.nio.ch=ALL-UNNAMED"

    # FIXED: Add cluster mode system property to prevent interactive blocking
    nohup mvn exec:java \
        -Dexec.mainClass="ai.akka.cache.DistributedCacheApplication" \
        -Dexec.args="$akka_port $http_port" \
        -Dexec.cleanupDaemonThreads=false \
        -Dcluster.mode=true \
        -q \
        > "$LOGS_DIR/node$node_num.log" 2>&1 &

    local pid=$!
    echo $pid > "$PIDS_DIR/node$node_num.pid"

    print_success "Node $node_num started with PID $pid"

    # Rest of the function remains the same...
}

# Function to show cluster status
show_status() {
    print_status "Checking cluster status..."
    echo

    local nodes_up=0
    local total_nodes=0

    for node_config in "1:$NODE1_HTTP_PORT" "2:$NODE2_HTTP_PORT" "3:$NODE3_HTTP_PORT"; do
        local node_num=$(echo $node_config | cut -d: -f1)
        local port=$(echo $node_config | cut -d: -f2)
        ((total_nodes++))

        echo -e "${BLUE}Node $node_num (http://localhost:$port):${NC}"

        # Check PID first
        local pid_file="$PIDS_DIR/node$node_num.pid"
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file" 2>/dev/null || echo "")
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                echo -e "  ${GREEN}✓ Process running (PID: $pid)${NC}"
            else
                echo -e "  ${RED}✗ Process not running${NC}"
                continue
            fi
        else
            echo -e "  ${RED}✗ No PID file found${NC}"
            continue
        fi

        # Check HTTP endpoint
        if curl -s --connect-timeout 3 "http://localhost:$port/admin/status" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓ HTTP endpoint healthy${NC}"

            # Test JSON cache functionality
            local test_json='{"value":"health-check"}'
            if curl -s -X PUT "http://localhost:$port/cache/health-check" \
               -H "Content-Type: application/json" \
               -d "$test_json" > /dev/null 2>&1; then

                local cache_test=$(curl -s "http://localhost:$port/cache/health-check" 2>/dev/null || echo "")
                if echo "$cache_test" | grep -q "health-check"; then
                    echo -e "  ${GREEN}✓ JSON cache operations working${NC}"
                    # Cleanup
                    curl -s -X DELETE "http://localhost:$port/cache/health-check" > /dev/null 2>&1 || true
                    ((nodes_up++))
                else
                    echo -e "  ${YELLOW}⚠ JSON cache operations failing${NC}"
                fi
            else
                echo -e "  ${YELLOW}⚠ JSON cache PUT failing${NC}"
            fi
        else
            echo -e "  ${RED}✗ HTTP endpoint not responding${NC}"
        fi
        echo
    done

    echo -e "${BLUE}Cluster Summary:${NC}"
    echo -e "  Nodes up: ${GREEN}$nodes_up${NC}/$total_nodes"

    if [ $nodes_up -eq $total_nodes ]; then
        echo -e "  Status: ${GREEN}HEALTHY${NC}"
    elif [ $nodes_up -gt 0 ]; then
        echo -e "  Status: ${YELLOW}PARTIAL${NC}"
    else
        echo -e "  Status: ${RED}DOWN${NC}"
    fi
}

# Function to stop cluster
stop_cluster() {
    print_status "Stopping cluster..."

    local stopped_count=0

    # Stop by PID files first
    for pid_file in "$PIDS_DIR"/node*.pid; do
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file" 2>/dev/null || echo "")
            local node_name=$(basename "$pid_file" .pid)

            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                print_status "Stopping $node_name (PID: $pid)"

                # Graceful shutdown
                kill -TERM "$pid" 2>/dev/null || true

                # Wait up to 10 seconds for graceful shutdown
                local wait_count=0
                while [ $wait_count -lt 10 ] && kill -0 "$pid" 2>/dev/null; do
                    sleep 1
                    ((wait_count++))
                done

                # Force kill if still running
                if kill -0 "$pid" 2>/dev/null; then
                    print_warning "Force killing $node_name"
                    kill -9 "$pid" 2>/dev/null || true
                fi

                ((stopped_count++))
            fi

            rm -f "$pid_file"
        fi
    done

    # Additional cleanup for any remaining processes
    cleanup_existing

    if [ $stopped_count -gt 0 ]; then
        print_success "Stopped $stopped_count cluster nodes"
    else
        print_info "No running nodes found to stop"
    fi
}

# Function to run quick tests
run_quick_tests() {
    print_status "Running quick JSON API tests..."

    local base_url="http://localhost:$NODE1_HTTP_PORT"

    # Test JSON operations
    print_info "Testing JSON PUT operation..."
    local test_json='{"value":"cluster-test"}'
    if curl -s -X PUT "$base_url/cache/quick-test" \
       -H "Content-Type: application/json" \
       -d "$test_json" | grep -q "successful"; then
        print_success "JSON PUT operation working"

        print_info "Testing JSON GET operation..."
        local result=$(curl -s "$base_url/cache/quick-test")
        if echo "$result" | grep -q "cluster-test"; then
            print_success "JSON GET operation working"

            # Cleanup
            curl -s -X DELETE "$base_url/cache/quick-test" > /dev/null 2>&1
            print_success "Quick JSON tests completed successfully"
        else
            print_error "JSON GET operation failed - got: '$result'"
        fi
    else
        print_error "JSON PUT operation failed"
    fi
}

# Main execution
main() {
    cd "$PROJECT_DIR"

    # Set MAVEN_OPTS globally for all Maven operations
    export MAVEN_OPTS="--add-opens java.base/java.nio=ALL-UNNAMED --add-opens java.base/sun.nio.ch=ALL-UNNAMED"

    print_status "Akka Distributed Cache - Cluster Management"
    print_status "Project Directory: $PROJECT_DIR"
    print_status "Java Module Args: $MAVEN_OPTS"
    echo

    # Handle command line arguments
    case "${1:-start}" in
        "start")
            if ! verify_project; then
                exit 1
            fi

            if ! compile_project; then
                exit 1
            fi

            cleanup_existing

            print_status "Starting 3-node Akka Cache cluster with JSON API..."
            echo

            # Start nodes sequentially
            if start_node 1 $NODE1_AKKA_PORT $NODE1_HTTP_PORT; then
                sleep 3  # Increased pause between nodes
                if start_node 2 $NODE2_AKKA_PORT $NODE2_HTTP_PORT; then
                    sleep 3
                    if start_node 3 $NODE3_AKKA_PORT $NODE3_HTTP_PORT; then
                        echo
                        print_success "All 3 nodes started successfully!"

                        # Run quick tests
                        echo
                        run_quick_tests

                        echo
                        print_status "Available endpoints:"
                        echo "  Node 1: http://localhost:$NODE1_HTTP_PORT"
                        echo "  Node 2: http://localhost:$NODE2_HTTP_PORT"
                        echo "  Node 3: http://localhost:$NODE3_HTTP_PORT"
                        echo
                        print_status "JSON API test commands:"
                        echo "  curl -X PUT http://localhost:$NODE1_HTTP_PORT/cache/test \\"
                        echo "       -H 'Content-Type: application/json' \\"
                        echo "       -d '{\"value\":\"hello\"}'"
                        echo "  curl http://localhost:$NODE1_HTTP_PORT/cache/test"
                        echo "  curl http://localhost:$NODE1_HTTP_PORT/admin/status"
                        echo
                        print_status "Run comprehensive tests: ./scripts/test-operations.sh"
                    else
                        print_error "Failed to start Node 3, stopping cluster"
                        stop_cluster
                        exit 1
                    fi
                else
                    print_error "Failed to start Node 2, stopping cluster"
                    stop_cluster
                    exit 1
                fi
            else
                print_error "Failed to start Node 1"
                exit 1
            fi
            ;;

        "stop")
            stop_cluster
            ;;

        "restart")
            stop_cluster
            sleep 3
            "$0" start
            ;;

        "status")
            show_status
            ;;

        "clean")
            stop_cluster
            print_status "Cleaning up logs and temporary files..."
            rm -rf "$LOGS_DIR"/* "$PIDS_DIR"/*
            print_success "Cleanup complete"
            ;;

        "test")
            if [ -f "$PROJECT_DIR/scripts/test-operations.sh" ]; then
                "$PROJECT_DIR/scripts/test-operations.sh"
            else
                print_error "Test script not found at scripts/test-operations.sh"
                exit 1
            fi
            ;;

        *)
            echo "Usage: $0 {start|stop|restart|status|clean|test}"
            echo
            echo "Commands:"
            echo "  start   - Start 3-node cluster with JSON API"
            echo "  stop    - Stop all cluster nodes"
            echo "  restart - Stop and start cluster"
            echo "  status  - Check cluster health with detailed info"
            echo "  clean   - Stop cluster and clean logs"
            echo "  test    - Run comprehensive test suite"
            echo
            echo "Examples:"
            echo "  $0 start     # Start cluster"
            echo "  $0 status    # Check if running"
            echo "  $0 test      # Run tests"
            echo "  $0 clean     # Stop and cleanup"
            exit 1
            ;;
    esac
}

# Trap signals for cleanup
trap 'print_warning "Interrupted! Cleaning up..."; stop_cluster; exit 130' INT TERM

# Run main function
main "$@"