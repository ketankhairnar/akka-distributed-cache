# Akka Distributed Cache

A high-performance, distributed cache system built with Akka Cluster Sharding and Akka HTTP. This project provides a scalable, fault-tolerant caching solution with RESTful JSON API endpoints and comprehensive cluster management capabilities.

## 🚀 Features

- **Distributed Architecture**: Built on Akka Cluster Sharding for horizontal scaling
- **RESTful JSON API**: Simple HTTP interface with JSON request/response format
- **Fault Tolerance**: Automatic failure detection and recovery
- **Entity Distribution**: Intelligent key-based entity distribution across cluster nodes
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

### 3. Test Basic Operations (JSON API)
```bash
# Store a value (JSON format)
curl -X PUT http://localhost:8080/cache/hello \
     -H 'Content-Type: application/json' \
     -d '{"value":"world"}'

# Retrieve the value (returns JSON)
curl http://localhost:8080/cache/hello

# Check node status
curl http://localhost:8080/admin/status

# View API documentation
curl http://localhost:8080/api
```

### 4. Start Full Cluster (Production)
```bash
# Start 3-node cluster
./scripts/start-cluster.sh start

# Check cluster status
./scripts/start-cluster.sh status

# Run comprehensive tests
./scripts/test-operations.sh
```

## 📚 API Reference

### Cache Operations (JSON Format)

| Method | Endpoint | Description | Request Body | Response |
|--------|----------|-------------|--------------|----------|
| `PUT` | `/cache/{key}` | Store a value | `{"value":"data"}` | `Put successful` |
| `GET` | `/cache/{key}` | Retrieve a value | None | `{"value":"data"}` |
| `DELETE` | `/cache/{key}` | Remove a value | None | `Delete successful` |

### Examples

```bash
# Store data with JSON
curl -X PUT http://localhost:8080/cache/user123 \
     -H 'Content-Type: application/json' \
     -d '{"value":"john_doe"}'

# Retrieve data (returns JSON)
curl http://localhost:8080/cache/user123
# Response: {"value":"john_doe"}

# Delete data
curl -X DELETE http://localhost:8080/cache/user123
```

### Cluster Operations

```bash
# Test data distribution across nodes
curl -X PUT http://localhost:8080/cache/key1 \
     -H 'Content-Type: application/json' \
     -d '{"value":"node1_data"}'

curl -X PUT http://localhost:8081/cache/key2 \
     -H 'Content-Type: application/json' \
     -d '{"value":"node2_data"}'

# Access data from any node (automatic routing)
curl http://localhost:8082/cache/key1  # Gets data from node storing key1
curl http://localhost:8080/cache/key2  # Gets data from node storing key2
```

### Admin Operations

| Method | Endpoint | Description | Response |
|--------|----------|-------------|----------|
| `GET` | `/admin/status` | Detailed node status | Node info, timestamps, sharding details |
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
- JSON API ready
- Immediate error feedback

### `start-cluster.sh`
**Purpose**: Production cluster management with sharding

```bash
# Start 3-node cluster with sharding
./scripts/start-cluster.sh start

# Check detailed cluster status
./scripts/start-cluster.sh status

# Stop cluster gracefully
./scripts/start-cluster.sh stop

# Restart cluster
./scripts/start-cluster.sh restart

# Clean logs and stop
./scripts/start-cluster.sh clean

# Run comprehensive tests
./scripts/start-cluster.sh test
```

**Features**:
- Manages 3-node cluster (ports 8080, 8081, 8082)
- Background process management with CountDownLatch blocking
- Cluster sharding with entity distribution
- Health verification with JSON API testing
- Detailed status reporting
- Graceful shutdown with coordinated shutdown

### `test-operations.sh`
**Purpose**: Comprehensive functionality testing

```bash
./scripts/test-operations.sh
```

**Test Coverage**:
- JSON API operations (PUT/GET/DELETE)
- Multi-key operations across cluster
- Cross-node data access and routing
- Entity distribution verification
- Admin endpoint validation
- Error case handling
- Cluster consistency testing

### `verify-endpoints.sh`
**Purpose**: Quick endpoint verification

```bash
# Test default local instance
./scripts/verify-endpoints.sh

# Test custom URL
./scripts/verify-endpoints.sh http://localhost:8081
```

**Features**:
- Tests all JSON API endpoints
- Validates response codes and formats
- Shows working examples
- Quick troubleshooting

## 🏗️ Project Structure

```
akka-distributed-cache/
├── src/
│   ├── main/
│   │   ├── java/ai/akka/cache/
│   │   │   ├── CacheActor.java              # Entity actors with sharding
│   │   │   ├── CacheRoutes.java             # HTTP JSON API routes
│   │   │   └── DistributedCacheApplication.java # Main app with sharding
│   │   └── resources/
│   │       ├── application.conf             # Cluster sharding configuration
│   │       └── logback.xml                  # Logging configuration
│   └── test/java/                           # Test files (future)
├── scripts/
│   ├── setup-project.sh                    # Project initialization
│   ├── start-single.sh                     # Single node startup
│   ├── start-cluster.sh                    # Cluster management with sharding
│   ├── test-operations.sh                  # Comprehensive testing
│   └── verify-endpoints.sh                 # Quick endpoint verification
├── logs/                                    # Runtime logs (node1.log, node2.log, node3.log)
├── pids/                                    # Process ID files for cluster nodes
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

### Cluster Sharding

- **Entity Distribution**: Keys are automatically distributed across nodes based on hash
- **Number of Shards**: 10 (configurable in application.conf)
- **State Store**: Distributed Data (ddata) for cluster coordination
- **Rebalancing**: Automatic shard rebalancing as nodes join/leave

### Key Configuration Files

- **`application.conf`**: Akka cluster settings, sharding configuration, timeouts
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

**3. Cluster Node Won't Start**
```bash
# Check logs
tail -f logs/node1.log

# Verify cluster status
./scripts/start-cluster.sh status

# Restart cluster
./scripts/start-cluster.sh restart
```

**4. JSON API Operations Fail**
```bash
# Verify endpoints
./scripts/verify-endpoints.sh

# Check cluster health
curl http://localhost:8080/admin/status
curl http://localhost:8081/admin/status
curl http://localhost:8082/admin/status

# Test sharding distribution
./scripts/test-operations.sh
```

**5. Serialization Issues**
- All commands/responses are now properly serializable
- EntityRef handles cluster communication automatically
- No more ActorRef serialization errors

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

# 2. Test your changes (JSON API)
curl -X PUT http://localhost:8080/cache/test \
     -H 'Content-Type: application/json' \
     -d '{"value":"test-data"}'
curl http://localhost:8080/cache/test

# 3. Stop with Ctrl+C
```

### Testing Changes
```bash
# 1. Run quick verification
./scripts/verify-endpoints.sh

# 2. Run comprehensive tests
./scripts/test-operations.sh

# 3. Test cluster behavior
./scripts/start-cluster.sh start
./scripts/test-operations.sh
./scripts/start-cluster.sh stop
```

### Production Deployment
```bash
# 1. Setup production environment
./scripts/setup-project.sh

# 2. Start cluster with sharding
./scripts/start-cluster.sh start

# 3. Verify cluster health
./scripts/start-cluster.sh status

# 4. Monitor logs
tail -f logs/*.log
```

## 🎯 Performance Characteristics

- **Latency**: Sub-millisecond for local cache hits
- **Throughput**: Thousands of operations per second per node
- **Scalability**: Horizontal scaling via cluster sharding
- **Consistency**: Eventually consistent across cluster nodes
- **Availability**: High availability through cluster redundancy
- **Distribution**: Automatic entity distribution across nodes

## 🛡️ Production Considerations

### Monitoring
- Check `/admin/status` for node health and sharding info
- Monitor log files for errors and cluster events
- Use cluster status for distributed health verification

### Scaling
- Add nodes by starting with different ports
- Entities automatically rebalance across new nodes
- Monitor memory usage per node and shard distribution

### Security
- Consider adding authentication to admin endpoints
- Use HTTPS in production
- Implement rate limiting if needed

## 🔮 Future Enhancements

- **Persistence**: Add database backing for durability with Akka Persistence
- **Authentication**: Secure admin and cache endpoints
- **Metrics**: Prometheus/Grafana integration for cluster monitoring
- **Consistency Levels**: Configurable consistency (ONE/QUORUM/ALL)
- **Replication**: Configurable replication factor across nodes
- **Load Balancing**: Advanced load balancing strategies

## 📄 License

[Add your license information here]

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with provided scripts (single node and cluster)
5. Verify JSON API functionality
6. Submit a pull request

---

**Happy Distributed Caching! 🚀**

For issues or questions, please check the troubleshooting section or create an issue in the repository.