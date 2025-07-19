package ai.akka.cache;

import akka.actor.typed.ActorSystem;
import akka.cluster.sharding.typed.javadsl.ClusterSharding;
import akka.cluster.sharding.typed.javadsl.EntityRef;
import akka.http.javadsl.marshallers.jackson.Jackson;
import akka.http.javadsl.model.ContentTypes;
import akka.http.javadsl.model.HttpEntities;
import akka.http.javadsl.model.StatusCodes;
import akka.http.javadsl.server.AllDirectives;
import akka.http.javadsl.server.Route;
import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.time.Duration;
import java.util.concurrent.CompletionStage;

import static akka.http.javadsl.server.PathMatchers.segment;

public class CacheRoutes extends AllDirectives {
    private final ClusterSharding sharding;
    private final ActorSystem<?> system;

    // FIXED: Use ClusterSharding directly instead of proxy
    public CacheRoutes(ClusterSharding sharding, ActorSystem<?> system) {
        this.sharding = sharding;
        this.system = system;
    }

    private static final Duration duration = Duration.ofSeconds(5);

    // JSON request class for PUT operations
    public static class CacheValue {
        private final String value;

        @JsonCreator
        public CacheValue(@JsonProperty("value") String value) {
            this.value = value;
        }

        public String getValue() {
            return value;
        }
    }

    // JSON response class for GET operations
    public static class CacheResponse {
        private final String value;

        public CacheResponse(String value) {
            this.value = value;
        }

        public String getValue() {
            return value;
        }
    }

    public Route routes() {
        return concat(
                // Root health check endpoint
                pathSingleSlash(() ->
                        get(() -> complete("Akka Distributed Cache - Node Online ✅"))
                ),

                // Basic cache operations - /cache/{key}
                pathPrefix("cache", () ->
                        path(segment(), (String key) -> concat(
                                get(() -> {
                                    // FIXED: Get EntityRef directly and use ask
                                    EntityRef<CacheActor.Command> entityRef = sharding.entityRefFor(
                                            DistributedCacheApplication.CACHE_ENTITY_KEY, key);

                                    CompletionStage<CacheActor.Response> future = entityRef.ask(
                                            replyTo -> new CacheActor.Get(key, replyTo),
                                            duration);

                                    return onSuccess(future, res -> {
                                        if (res instanceof CacheActor.Found) {
                                            CacheActor.Found found = (CacheActor.Found) res;
                                            // Return JSON response as required
                                            return complete(StatusCodes.OK,
                                                    new CacheResponse(found.value), Jackson.marshaller());
                                        } else {
                                            return complete(StatusCodes.NOT_FOUND, "Key not found");
                                        }
                                    });
                                }),
                                put(() ->
                                        // Accept JSON body with "value" field as required by assignment
                                        entity(Jackson.unmarshaller(CacheValue.class), cacheValue -> {
                                            // FIXED: Get EntityRef directly and use ask
                                            EntityRef<CacheActor.Command> entityRef = sharding.entityRefFor(
                                                    DistributedCacheApplication.CACHE_ENTITY_KEY, key);

                                            CompletionStage<CacheActor.Response> future = entityRef.ask(
                                                    replyTo -> new CacheActor.Put(key, cacheValue.getValue(), replyTo),
                                                    duration);

                                            return onSuccess(future, res ->
                                                    complete(StatusCodes.OK, "Put successful"));
                                        })
                                ),
                                delete(() -> {
                                    // FIXED: Get EntityRef directly and use ask
                                    EntityRef<CacheActor.Command> entityRef = sharding.entityRefFor(
                                            DistributedCacheApplication.CACHE_ENTITY_KEY, key);

                                    CompletionStage<CacheActor.Response> future = entityRef.ask(
                                            replyTo -> new CacheActor.Delete(key, replyTo),
                                            duration);

                                    return onSuccess(future, res ->
                                            complete(StatusCodes.OK, "Delete successful"));
                                })
                        ))
                ),

                // Admin endpoints - /admin/*
                pathPrefix("admin", () -> concat(
                        // Status endpoint - /admin/status
                        path("status", () ->
                                get(() -> {
                                    String status = String.format(
                                            "=== Cache Node Status ===\n" +
                                                    "Node: %s\n" +
                                                    "Status: HEALTHY ✅\n" +
                                                    "Type: Akka Cluster Cache\n" +
                                                    "Timestamp: %s\n" +
                                                    "Sharding: Cluster Sharding Enabled\n" +
                                                    "HTTP Endpoints:\n" +
                                                    "  PUT /cache/{key} - Store value (JSON: {\"value\":\"data\"})\n" +
                                                    "  GET /cache/{key} - Retrieve value (returns JSON)\n" +
                                                    "  DELETE /cache/{key} - Remove value\n" +
                                                    "  GET /admin/status - This status page\n" +
                                                    "  GET /admin/health - Simple health check\n",
                                            system.name(),
                                            java.time.Instant.now()
                                    );
                                    return complete(HttpEntities.create(ContentTypes.TEXT_PLAIN_UTF8, status));
                                })
                        ),

                        // Simple health check - /admin/health
                        path("health", () ->
                                get(() -> complete("OK"))
                        ),

                        // Admin root - /admin
                        pathEndOrSingleSlash(() ->
                                get(() -> complete("Admin Interface - Available endpoints: /admin/status, /admin/health"))
                        )
                )),

                // API documentation endpoint - /api
                path("api", () ->
                        get(() -> {
                            String apiDocs =
                                    "=== Akka Distributed Cache API ===\n\n" +
                                            "Cache Operations (JSON Format):\n" +
                                            "  PUT /cache/{key}    - Store a value with JSON body\n" +
                                            "  GET /cache/{key}    - Retrieve a value (returns JSON)\n" +
                                            "  DELETE /cache/{key} - Remove a value\n\n" +
                                            "Admin Operations:\n" +
                                            "  GET /admin/status   - Detailed node status\n" +
                                            "  GET /admin/health   - Simple health check\n" +
                                            "  GET /              - Root health check\n" +
                                            "  GET /api           - This API documentation\n\n" +
                                            "Examples (JSON Format):\n" +
                                            "  curl -X PUT http://localhost:8080/cache/mykey \\\n" +
                                            "       -H 'Content-Type: application/json' \\\n" +
                                            "       -d '{\"value\":\"myvalue\"}'\n" +
                                            "  curl http://localhost:8080/cache/mykey\n" +
                                            "  curl -X DELETE http://localhost:8080/cache/mykey\n" +
                                            "  curl http://localhost:8080/admin/status\n";
                            return complete(HttpEntities.create(ContentTypes.TEXT_PLAIN_UTF8, apiDocs));
                        })
                )
        );
    }
}