# Akka Distributed Cache

A distributed cache built on Akka Cluster Sharding and Akka HTTP. One entity actor per cache key, automatic shard rebalancing across a 3-node cluster, JSON HTTP API on every node.

> Learning project — not production-ready. See [Limits](#limits) before using.

## Architecture

```
                    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
   HTTP client ───▶ │   Node 1     │  │   Node 2     │  │   Node 3     │
   (any node)       │  :8080 HTTP  │  │  :8081 HTTP  │  │  :8082 HTTP  │
                    │  :2551 Akka  │◀▶│  :2552 Akka  │◀▶│  :2553 Akka  │
                    └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
                           │                 │                 │
                           ▼                 ▼                 ▼
                    ┌─────────────────────────────────────────────────┐
                    │         Akka Cluster Sharding (10 shards)        │
                    │   shard = hash(key) % 10                         │
                    │   each shard owns N entity actors                │
                    │   entity = single CacheActor instance per key    │
                    └─────────────────────────────────────────────────┘
                           │
                           ▼
                    ┌──────────────────┐
                    │ Distributed Data │   shard → node assignment
                    │  (CRDT, ddata)   │   gossiped via Akka Cluster
                    └──────────────────┘
```

**Request lifecycle (`PUT /cache/foo`):**

1. HTTP request hits any node (e.g. node 2). `CacheRoutes` parses it.
2. `CacheProxy` resolves the entity ref via `ClusterSharding.entityRefFor("CacheActor", "foo")`.
3. Akka routes the message to the node currently hosting shard `hash("foo") % 10`. Shard rebalances move entities transparently.
4. The single `CacheActor` for key `foo` updates its in-memory map and replies.
5. Response returns through the proxy to the originating HTTP client.

Reads, writes, deletes follow the same path. Single-writer per key — no concurrency on the hot value.

## Why this design

| Choice | Why |
|---|---|
| Akka Cluster Sharding (not consistent hashing) | Built-in shard rebalance during membership change. No manual ring management. |
| ddata for shard coordination | CRDT-based, no external coordinator (no etcd / ZooKeeper). |
| One entity actor per key | Eliminates concurrency control on the value. Akka's mailbox is the lock. |
| In-memory state | Cache, not store. Persistence is a different problem. |

## Limits

Honest list of what this does **not** do:

- **No replication.** A node dying loses all entities it owned until they're re-created on writes elsewhere. Reads fail until then.
- **No persistence beyond process lifetime.** `state-store-mode = ddata` covers shard assignments, not entity state. `passivate-idle-entity-after = 10m` evicts cold keys.
- **No quorum reads/writes.** Single-writer-per-key gives strong consistency on hot path; failure semantics are last-writer-wins on entity recreation.
- **Java serialization.** Faster to set up, slow + fragile in production. Switch to Jackson or protobuf for real use.
- **No metrics endpoint.** `/admin/status` exposes node info; no Prometheus, no histograms.
- **In-memory journal.** Persistence module is wired but uses `inmem` journal. Not crash-safe.
- **3-node cluster fixed in scripts.** Number of shards (10) is fine for ~3 nodes; needs raising for larger deployments.

## Features

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
# Response: {"value":"world"}

# Check node status
curl http://localhost:8080/admin/status

# View API documentation
curl http://localhost:8080/api
```

### 4. Start Full Cluster (Production)
```bash
# Start 3-node cluster
./scripts/cluster.sh start

# Check cluster status
./scripts/cluster.sh status

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
# Store data with JSON format
curl -X PUT http://localhost:8080/cache/user123 \
     -H 'Content-Type: application/json' \
     -d '{"value":"john_doe"}'

# Retrieve data (returns JSON)
curl http://localhost:8080/cache/user123
# Response: {"value":"john_doe"}

# Delete data
curl -X DELETE http://localhost:8080/cache/user123
# Response: Delete successful
```

### Cluster Operations
```bash
# Test data distribution across nodes (JSON format)
curl -X PUT http://localhost:8080/cache/key1 \
     -H 'Content-Type: application/json' \
     -d '{"value":"node1_data"}'

curl -X PUT http://localhost:8081/cache/key2 \
     -H 'Content-Type: application/json' \
     -d '{"value":"node2_data"}'

# Access data from any node (automatic routing)
curl http://localhost:8082/cache/key1  # Returns: {"value":"node1_data"}
curl http://localhost:8080/cache/key2  # Returns: {"value":"node2_data"}
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

### `verify-endpoints.sh`
**Purpose**: Quick endpoint verification with JSON API

```bash
# Test default local instance
./scripts/verify-endpoints.sh

# Test custom URL
./scripts/verify-endpoints.sh http://localhost:8081
```

**Features**:
- Tests all JSON API endpoints with correct format
- Validates response codes and JSON responses
- Shows working examples with proper Content-Type headers
- Quick troubleshooting

### `test-operations.sh`
**Purpose**: Comprehensive functionality testing

```bash
./scripts/test-operations.sh
```

**Test Coverage**:
- JSON API operations (PUT/GET/DELETE) with proper headers
- Multi-key operations across cluster
- Cross-node data access and routing
- Entity distribution verification
- Admin endpoint validation
- Error case handling
- Cluster consistency testing

### `cluster.sh`
**Purpose**: Production cluster management with sharding

```bash
# Start 3-node cluster with sharding
./scripts/cluster.sh start

# Check detailed cluster status
./scripts/cluster.sh status

# Stop cluster gracefully
./scripts/cluster.sh stop

# Restart cluster
./scripts/cluster.sh restart

# Clean logs and stop
./scripts/cluster.sh clean

# Run comprehensive tests
./scripts/cluster.sh test
```

**Features**:
- Manages 3-node cluster (ports 8080, 8081, 8082)
- Background process management with CountDownLatch blocking
- Cluster sharding with entity distribution
- Health verification with JSON API testing
- Detailed status reporting
- Graceful shutdown with coordinated shutdown

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
│   ├── setup-project.sh                     # Project initialization
│   ├── start-single.sh                      # Single node startup
│   ├── cluster.sh                           # Cluster management with sharding
│   ├── test-operations.sh                   # Comprehensive testing
│   └── verify-endpoints.sh                  # Quick endpoint verification
├── logs/                                    # Runtime logs (node1.log, node2.log, node3.log)
├── pids/                                    # Process ID files for cluster nodes
├── pom.xml                                  # Maven configuration
└── README.md                                # This file
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

**2. Wrong API Format**
The API requires JSON format for PUT operations:
```bash
# ❌ Wrong - sending plain text
curl -X PUT http://localhost:8080/cache/hello -d 'world'

# ✅ Correct - sending JSON
curl -X PUT http://localhost:8080/cache/hello \
     -H 'Content-Type: application/json' \
     -d '{"value":"world"}'
```

**3. Compilation Errors**
```bash
# Clean and rebuild
mvn clean compile

# Check Java version
java -version  # Ensure Java 11+
```

**4. Missing Dependencies**
```bash
# Download dependencies
mvn dependency:resolve

# Verify classpath
mvn dependency:build-classpath
```

## 🎯 Important API Notes

### JSON Format Requirements

**PUT Operations** must include:
- `Content-Type: application/json` header
- JSON body with `value` field: `{"value":"your-data"}`

**GET Operations** return:
- JSON response: `{"value":"your-data"}`
- 404 status for missing keys

**DELETE Operations**:
- No body required
- Returns success message

### Examples of Correct Usage:
```bash
# Store JSON data
curl -X PUT http://localhost:8080/cache/session123 \
     -H 'Content-Type: application/json' \
     -d '{"value":"user_data_here"}'

# Retrieve JSON data  
curl http://localhost:8080/cache/session123
# Returns: {"value":"user_data_here"}

# Delete data
curl -X DELETE http://localhost:8080/cache/session123
# Returns: Delete successful
```

### Error Responses
```bash
# Missing key
curl http://localhost:8080/cache/nonexistent
# Returns: 404 Not Found - "Key not found"

# Invalid JSON format
curl -X PUT http://localhost:8080/cache/test -d 'plain-text'
# Returns: 400 Bad Request - Invalid JSON
```

## 🌟 Advanced Usage

### Multiple Data Types
```bash
# Store complex JSON values
curl -X PUT http://localhost:8080/cache/user123 \
     -H 'Content-Type: application/json' \
     -d '{"value":"{\"name\":\"john\",\"age\":30}"}'

# Store simple strings
curl -X PUT http://localhost:8080/cache/message \
     -H 'Content-Type: application/json' \
     -d '{"value":"Hello World"}'
```

### Cluster Testing
```bash
# Test cross-node data access
curl -X PUT http://localhost:8080/cache/test1 \
     -H 'Content-Type: application/json' \
     -d '{"value":"from-node-1"}'

# Access from different node
curl http://localhost:8081/cache/test1
# Should return: {"value":"from-node-1"}
```

---
