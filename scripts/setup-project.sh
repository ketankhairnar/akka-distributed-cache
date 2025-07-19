#!/bin/bash

# Akka Distributed Cache - Project Setup Script
# This script sets up the correct directory structure and verifies the project

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_DIR="$(pwd)"

echo -e "${BLUE}🛠️  Akka Distributed Cache - Project Setup${NC}"
echo -e "${BLUE}===========================================${NC}"
echo -e "Project Directory: $PROJECT_DIR"
echo

# Create directory structure
create_directories() {
    echo -e "${CYAN}📁 Creating directory structure...${NC}"

    mkdir -p src/main/java/ai/akka/cache
    mkdir -p src/main/resources
    mkdir -p src/test/java
    mkdir -p scripts
    mkdir -p logs
    mkdir -p pids
    mkdir -p target

    echo -e "${GREEN}✅ Directories created${NC}"
}

# Check if files are in correct locations
check_file_locations() {
    echo -e "${CYAN}📋 Checking file locations...${NC}"

    local issues=0

    # Java files
    for file in "CacheActor.java" "CacheRoutes.java" "DistributedCacheApplication.java"; do
        if [ -f "$file" ] && [ ! -f "src/main/java/ai/akka/cache/$file" ]; then
            echo -e "${YELLOW}⚠️  Moving $file to src/main/java/ai/akka/cache/${NC}"
            mv "$file" "src/main/java/ai/akka/cache/"
        elif [ -f "src/main/java/ai/akka/cache/$file" ]; then
            echo -e "${GREEN}✅ $file in correct location${NC}"
        else
            echo -e "${RED}❌ $file not found${NC}"
            ((issues++))
        fi
    done

    # Config files
    for file in "application.conf" "logback.xml"; do
        if [ -f "$file" ] && [ ! -f "src/main/resources/$file" ]; then
            echo -e "${YELLOW}⚠️  Moving $file to src/main/resources/${NC}"
            mv "$file" "src/main/resources/"
        elif [ -f "src/main/resources/$file" ]; then
            echo -e "${GREEN}✅ $file in correct location${NC}"
        else
            echo -e "${RED}❌ $file not found${NC}"
            ((issues++))
        fi
    done

    # Script files
    for file in "start-cluster.sh" "test-operations.sh" "start-single.sh"; do
        if [ -f "$file" ] && [ ! -f "scripts/$file" ]; then
            echo -e "${YELLOW}⚠️  Moving $file to scripts/${NC}"
            mv "$file" "scripts/"
            chmod +x "scripts/$file"
        elif [ -f "scripts/$file" ]; then
            echo -e "${GREEN}✅ $file in correct location${NC}"
            chmod +x "scripts/$file"
        else
            echo -e "${YELLOW}⚠️  $file not found (optional)${NC}"
        fi
    done

    # pom.xml
    if [ -f "pom.xml" ]; then
        echo -e "${GREEN}✅ pom.xml found${NC}"
    else
        echo -e "${RED}❌ pom.xml not found${NC}"
        ((issues++))
    fi

    return $issues
}

# Verify Maven dependencies
verify_maven() {
    echo -e "${CYAN}🔍 Verifying Maven setup...${NC}"

    if ! command -v mvn >/dev/null 2>&1; then
        echo -e "${RED}❌ Maven not found. Please install Maven first.${NC}"
        return 1
    fi

    echo -e "${GREEN}✅ Maven found: $(mvn --version | head -1)${NC}"

    if [ -f "pom.xml" ]; then
        echo -e "${BLUE}📦 Validating project...${NC}"
        if mvn validate -q > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Project validation successful${NC}"
        else
            echo -e "${RED}❌ Project validation failed${NC}"
            return 1
        fi
    fi

    return 0
}

# Test compilation
test_compilation() {
    echo -e "${CYAN}🔨 Testing compilation...${NC}"

    if mvn clean compile -q > logs/setup-compile.log 2>&1; then
        echo -e "${GREEN}✅ Compilation successful${NC}"
        return 0
    else
        echo -e "${RED}❌ Compilation failed${NC}"
        echo -e "${YELLOW}📋 Check logs/setup-compile.log for details${NC}"
        if [ -f "logs/setup-compile.log" ]; then
            echo -e "${YELLOW}Last 10 lines of compile log:${NC}"
            tail -10 logs/setup-compile.log
        fi
        return 1
    fi
}

# Show project structure
show_structure() {
    echo -e "${CYAN}📁 Project structure:${NC}"

    if command -v tree >/dev/null 2>&1; then
        tree -I 'target|.git' --dirsfirst
    else
        find . -type d -not -path '*/target/*' -not -path '*/.git/*' | sort | sed 's/^/  /'
    fi
}

# Show next steps
show_next_steps() {
    echo
    echo -e "${BLUE}🎯 Next Steps:${NC}"
    echo -e "${GREEN}1. Start single node:${NC}"
    echo -e "   ./scripts/start-single.sh"
    echo
    echo -e "${GREEN}2. Test the cache:${NC}"
    echo -e "   curl -X PUT http://localhost:8080/cache/test -d 'hello'"
    echo -e "   curl http://localhost:8080/cache/test"
    echo
    echo -e "${GREEN}3. Start full cluster:${NC}"
    echo -e "   ./scripts/start-cluster.sh start"
    echo
    echo -e "${GREEN}4. Run tests:${NC}"
    echo -e "   ./scripts/test-operations.sh"
    echo
    echo -e "${GREEN}5. Check cluster status:${NC}"
    echo -e "   ./scripts/start-cluster.sh status"
    echo
}

# Main execution
main() {
    create_directories
    echo

    if ! check_file_locations; then
        echo -e "${RED}❌ Some required files are missing${NC}"
        echo -e "${YELLOW}💡 Make sure you have all the Java and config files in the project${NC}"
        exit 1
    fi
    echo

    if ! verify_maven; then
        exit 1
    fi
    echo

    if ! test_compilation; then
        exit 1
    fi
    echo

    show_structure
    echo

    echo -e "${GREEN}🎉 Project setup completed successfully!${NC}"
    show_next_steps
}

# Run setup
main "$@"