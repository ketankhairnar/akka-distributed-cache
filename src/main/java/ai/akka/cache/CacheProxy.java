package ai.akka.cache;

import akka.actor.typed.ActorRef;
import akka.actor.typed.Behavior;
import akka.actor.typed.javadsl.AbstractBehavior;
import akka.actor.typed.javadsl.ActorContext;
import akka.actor.typed.javadsl.Behaviors;
import akka.actor.typed.javadsl.Receive;
import akka.cluster.sharding.typed.javadsl.ClusterSharding;
import akka.cluster.sharding.typed.javadsl.EntityRef;

/**
 * Proxy actor that forwards cache operations to the appropriate sharded entity
 * based on the key. This allows the HTTP layer to work with a single actor
 * reference while the actual cache operations are distributed across shards.
 */
public class CacheProxy extends AbstractBehavior<CacheActor.Command> {

    private final ClusterSharding sharding;

    public static Behavior<CacheActor.Command> create(ClusterSharding sharding) {
        return Behaviors.setup(context -> new CacheProxy(context, sharding));
    }

    private CacheProxy(ActorContext<CacheActor.Command> context, ClusterSharding sharding) {
        super(context);
        this.sharding = sharding;
        getContext().getLog().info("CacheProxy started - forwarding to sharded entities");
    }

    @Override
    public Receive<CacheActor.Command> createReceive() {
        return newReceiveBuilder()
                .onMessage(CacheActor.Get.class, this::onGet)
                .onMessage(CacheActor.Put.class, this::onPut)
                .onMessage(CacheActor.Delete.class, this::onDelete)
                .build();
    }

    private Behavior<CacheActor.Command> onGet(CacheActor.Get msg) {
        // FIXED: Use the key as entity ID, not shard ID
        EntityRef<CacheActor.Command> entityRef = sharding.entityRefFor(
                DistributedCacheApplication.CACHE_ENTITY_KEY,
                msg.key  // Use key as entity ID directly
        );

        getContext().getLog().debug("Forwarding GET for key '{}' to entity '{}'",
                msg.key, msg.key);

        entityRef.tell(msg);
        return this;
    }

    private Behavior<CacheActor.Command> onPut(CacheActor.Put msg) {
        // FIXED: Use the key as entity ID, not shard ID
        EntityRef<CacheActor.Command> entityRef = sharding.entityRefFor(
                DistributedCacheApplication.CACHE_ENTITY_KEY,
                msg.key  // Use key as entity ID directly
        );

        getContext().getLog().debug("Forwarding PUT for key '{}' to entity '{}'",
                msg.key, msg.key);

        entityRef.tell(msg);
        return this;
    }

    private Behavior<CacheActor.Command> onDelete(CacheActor.Delete msg) {
        // FIXED: Use the key as entity ID, not shard ID
        EntityRef<CacheActor.Command> entityRef = sharding.entityRefFor(
                DistributedCacheApplication.CACHE_ENTITY_KEY,
                msg.key  // Use key as entity ID directly
        );

        getContext().getLog().debug("Forwarding DELETE for key '{}' to entity '{}'",
                msg.key, msg.key);

        entityRef.tell(msg);
        return this;
    }
}