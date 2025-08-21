# Complete CacheActor + EnhancedDistributedCache Integration Recipe

## 1. Project Structure
```
src/main/java/ai/akka/cache/
├── CacheExtension.java          (NEW - Akka Extension)
├── EnhancedCacheActor.java      (NEW - Enhanced Actor)
├── CacheRoutes.java             (MODIFIED - Add enhanced routes)
├── CacheClusterApp.java         (MODIFIED - Use enhanced actor)
├── EnhancedDistributedCache.java (EXISTING)
├── ConsistencyLevel.java        (EXISTING)
└── ... (all other existing cache files)
```

## 2. Dependencies (add to pom.xml/build.sbt)
```xml
<!-- If using Maven -->
<dependency>
    <groupId>com.typesafe.akka</groupId>
    <artifactId>akka-actor-typed_2.13</artifactId>
    <version>2.8.0</version>
</dependency>
<dependency>
    <groupId>com.typesafe.akka</groupId>
    <artifactId>akka-cluster-typed_2.13</artifactId>
    <version>2.8.0</version>
</dependency>
```

## 3. CacheExtension.java (NEW FILE)
```java
package ai.akka.cache;

import akka.actor.typed.ActorSystem;
import akka.actor.typed.Extension;
import akka.actor.typed.ExtensionId;

/**
 * Akka Extension for managing singleton EnhancedDistributedCache
 * across the entire cluster
 */
public class CacheExtension implements Extension {
    private final EnhancedDistributedCache distributedCache;
    
    public CacheExtension(ActorSystem<?> system) {
        // Initialize with cluster-aware configuration
        int nodeCount = 3; // Could be derived from cluster size
        int replicationFactor = 2;
        ConsistencyLevel defaultLevel = ConsistencyLevel.QUORUM;
        
        this.distributedCache = new EnhancedDistributedCache(
            nodeCount, 
            replicationFactor, 
            defaultLevel
        );
        
        // Log initialization
        system.log().info("Distributed Cache Extension initialized with {} nodes", nodeCount);
    }
    
    public EnhancedDistributedCache getCache() {
        return distributedCache;
    }
    
    // Akka Extension ID for lookup
    public static final ExtensionId<CacheExtension> CACHE_EXTENSION_ID = 
        new ExtensionId<CacheExtension>() {
            @Override
            public CacheExtension createExtension(ActorSystem<?> system) {
                return new CacheExtension(system);
            }
        };
    
    // Convenience method for getting cache from any actor
    public static EnhancedDistributedCache get(ActorSystem<?> system) {
        return CACHE_EXTENSION_ID.get(system).getCache();
    }
}
```

## 4. EnhancedCacheActor.java (NEW FILE)
```java
package ai.akka.cache;

import akka.actor.typed.ActorRef;
import akka.actor.typed.Behavior;
import akka.actor.typed.javadsl.*;

/**
 * Enhanced Cache Actor that delegates to EnhancedDistributedCache
 * while maintaining clean Actor interface
 */
public class EnhancedCacheActor extends AbstractBehavior<EnhancedCacheActor.Command> {

    // ========== COMMAND INTERFACE ==========
    public interface Command {}

    // Basic Commands (same interface as original)
    public static final class Get implements Command {
        public final String key;
        public final ActorRef<Response> replyTo;

        public Get(String key, ActorRef<Response> replyTo) {
            this.key = key;
            this.replyTo = replyTo;
        }
    }

    public static final class Put implements Command {
        public final String key;
        public final String value;
        public final ActorRef<Response> replyTo;

        public Put(String key, String value, ActorRef<Response> replyTo) {
            this.key = key;
            this.value = value;
            this.replyTo = replyTo;
        }
    }

    public static final class Delete implements Command {
        public final String key;
        public final ActorRef<Response> replyTo;

        public Delete(String key, ActorRef<Response> replyTo) {
            this.key = key;
            this.replyTo = replyTo;
        }
    }

    // Enhanced Commands with Consistency Levels
    public static final class GetWithConsistency implements Command {
        public final String key;
        public final ConsistencyLevel level;
        public final ActorRef<Response> replyTo;

        public GetWithConsistency(String key, ConsistencyLevel level, ActorRef<Response> replyTo) {
            this.key = key;
            this.level = level;
            this.replyTo = replyTo;
        }
    }

    public static final class PutWithConsistency implements Command {
        public final String key;
        public final String value;
        public final ConsistencyLevel level;
        public final ActorRef<Response> replyTo;

        public PutWithConsistency(String key, String value, ConsistencyLevel level, ActorRef<Response> replyTo) {
            this.key = key;
            this.value = value;
            this.level = level;
            this.replyTo = replyTo;
        }
    }

    // Admin Commands
    public static final class GetClusterStatus implements Command {
        public final ActorRef<ClusterStatusResponse> replyTo;
        
        public GetClusterStatus(ActorRef<ClusterStatusResponse> replyTo) {
            this.replyTo = replyTo;
        }
    }

    // ========== RESPONSE INTERFACE ==========
    public interface Response {}

    public static final class Found implements Response {
        public final String value;
        public Found(String value) { this.value = value; }
    }

    public static final class NotFound implements Response {}
    public static final class Done implements Response {}
    
    public static final class CacheError implements Response {
        public final String message;
        public CacheError(String message) { this.message = message; }
    }

    public static final class ClusterStatusResponse implements Response {
        public final String status;
        public ClusterStatusResponse(String status) { this.status = status; }
    }

    // ========== ACTOR IMPLEMENTATION ==========
    
    // Factory method
    public static Behavior<Command> create() {
        return Behaviors.setup(EnhancedCacheActor::new);
    }

    // Shared distributed cache instance
    private final EnhancedDistributedCache distributedCache;

    private EnhancedCacheActor(ActorContext<Command> context) {
        super(context);
        // Get singleton cache instance via Extension
        this.distributedCache = CacheExtension.get(context.getSystem());
        
        context.getLog().info("EnhancedCacheActor started with distributed cache");
    }

    @Override
    public Receive<Command> createReceive() {
        return newReceiveBuilder()
                .onMessage(Get.class, this::onGet)
                .onMessage(Put.class, this::onPut)
                .onMessage(Delete.class, this::onDelete)
                .onMessage(GetWithConsistency.class, this::onGetWithConsistency)
                .onMessage(PutWithConsistency.class, this::onPutWithConsistency)
                .onMessage(GetClusterStatus.class, this::onGetClusterStatus)
                .build();
    }

    // ========== MESSAGE HANDLERS ==========

    private Behavior<Command> onGet(Get msg) {
        try {
            String value = distributedCache.get(msg.key);
            if (value != null) {
                msg.replyTo.tell(new Found(value));
            } else {
                msg.replyTo.tell(new NotFound());
            }
        } catch (Exception e) {
            getContext().getLog().error("Get operation failed for key: {}", msg.key, e);
            msg.replyTo.tell(new CacheError("Get failed: " + e.getMessage()));
        }
        return this;
    }

    private Behavior<Command> onPut(Put msg) {
        try {
            distributedCache.put(msg.key, msg.value);
            msg.replyTo.tell(new Done());
        } catch (Exception e) {
            getContext().getLog().error("Put operation failed for key: {}", msg.key, e);
            msg.replyTo.tell(new CacheError("Put failed: " + e.getMessage()));
        }
        return this;
    }

    private Behavior<Command> onDelete(Delete msg) {
        try {
            distributedCache.delete(msg.key);
            msg.replyTo.tell(new Done());
        } catch (Exception e) {
            getContext().getLog().error("Delete operation failed for key: {}", msg.key, e);
            msg.replyTo.tell(new CacheError("Delete failed: " + e.getMessage()));
        }
        return this;
    }

    private Behavior<Command> onGetWithConsistency(GetWithConsistency msg) {
        try {
            String value = distributedCache.get(msg.key, msg.level);
            if (value != null) {
                msg.replyTo.tell(new Found(value));
            } else {
                msg.replyTo.tell(new NotFound());
            }
        } catch (Exception e) {
            getContext().getLog().error("Get with consistency failed for key: {}", msg.key, e);
            msg.replyTo.tell(new CacheError("Get failed: " + e.getMessage()));
        }
        return this;
    }

    private Behavior<Command> onPutWithConsistency(PutWithConsistency msg) {
        try {
            distributedCache.put(msg.key, msg.value, msg.level);
            msg.replyTo.tell(new Done());
        } catch (Exception e) {
            getContext().getLog().error("Put with consistency failed for key: {}", msg.key, e);
            msg.replyTo.tell(new CacheError("Put failed: " + e.getMessage()));
        }
        return this;
    }

    private Behavior<Command> onGetClusterStatus(GetClusterStatus msg) {
        try {
            // Capture cluster status as string
            java.io.ByteArrayOutputStream baos = new java.io.ByteArrayOutputStream();
            java.io.PrintStream ps = new java.io.PrintStream(baos);
            java.io.PrintStream old = System.out;
            System.setOut(ps);
            distributedCache.printClusterStatus();
            System.setOut(old);
            String status = baos.toString();
            
            msg.replyTo.tell(new ClusterStatusResponse(status));
        } catch (Exception e) {
            getContext().getLog().error("Failed to get cluster status", e);
            msg.replyTo.tell(new ClusterStatusResponse("Error: " + e.getMessage()));
        }
        return this;
    }
}
```

## 5. Enhanced CacheRoutes.java (MODIFY EXISTING)
```java
package ai.akka.cache;

import akka.actor.typed.ActorRef;
import akka.actor.typed.ActorSystem;
import akka.actor.typed.javadsl.AskPattern;
import akka.http.javadsl.marshallers.jackson.Jackson;
import akka.http.javadsl.model.ContentTypes;
import akka.http.javadsl.model.HttpEntities;
import akka.http.javadsl.model.StatusCodes;
import akka.http.javadsl.server.AllDirectives;
import akka.http.javadsl.server.Route;

import java.time.Duration;
import java.util.concurrent.CompletionStage;

import static akka.http.javadsl.server.PathMatchers.segment;

public class CacheRoutes extends AllDirectives {
    private final ActorRef<EnhancedCacheActor.Command> cacheActor;
    private final ActorSystem<?> system;

    public CacheRoutes(ActorRef<EnhancedCacheActor.Command> cacheActor, ActorSystem<?> system) {
        this.cacheActor = cacheActor;
        this.system = system;
    }

    private static final Duration duration = Duration.ofSeconds(5);

    public Route routes() {
        return concat(
                // Basic cache operations
                pathPrefix("cache", () ->
                        path(segment(), (String key) -> concat(
                                get(() -> {
                                    CompletionStage<EnhancedCacheActor.Response> future =
                                            AskPattern.<EnhancedCacheActor.Command, EnhancedCacheActor.Response>ask(
                                                    cacheActor,
                                                    replyTo -> new EnhancedCacheActor.Get(key, replyTo),
                                                    duration,
                                                    system.scheduler()
                                            );
                                    return onSuccess(future, this::handleGetResponse);
                                }),
                                put(() -> entity(Jackson.unmarshaller(PutPayload.class), putPayload -> {
                                    CompletionStage<EnhancedCacheActor.Response> future =
                                            AskPattern.<EnhancedCacheActor.Command, EnhancedCacheActor.Response>ask(
                                                    cacheActor,
                                                    replyTo -> new EnhancedCacheActor.Put(key, putPayload.value, replyTo),
                                                    duration,
                                                    system.scheduler()
                                            );
                                    return onSuccess(future, this::handlePutResponse);
                                })),
                                delete(() -> {
                                    CompletionStage<EnhancedCacheActor.Response> future =
                                            AskPattern.<EnhancedCacheActor.Command, EnhancedCacheActor.Response>ask(
                                                    cacheActor,
                                                    replyTo -> new EnhancedCacheActor.Delete(key, replyTo),
                                                    duration,
                                                    system.scheduler()
                                            );
                                    return onSuccess(future, this::handleDeleteResponse);
                                })
                        ))
                ),
                
                // Enhanced operations with consistency levels
                pathPrefix("cache-enhanced", () -> concat(
                        path(segment(), (String key) -> concat(
                                get(() -> parameter("consistency", consistency -> {
                                    ConsistencyLevel level = parseConsistencyLevel(consistency);
                                    CompletionStage<EnhancedCacheActor.Response> future =
                                            AskPattern.<EnhancedCacheActor.Command, EnhancedCacheActor.Response>ask(
                                                    cacheActor,
                                                    replyTo -> new EnhancedCacheActor.GetWithConsistency(key, level, replyTo),
                                                    duration,
                                                    system.scheduler()
                                            );
                                    return onSuccess(future, this::handleGetResponse);
                                })),
                                put(() -> parameter("consistency", consistency -> 
                                    entity(Jackson.unmarshaller(PutPayload.class), putPayload -> {
                                        ConsistencyLevel level = parseConsistencyLevel(consistency);
                                        CompletionStage<EnhancedCacheActor.Response> future =
                                                AskPattern.<EnhancedCacheActor.Command, EnhancedCacheActor.Response>ask(
                                                        cacheActor,
                                                        replyTo -> new EnhancedCacheActor.PutWithConsistency(key, putPayload.value, level, replyTo),
                                                        duration,
                                                        system.scheduler()
                                                );
                                        return onSuccess(future, this::handlePutResponse);
                                    })
                                ))
                        ))
                )),
                
                // Admin endpoints
                pathPrefix("admin", () -> concat(
                        path("status", () -> get(() -> {
                            CompletionStage<EnhancedCacheActor.ClusterStatusResponse> future =
                                    AskPattern.<EnhancedCacheActor.Command, EnhancedCacheActor.ClusterStatusResponse>ask(
                                            cacheActor,
                                            replyTo -> new EnhancedCacheActor.GetClusterStatus(replyTo),
                                            duration,
                                            system.scheduler()
                                    );
                            return onSuccess(future, status -> 
                                complete(HttpEntities.create(ContentTypes.TEXT_PLAIN_UTF8, status.status))
                            );
                        }))
                ))
        );
    }

    private Route handleGetResponse(EnhancedCacheActor.Response response) {
        if (response instanceof EnhancedCacheActor.Found found) {
            return complete(HttpEntities.create(ContentTypes.TEXT_PLAIN_UTF8, found.value));
        } else if (response instanceof EnhancedCacheActor.NotFound) {
            return complete(StatusCodes.NOT_FOUND, "Key not found");
        } else if (response instanceof EnhancedCacheActor.CacheError error) {
            return complete(StatusCodes.INTERNAL_SERVER_ERROR, error.message);
        } else {
            return complete(StatusCodes.INTERNAL_SERVER_ERROR, "Unknown response");
        }
    }

    private Route handlePutResponse(EnhancedCacheActor.Response response) {
        if (response instanceof EnhancedCacheActor.Done) {
            return complete("Put successful");
        } else if (response instanceof EnhancedCacheActor.CacheError error) {
            return complete(StatusCodes.INTERNAL_SERVER_ERROR, error.message);
        } else {
            return complete(StatusCodes.INTERNAL_SERVER_ERROR, "Unknown response");
        }
    }

    private Route handleDeleteResponse(EnhancedCacheActor.Response response) {
        if (response instanceof EnhancedCacheActor.Done) {
            return complete("Delete successful");
        } else if (response instanceof EnhancedCacheActor.CacheError error) {
            return complete(StatusCodes.INTERNAL_SERVER_ERROR, error.message);
        } else {
            return complete(StatusCodes.INTERNAL_SERVER_ERROR, "Unknown response");
        }
    }

    private ConsistencyLevel parseConsistencyLevel(String level) {
        try {
            return ConsistencyLevel.valueOf(level.toUpperCase());
        } catch (IllegalArgumentException e) {
            return ConsistencyLevel.ONE; // Default fallback
        }
    }

    public static class PutPayload {
        public String value;
        public PutPayload() {}
    }
}
```

## 6. Updated CacheClusterApp.java (MODIFY EXISTING)
```java
package ai.akka.cache;

import akka.actor.typed.ActorRef;
import akka.actor.typed.ActorSystem;
import akka.http.javadsl.Http;
import akka.http.javadsl.ServerBinding;
import com.typesafe.config.Config;
import com.typesafe.config.ConfigFactory;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.concurrent.CompletionStage;

public class CacheClusterApp {
    public static void main(String[] args) throws IOException {
        // Default port values
        int akkaPort = args.length > 0 ? Integer.parseInt(args[0]) : 2551;
        int httpPort = args.length > 1 ? Integer.parseInt(args[1]) : 8080;

        // HOCON config with dynamic akka.remote.artery.canonical.port
        Config config = ConfigFactory.parseString(
                "akka.remote.artery.canonical.port=" + akkaPort + "\n"
        ).withFallback(ConfigFactory.load());

        // Actor System startup with Enhanced Actor
        ActorSystem<EnhancedCacheActor.Command> system =
                ActorSystem.create(EnhancedCacheActor.create(), "ClusterSystem", config);

        // Initialize Cache Extension (singleton)
        CacheExtension.get(system);

        // Spawn root actor (EnhancedCacheActor)
        ActorRef<EnhancedCacheActor.Command> cacheActor = system;

        // HTTP setup
        CacheRoutes routes = new CacheRoutes(cacheActor, system);
        Http http = Http.get(system);

        CompletionStage<ServerBinding> binding = http
                .newServerAt("0.0.0.0", httpPort)
                .bind(routes.routes());

        binding.whenComplete((bind, failure) -> {
            if (bind != null) {
                InetSocketAddress address = bind.localAddress();
                System.out.printf(
                        "Enhanced Cache Server online at http://%s:%d/%n",
                        address.getHostString(), address.getPort());
                System.out.println("Available endpoints:");
                System.out.println("  GET    /cache/{key}");
                System.out.println("  PUT    /cache/{key}");
                System.out.println("  DELETE /cache/{key}");
                System.out.println("  GET    /cache-enhanced/{key}?consistency=ONE|QUORUM|ALL");
                System.out.println("  PUT    /cache-enhanced/{key}?consistency=ONE|QUORUM|ALL");
                System.out.println("  GET    /admin/status");
            } else {
                System.err.println("Failed to bind HTTP endpoint: " + failure);
                system.terminate();
            }
        });

        // Graceful shutdown
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            System.out.println("Shutting down...");
            system.terminate();
        }));

        // Wait so JVM doesn't exit
        System.out.println("Press RETURN to stop...");
        System.in.read();
        system.terminate();
    }
}
```

## 7. Testing the Integration

### Basic Operations
```bash
# PUT a value
curl -X PUT http://localhost:8080/cache/mykey \
  -H "Content-Type: application/json" \
  -d '{"value":"myvalue"}'

# GET a value
curl http://localhost:8080/cache/mykey

# DELETE a value
curl -X DELETE http://localhost:8080/cache/mykey
```

### Enhanced Operations with Consistency
```bash
# PUT with QUORUM consistency
curl -X PUT "http://localhost:8080/cache-enhanced/mykey?consistency=QUORUM" \
  -H "Content-Type: application/json" \
  -d '{"value":"consistent-value"}'

# GET with ALL consistency
curl "http://localhost:8080/cache-enhanced/mykey?consistency=ALL"
```

### Admin Operations
```bash
# Get cluster status
curl http://localhost:8080/admin/status
```

## 8. Key Integration Benefits

### ✅ Clean Separation of Concerns
- **Akka Layer**: HTTP API, actor messaging, supervision
- **Cache Layer**: Distributed algorithms, consistency, replication

### ✅ Best of Both Worlds
- **Akka Extensions**: Proper singleton management
- **Enhanced Features**: Consistency levels, bulk operations, metrics

### ✅ Interview-Ready Architecture
- Shows understanding of both Akka and distributed systems
- Demonstrates clean integration patterns
- Exhibits proper resource management

## 9. Interview Talking Points

### Technical Depth
- "I implemented consistent hashing with virtual nodes for data partitioning"
- "The system supports tunable consistency levels - ONE, QUORUM, and ALL"
- "I used Akka Extensions for proper singleton lifecycle management"

### Architectural Decisions
- "I separated the actor layer (API/messaging) from the data layer (consistency/replication)"
- "This allows demonstrating both Akka patterns and distributed systems algorithms"
- "The design shows when to build custom vs leverage framework capabilities"

### Production Considerations
- "In production, I'd replace the EnhancedDistributedCache with Cassandra/Redis"
- "The actor layer would remain the same - clean separation of concerns"
- "This pattern allows for easy technology substitution"

This integration showcases both your Akka knowledge and distributed systems understanding while maintaining clean, maintainable code.
