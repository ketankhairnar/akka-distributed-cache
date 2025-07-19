package ai.akka.cache;

import akka.actor.typed.ActorRef;
import akka.actor.typed.ActorSystem;
import akka.actor.typed.javadsl.AskPattern;
import akka.http.javadsl.model.ContentTypes;
import akka.http.javadsl.model.HttpEntities;
import akka.http.javadsl.model.StatusCodes;
import akka.http.javadsl.server.AllDirectives;
import akka.http.javadsl.server.Route;

import java.time.Duration;
import java.util.concurrent.CompletionStage;

import static akka.http.javadsl.server.PathMatchers.segment;
import static akka.http.javadsl.unmarshalling.Unmarshaller.entityToString;

public class CacheRoutes extends AllDirectives {
    private final ActorRef<CacheActor.Command> cacheActor;
    private final ActorSystem<?> system;

    public CacheRoutes(ActorRef<CacheActor.Command> cacheActor, ActorSystem<?> system) {
        this.cacheActor = cacheActor;
        this.system = system;
    }

    private static final Duration duration = Duration.ofSeconds(5);

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
                                    CompletionStage<CacheActor.Response> future =
                                            AskPattern.<CacheActor.Command, CacheActor.Response>ask(
                                                    cacheActor,
                                                    replyTo -> new CacheActor.Get(key, replyTo),
                                                    duration,
                                                    system.scheduler()
                                            );
                                    return onSuccess(future, res -> {
                                        if (res instanceof CacheActor.Found) {
                                            CacheActor.Found found = (CacheActor.Found) res;
                                            return complete(StatusCodes.OK,
                                                    HttpEntities.create(ContentTypes.TEXT_PLAIN_UTF8, found.value));
                                        } else {
                                            return complete(StatusCodes.NOT_FOUND, "Key not found");
                                        }
                                    });
                                }),
                                put(() ->
                                        // Accept raw string value
                                        entity(entityToString(), value -> {
                                            CompletionStage<CacheActor.Response> future =
                                                    AskPattern.<CacheActor.Command, CacheActor.Response>ask(
                                                            cacheActor,
                                                            replyTo -> new CacheActor.Put(key, value.trim(), replyTo),
                                                            duration,
                                                            system.scheduler()
                                                    );
                                            return onSuccess(future, res ->
                                                    complete(StatusCodes.OK, "Put successful"));
                                        })
                                ),
                                delete(() -> {
                                    CompletionStage<CacheActor.Response> future =
                                            AskPattern.<CacheActor.Command, CacheActor.Response>ask(
                                                    cacheActor,
                                                    replyTo -> new CacheActor.Delete(key, replyTo),
                                                    duration,
                                                    system.scheduler()
                                            );
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
                                                    "Cache Actor: %s\n" +
                                                    "HTTP Endpoints:\n" +
                                                    "  PUT /cache/{key} - Store value\n" +
                                                    "  GET /cache/{key} - Retrieve value\n" +
                                                    "  DELETE /cache/{key} - Remove value\n" +
                                                    "  GET /admin/status - This status page\n" +
                                                    "  GET /admin/health - Simple health check\n",
                                            system.name(),
                                            java.time.Instant.now(),
                                            cacheActor.path()
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
                                            "Cache Operations:\n" +
                                            "  PUT /cache/{key}    - Store a value (send data as request body)\n" +
                                            "  GET /cache/{key}    - Retrieve a value\n" +
                                            "  DELETE /cache/{key} - Remove a value\n\n" +
                                            "Admin Operations:\n" +
                                            "  GET /admin/status   - Detailed node status\n" +
                                            "  GET /admin/health   - Simple health check\n" +
                                            "  GET /              - Root health check\n" +
                                            "  GET /api           - This API documentation\n\n" +
                                            "Examples:\n" +
                                            "  curl -X PUT http://localhost:8080/cache/mykey -d 'myvalue'\n" +
                                            "  curl http://localhost:8080/cache/mykey\n" +
                                            "  curl http://localhost:8080/admin/status\n";
                            return complete(HttpEntities.create(ContentTypes.TEXT_PLAIN_UTF8, apiDocs));
                        })
                )
        );
    }
}