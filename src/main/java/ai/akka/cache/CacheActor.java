package ai.akka.cache;

import akka.actor.typed.ActorRef;
import akka.actor.typed.Behavior;
import akka.actor.typed.javadsl.AbstractBehavior;
import akka.actor.typed.javadsl.ActorContext;
import akka.actor.typed.javadsl.Behaviors;
import akka.actor.typed.javadsl.Receive;

import java.util.HashMap;
import java.util.Map;

public class CacheActor extends AbstractBehavior<CacheActor.Command> {

    public interface Command {
    }

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

    public interface Response {
    }

    public static final class Found implements Response {
        public final String value;

        public Found(String value) {
            this.value = value;
        }
    }

    public static final class NotFound implements Response {
    }

    public static final class Done implements Response {
    }

    // Factory
    public static Behavior<Command> create() {
        return Behaviors.setup(CacheActor::new);
    }

    // State
    private final Map<String, String> map = new HashMap<>();

    private CacheActor(ActorContext<Command> ctx) {
        super(ctx);
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
        if (map.containsKey(msg.key)) {
            msg.replyTo.tell(new Found(map.get(msg.key)));
        } else {
            msg.replyTo.tell(new NotFound());
        }
        return this;
    }

    private Behavior<Command> onPut(Put msg) {
        map.put(msg.key, msg.value);
        msg.replyTo.tell(new Done());
        return this;
    }

    private Behavior<Command> onDelete(Delete msg) {
        map.remove(msg.key);
        msg.replyTo.tell(new Done());
        return this;
    }
}

