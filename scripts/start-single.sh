#!/bin/bash

# Simple single-node startup script for development/testing
# Usage: ./scripts/start-single.sh [akka_port] [http_port]

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default ports
AKKA_PORT=${1:-2551}
HTTP_PORT=${2:-8080}

# Get project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}🚀 Starting Akka Cache - Single Node${NC}"
echo -e "${BLUE}=====================================${NC}"
echo -e "Project: $PROJECT_DIR"
echo -e "Akka Port: $AKKA_PORT"
echo -e "HTTP Port: $HTTP_PORT"
echo

# Change to project directory
cd "$PROJECT_DIR"

# Check if project structure is correct
if [ ! -f "pom.xml" ]; then
    echo -e "${RED}❌ pom.xml not found in $PROJECT_DIR${NC}"
    exit 1
fi

if [ ! -f "src/main/java/ai/akka/cache/DistributedCacheApplication.java" ]; then
    echo -e "${RED}❌ Main application class not found${NC}"
    echo -e "${RED}   Expected: src/main/java/ai/akka/cache/DistributedCacheApplication.java${NC}"
    exit 1
fi

# Check if ports are free
check_port() {
    local port=$1
    if command -v lsof >/dev/null 2>&1; then
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            return 0  # Port in use
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -ln 2>/dev/null | grep -q ":$port "; then
            return 0  # Port in use
        fi
    fi
    return 1  # Port free
}

if check_port $HTTP_PORT; then
    echo -e "${RED}❌ HTTP port $HTTP_PORT is already in use${NC}"
    echo -e "${YELLOW}💡 Try a different port: $0 $AKKA_PORT 8081${NC}"
    exit 1
fi

if check_port $AKKA_PORT; then
    echo -e "${YELLOW}⚠️  Akka port $AKKA_PORT is in use, but continuing...${NC}"
fi

# Compile project
echo -e "${BLUE}📦 Compiling project...${NC}"
if mvn clean compile -q; then
    echo -e "${GREEN}✅ Compilation successful${NC}"
else
    echo -e "${RED}❌ Compilation failed${NC}"
    exit 1
fi

echo
echo -e "${BLUE}🎯 Starting cache node...${NC}"
echo -e "${YELLOW}   Press Ctrl+C to stop${NC}"
echo

# Start the application
exec mvn exec:java \
    -Dexec.mainClass="ai.akka.cache.DistributedCacheApplication" \
    -Dexec.args="$AKKA_PORT $HTTP_PORT" \
    -Dexec.cleanupDaemonThreads=false