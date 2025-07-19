# Akka Distributed Cache

A high-performance, distributed cache system built with Akka Cluster and Akka HTTP. This project provides a scalable, fault-tolerant caching solution with RESTful API endpoints and comprehensive cluster management capabilities.

## 🚀 Features

- **Distributed Architecture**: Built on Akka Cluster for horizontal scaling
- **RESTful API**: Simple HTTP interface for cache operations
- **Fault Tolerance**: Automatic failure detection and recovery
- **Production Ready**: Comprehensive logging, monitoring, and management scripts
- **Development Friendly**: Easy setup and testing scripts for rapid development

## 📋 Prerequisites

- **Java 11+**: Required for Akka and modern Java features
- **Maven 3.6+**: For dependency management and building
- **curl**: For testing HTTP endpoints (usually pre-installed)

### Quick Verification:
```bash
java -version    # Should show Java 11+
mvn -version     # Should show Maven 3.6+
curl --version   # Should show curl info
```

## 🛠️ Quick Start

### 1. Project Setup
```bash
# Clone or download the project
git clone <your-repo-url>
cd akka-distributed-cache

# Run automated project setup
chmod +x scripts/setup-project.sh
./scripts/setup-project.sh
```

### 2. Start Single Node (Development)
```bash
# Start a single cache node for development/testing
./scripts/start-single.sh

# The server will start on:
# - HTTP API: http://localhost:8080
# - Akka Cluster: localhost:2551
```

### 3. Test Basic Operations
```bash
# Store a value
curl -X PUT http://localhost:8080/cache/hello -d 'world'

# Retrieve the value
curl http://localhost:8080/cache/hello

# Check node status
curl http://localhost:8080/admin/status

# View API documentation
curl http://localhost:8080/api
```
<!--
### 4. Start Full Cluster (Production)
```bash
# Start 3-node cluster
./scripts/start-cluster.sh start

# Check cluster status
./scripts/start-cluster.sh status

# Run comprehensive tests
./scripts/test-operations.sh
```
-->
## 📚 API Reference

### Cache Operations

| Method | Endpoint | Description | Example |
|--------|----------|-------------|---------|
| `PUT` | `/cache/{key}` | Store a value | `curl -X PUT http://localhost:8080/cache/mykey -d 'myvalue'` |
| `GET` | `/cache/{key}` | Retrieve a value | `curl http://localhost:8080/cache/mykey` |
| `DELETE` | `/cache/{key}` | Remove a value | `curl -X DELETE http://localhost:8080/cache/mykey` |

### Admin Operations

| Method | Endpoint | Description | Response |
|--------|----------|-------------|----------|
| `GET` | `/admin/status` | Detailed node status | Node info, timestamps, actor details |
| `GET` | `/admin/health` | Simple health check | `OK` |
| `GET` | `/` | Root health check | Node online confirmation |
| `GET` | `/api` | API documentation | Complete API reference |

### Response Codes

- **200 OK**: Operation successful
- **404 Not Found**: Key doesn't exist or invalid endpoint
- **500 Internal Server Error**: Server-side error

## 🔧 Scripts Reference

### `setup-project.sh`
**Purpose**: One-time project initialization and verification

```bash
./scripts/setup-project.sh
```

**What it does**:
- Creates proper Maven directory structure
- Moves files to correct locations
- Verifies Maven setup and dependencies
- Tests compilation
- Shows project structure and next steps

### `start-single.sh`
**Purpose**: Start single node for development

```bash
# Default ports (2551 for Akka, 8080 for HTTP)
./scripts/start-single.sh

# Custom ports
./scripts/start-single.sh 2552 8081
```

**Features**:
- Quick startup for development
- Port conflict detection
- Direct console output
- Immediate error feedback

### `start-cluster.sh`
**Purpose**: Production cluster management

```bash
# Start 3-node cluster
./scripts/start-cluster.sh start

# Check detailed status
./scripts/start-cluster.sh status

# Stop cluster
./scripts/start-cluster.sh stop

# Restart cluster
./scripts/start-cluster.sh restart

# Clean logs and stop
./scripts/start-cluster.sh clean
```

**Features**:
- Manages 3-node cluster (ports 8080, 8081, 8082)
- Background process management
- Health verification
- Detailed status reporting
- Graceful shutdown

### `test-operations.sh`
**Purpose**: Comprehensive functionality testing

```bash
./scripts/test-operations.sh
```

**Test Coverage**:
- Basic cache operations (PUT/GET/DELETE)
- Multi-key operations
- Cross-node data access
- Admin endpoint validation
- Error case handling
- Performance testing

### `verify-endpoints.sh`
**Purpose**: Quick endpoint verification

```bash
# Test default local instance
./scripts/verify-endpoints.sh

# Test custom URL
./scripts/verify-endpoints.sh http://localhost:8081
```

**Features**:
- Tests all API endpoints
- Validates response codes
- Shows working examples
- Quick troubleshooting

## 🏗️ Project Structure

```
akka-distributed-cache/
├── src/
│   ├── main/
│   │   ├── java/ai/akka/cache/
│   │   │   ├── CacheActor.java              # Core cache logic
│   │   │   ├── CacheRoutes.java             # HTTP API routes
│   │   │   └── DistributedCacheApplication.java # Main application
│   │   └── resources/
│   │       ├── application.conf             # Akka configuration
│   │       └── logback.xml                  # Logging configuration
│   └── test/java/                           # Test files (future)
├── scripts/
│   ├── setup-project.sh                    # Project initialization
│   ├── start-single.sh                     # Single node startup
│   ├── start-cluster.sh                    # Cluster management
│   ├── test-operations.sh                  # Comprehensive testing
│   └── verify-endpoints.sh                 # Quick endpoint verification
├── logs/                                    # Runtime logs
├── pids/                                    # Process ID files
├── pom.xml                                  # Maven configuration
└── README.md                               # This file
```

## 🔧 Configuration

### Default Ports

| Node | HTTP Port | Akka Port | Usage |
|------|-----------|-----------|-------|
| Node 1 | 8080 | 2551 | Primary/Development |
| Node 2 | 8081 | 2552 | Cluster member |
| Node 3 | 8082 | 2553 | Cluster member |

### Key Configuration Files

- **`application.conf`**: Akka cluster settings, timeouts, logging levels
- **`logback.xml`**: Logging configuration for console and file output
- **`pom.xml`**: Maven dependencies and build configuration

## 🔍 Troubleshooting

### Common Issues

**1. Port Already in Use**
```bash
# Check what's using the port
lsof -i :8080

# Use different port
./scripts/start-single.sh 2551 8085
```

**2. Compilation Errors**
```bash
# Clean and rebuild
mvn clean compile

# Check Java version
java -version  # Ensure Java 11+
```

**3. Node Won't Start**
```bash
# Check logs
tail -f logs/node1.log

# Verify project structure
./scripts/setup-project.sh
```

**4. Cache Operations Fail**
```bash
# Verify endpoints
./scripts/verify-endpoints.sh

# Check node health
curl http://localhost:8080/admin/status
```

### Log Locations

- **Compilation**: `logs/setup-compile.log`
- **Node 1**: `logs/node1.log`
- **Node 2**: `logs/node2.log`
- **Node 3**: `logs/node3.log`

## 🚦 Development Workflow

### Daily Development
```bash
# 1. Start development node
./scripts/start-single.sh

# 2. Test your changes
curl -X PUT http://localhost:8080/cache/test -d 'value'
curl http://localhost:8080/cache/test

# 3. Stop with Ctrl+C
```

### Testing Changes
```bash
# 1. Run quick verification
./scripts/verify-endpoints.sh

# 2. Run comprehensive tests
./scripts/test-operations.sh

# 3. Test Single Node behavior
./scripts/start-single.sh
./scripts/test-operations.sh
```
<!--
### Production Deployment
```bash
# 1. Setup production environment
./scripts/setup-project.sh

# 2. Start cluster
./scripts/start-cluster.sh start

# 3. Verify health
./scripts/start-cluster.sh status

# 4. Monitor logs
tail -f logs/*.log
```

## 🎯 Performance Characteristics

- **Latency**: Sub-millisecond for local cache hits
- **Throughput**: Thousands of operations per second per node
- **Scalability**: Horizontal scaling via cluster membership
- **Consistency**: Eventually consistent across cluster nodes
- **Availability**: High availability through cluster redundancy

## 🛡️ Production Considerations

### Monitoring
- Check `/admin/status` for node health
- Monitor log files for errors
- Use cluster status for distributed health

### Scaling
- Add nodes by starting with different ports
- Update seed-nodes in configuration
- Monitor memory usage per node

### Security
- Consider adding authentication to admin endpoints
- Use HTTPS in production
- Implement rate limiting if needed

-->

## 🔮 Future Enhancements

- **Persistence**: Add database backing for durability
- **Authentication**: Secure admin and cache endpoints
- **Metrics**: Prometheus/Grafana integration
- **Consistency Levels**: Configurable consistency (ONE/QUORUM/ALL)
- **Replication**: Configurable replication factor
- **Load Balancing**: Built-in load balancing strategies

## 📄 License

[Add your license information here]

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with provided scripts
5. Submit a pull request

---

**Happy Caching! 🚀**

For issues or questions, please check the troubleshooting section or create an issue in the repository.