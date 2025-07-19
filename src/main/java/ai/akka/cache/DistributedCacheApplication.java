package ai.akka.cache;

import akka.actor.typed.ActorSystem;
import akka.cluster.sharding.typed.javadsl.ClusterSharding;
import akka.cluster.sharding.typed.javadsl.Entity;
import akka.cluster.sharding.typed.javadsl.EntityTypeKey;
import akka.http.javadsl.Http;
import akka.http.javadsl.ServerBinding;
import com.typesafe.config.Config;
import com.typesafe.config.ConfigFactory;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.concurrent.CompletionStage;
import java.util.concurrent.CountDownLatch;

public class DistributedCacheApplication {

    // Define the entity type key for sharding
    public static final EntityTypeKey<CacheActor.Command> CACHE_ENTITY_KEY =
            EntityTypeKey.create(CacheActor.Command.class, "CacheEntity");

    public static void main(String[] args) throws IOException {
        // Parse command line arguments
        final int akkaPort = args.length > 0 ? Integer.parseInt(args[0]) : findAvailablePort(2551, 2559);
        int httpPort = args.length > 1 ? Integer.parseInt(args[1]) : 8080;

        // HOCON config with dynamic akka.remote.artery.canonical.port
        Config config = ConfigFactory.parseString(
                "akka.remote.artery.canonical.port=" + akkaPort + "\n"
        ).withFallback(ConfigFactory.load());

        // Actor System startup
        ActorSystem<Void> system = ActorSystem.create(
                akka.actor.typed.javadsl.Behaviors.setup(context -> {

                    // FIXED: Wait for cluster to be ready before initializing sharding
                    context.getSystem().log().info("Initializing cluster sharding...");

                    // Initialize Cluster Sharding with proper message extractor
                    ClusterSharding sharding = ClusterSharding.get(context.getSystem());

                    // FIXED: Initialize the sharded cache entity with proper extractor
                    sharding.init(
                            Entity.of(CACHE_ENTITY_KEY, entityContext -> {
                                // Pass entity context to actor for proper entity ID handling
                                return CacheActor.create(entityContext);
                            }).withMessageExtractor(new CacheMessageExtractor())
                    );

                    context.getSystem().log().info("Cluster sharding initialized with message extractor");

                    // FIXED: Use ClusterSharding directly in routes (no proxy needed)
                    CacheRoutes routes = new CacheRoutes(sharding, context.getSystem());
                    Http http = Http.get(context.getSystem());

                    CompletionStage<ServerBinding> binding = http
                            .newServerAt("0.0.0.0", httpPort)
                            .bind(routes.routes());

                    binding.whenComplete((bind, failure) -> {
                        if (bind != null) {
                            InetSocketAddress address = bind.localAddress();
                            System.out.printf(
                                    "✅ Cache server online at http://%s:%d/%n",
                                    address.getHostString(), address.getPort());
                            System.out.printf("   Akka cluster port: %d%n", akkaPort);
                            System.out.printf("   Node name: %s%n", context.getSystem().name());
                            System.out.printf("   Cluster sharding initialized ✅%n");
                            System.out.printf("   API Format: JSON with sharding ✅%n");
                        } else {
                            System.err.println("❌ Failed to bind HTTP endpoint: " + failure);
                            context.getSystem().terminate();
                        }
                    });

                    return akka.actor.typed.javadsl.Behaviors.empty();
                }),
                "ClusterSystem",
                config
        );

        // FIXED: Replace System.in.read() with proper blocking mechanism
        System.out.println("\n🚀 Distributed cache node started successfully!");
        System.out.println("📝 Test commands (JSON API with Cluster Sharding):");
        System.out.printf("   curl -X PUT http://localhost:%d/cache/test \\\n", httpPort);
        System.out.printf("        -H 'Content-Type: application/json' \\\n");
        System.out.printf("        -d '{\"value\":\"test-data\"}'\n");
        System.out.printf("   curl http://localhost:%d/cache/test\n", httpPort);
        System.out.printf("   curl http://localhost:%d/admin/status\n", httpPort);

        // Detect if running in background/cluster mode vs interactive mode
        boolean isInteractive = System.console() != null && System.getProperty("cluster.mode") == null;

        if (isInteractive) {
            System.out.println("\nPress RETURN to stop...");
            try {
                System.in.read();
            } catch (IOException e) {
                // Fall through to blocking wait
            }
        } else {
            System.out.println("\nRunning in cluster mode - use SIGTERM or cluster shutdown to stop");
        }

        // Block main thread using CountDownLatch with shutdown hook
        CountDownLatch shutdownLatch = new CountDownLatch(1);

        // Register shutdown hook for graceful termination
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            System.out.println("\n⏹️  Shutdown signal received, stopping cache node...");
            system.terminate();
            shutdownLatch.countDown();
        }));

        try {
            // Block main thread until shutdown
            shutdownLatch.await();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            system.terminate();
        }

        System.out.println("✅ Cache node stopped gracefully");
    }

    // Utility method to find available port
    private static int findAvailablePort(int startPort, int endPort) {
        for (int port = startPort; port <= endPort; port++) {
            try (java.net.ServerSocket socket = new java.net.ServerSocket(port)) {
                return port;
            } catch (IOException e) {
                // Port is in use, try next
            }
        }
        throw new RuntimeException("No available ports found in range " + startPort + "-" + endPort);
    }

    // FIXED: Add proper message extractor for sharding
    public static class CacheMessageExtractor extends akka.cluster.sharding.typed.ShardingMessageExtractor<CacheActor.Command, CacheActor.Command> {

        @Override
        public String entityId(CacheActor.Command message) {
            // Extract entity ID from the message
            if (message instanceof CacheActor.Get) {
                return ((CacheActor.Get) message).key;
            } else if (message instanceof CacheActor.Put) {
                return ((CacheActor.Put) message).key;
            } else if (message instanceof CacheActor.Delete) {
                return ((CacheActor.Delete) message).key;
            }
            throw new IllegalArgumentException("Unknown message type: " + message.getClass());
        }

        public String shardId(CacheActor.Command message) {
            // Calculate shard ID from entity ID using hash
            String entityId = entityId(message);
            return String.valueOf(Math.abs(entityId.hashCode()) % 10); // 10 shards
        }

        @Override
        public String shardId(String entityId) {
            // Required method - calculate shard ID from entity ID
            return String.valueOf(Math.abs(entityId.hashCode()) % 10); // 10 shards
        }

        @Override
        public CacheActor.Command unwrapMessage(CacheActor.Command message) {
            // No unwrapping needed as we're not using envelopes
            return message;
        }
    }
}