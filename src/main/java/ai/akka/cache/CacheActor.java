package ai.akka.cache;

import akka.actor.typed.ActorRef;
import akka.actor.typed.Behavior;
import akka.actor.typed.javadsl.AbstractBehavior;
import akka.actor.typed.javadsl.ActorContext;
import akka.actor.typed.javadsl.Behaviors;
import akka.actor.typed.javadsl.Receive;
import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.io.Serializable;
import java.util.HashMap;
import java.util.Map;

public class CacheActor extends AbstractBehavior<CacheActor.Command> {

    // FIXED: Command interface with proper serialization support
    public interface Command extends Serializable {
    }

    public static final class Get implements Command {
        public final String key;
        public final ActorRef<Response> replyTo;

        @JsonCreator
        public Get(@JsonProperty("key") String key, @JsonProperty("replyTo") ActorRef<Response> replyTo) {
            this.key = key;
            this.replyTo = replyTo;
        }

        @Override
        public String toString() {
            return "Get{" + "key='" + key + '\'' + '}';
        }
    }

    public static final class Put implements Command {
        public final String key;
        public final String value;
        public final ActorRef<Response> replyTo;

        @JsonCreator
        public Put(@JsonProperty("key") String key, @JsonProperty("value") String value, @JsonProperty("replyTo") ActorRef<Response> replyTo) {
            this.key = key;
            this.value = value;
            this.replyTo = replyTo;
        }

        @Override
        public String toString() {
            return "Put{" + "key='" + key + '\'' + ", value='" + value + '\'' + '}';
        }
    }

    public static final class Delete implements Command {
        public final String key;
        public final ActorRef<Response> replyTo;

        @JsonCreator
        public Delete(@JsonProperty("key") String key, @JsonProperty("replyTo") ActorRef<Response> replyTo) {
            this.key = key;
            this.replyTo = replyTo;
        }

        @Override
        public String toString() {
            return "Delete{" + "key='" + key + '\'' + '}';
        }
    }

    // FIXED: Response interface with proper serialization support
    public interface Response extends Serializable {
    }

    public static final class Found implements Response {
        public final String value;

        @JsonCreator
        public Found(@JsonProperty("value") String value) {
            this.value = value;
        }

        @Override
        public String toString() {
            return "Found{" + "value='" + value + '\'' + '}';
        }
    }

    public static final class NotFound implements Response {
        @JsonCreator
        public NotFound() {
        }

        @Override
        public String toString() {
            return "NotFound{}";
        }
    }

    public static final class Done implements Response {
        @JsonCreator
        public Done() {
        }

        @Override
        public String toString() {
            return "Done{}";
        }
    }

    // Factory - FIXED: Accept EntityContext for proper sharding
    public static Behavior<Command> create() {
        return Behaviors.setup(CacheActor::new);
    }

    // Alternative factory for entity context (better for sharding)
    public static Behavior<Command> create(akka.cluster.sharding.typed.javadsl.EntityContext<Command> entityContext) {
        return Behaviors.setup(ctx -> new CacheActor(ctx, entityContext.getEntityId()));
    }

    // State - FIXED: This actor now stores value for a single key (entity ID)
    private final String entityId;
    private String value; // Single value storage per entity
    private final Map<String, String> fallbackMap = new HashMap<>(); // Fallback for compatibility

    private CacheActor(ActorContext<Command> ctx) {
        super(ctx);
        this.entityId = "unknown"; // Fallback
        getContext().getLog().info("CacheActor started for entity: {}", entityId);
    }

    private CacheActor(ActorContext<Command> ctx, String entityId) {
        super(ctx);
        this.entityId = entityId;
        getContext().getLog().info("CacheActor started for entity: {}", entityId);
    }

    @Override
    public Receive<Command> createReceive() {
        return newReceiveBuilder()
                .onMessage(Get.class, this::onGet)
                .onMessage(Put.class, this::onPut)
                .onMessage(Delete.class, this::onDelete)
                .build();
    }

    private Behavior<Command> onGet(Get msg) {
        getContext().getLog().debug("GET operation for key: {} (entity: {})", msg.key, entityId);

        // FIXED: Check if this entity is responsible for this key
        if (msg.key.equals(entityId)) {
            // This entity stores this key's value
            if (value != null) {
                getContext().getLog().debug("Found value for key '{}': {}", msg.key, value);
                msg.replyTo.tell(new Found(value));
            } else {
                getContext().getLog().debug("Key '{}' not found in entity {}", msg.key, entityId);
                msg.replyTo.tell(new NotFound());
            }
        } else {
            // Fallback: check in map for compatibility
            if (fallbackMap.containsKey(msg.key)) {
                String mapValue = fallbackMap.get(msg.key);
                getContext().getLog().debug("Found value for key '{}' in fallback map: {}", msg.key, mapValue);
                msg.replyTo.tell(new Found(mapValue));
            } else {
                getContext().getLog().debug("Key '{}' not found in entity {} or fallback map", msg.key, entityId);
                msg.replyTo.tell(new NotFound());
            }
        }
        return this;
    }

    private Behavior<Command> onPut(Put msg) {
        getContext().getLog().debug("PUT operation for key: {} -> {} (entity: {})", msg.key, msg.value, entityId);

        // FIXED: Check if this entity is responsible for this key
        if (msg.key.equals(entityId)) {
            // This entity stores this key's value directly
            this.value = msg.value;
            getContext().getLog().info("Stored key '{}' with value '{}' in entity {}",
                    msg.key, msg.value, entityId);
        } else {
            // Fallback: store in map for compatibility
            fallbackMap.put(msg.key, msg.value);
            getContext().getLog().info("Stored key '{}' with value '{}' in fallback map of entity {}",
                    msg.key, msg.value, entityId);
        }

        msg.replyTo.tell(new Done());
        return this;
    }

    private Behavior<Command> onDelete(Delete msg) {
        getContext().getLog().debug("DELETE operation for key: {} (entity: {})", msg.key, entityId);

        String removedValue = null;

        // FIXED: Check if this entity is responsible for this key
        if (msg.key.equals(entityId)) {
            // This entity stores this key's value directly
            removedValue = this.value;
            this.value = null;
            if (removedValue != null) {
                getContext().getLog().info("Deleted key '{}' (was: '{}') from entity {}",
                        msg.key, removedValue, entityId);
            }
        } else {
            // Fallback: remove from map for compatibility
            removedValue = fallbackMap.remove(msg.key);
            if (removedValue != null) {
                getContext().getLog().info("Deleted key '{}' (was: '{}') from fallback map of entity {}",
                        msg.key, removedValue, entityId);
            }
        }

        if (removedValue == null) {
            getContext().getLog().debug("Attempted to delete non-existent key: {} from entity {}", msg.key, entityId);
        }

        msg.replyTo.tell(new Done());
        return this;
    }
}