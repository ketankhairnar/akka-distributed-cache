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

public class DistributedCacheApplication {
    public static void main(String[] args) throws IOException {
        // Default port values
        int akkaPort = args.length > 0 ? Integer.parseInt(args[0]) : 2551;
        int httpPort = args.length > 1 ? Integer.parseInt(args[1]) : 8080;

        // HOCON config with dynamic akka.remote.artery.canonical.port
        Config config = ConfigFactory.parseString(
                "akka.remote.artery.canonical.port=" + akkaPort + "\n"
        ).withFallback(ConfigFactory.load());

        // Actor System startup - use Void for guardian actor
        ActorSystem<Void> system = ActorSystem.create(
                akka.actor.typed.javadsl.Behaviors.setup(context -> {
                    // Spawn the cache actor as a child
                    ActorRef<CacheActor.Command> cacheActor =
                            context.spawn(CacheActor.create(), "cache-actor");

                    // Setup HTTP routes
                    CacheRoutes routes = new CacheRoutes(cacheActor, context.getSystem());
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

        // Wait so JVM doesn't exit
        System.out.println("\n🚀 Cache node started successfully!");
        System.out.println("📝 Test commands:");
        System.out.printf("   curl -X PUT http://localhost:%d/cache/test -d 'test-value'%n", httpPort);
        System.out.printf("   curl http://localhost:%d/cache/test%n", httpPort);
        System.out.printf("   curl http://localhost:%d/admin/status%n", httpPort);
        System.out.println("\nPress RETURN to stop...");

        System.in.read();
        system.terminate();
    }
}