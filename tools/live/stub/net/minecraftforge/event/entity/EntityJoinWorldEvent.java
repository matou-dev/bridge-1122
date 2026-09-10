package net.minecraftforge.event.entity;

import net.minecraft.entity.Entity;
import net.minecraft.world.World;

/**
 * Spawn compile stub: 2860 EntityJoinWorldEvent carries a private world
 * behind getWorld() (measured via javap against the pinned 2860
 * universal — the 1.7.10 public-field shape does not port; reading
 * fields would die linking at runtime), the entity on the EntityEvent
 * base behind getEntity(). The class is @Cancelable live (measured via
 * javap -v on the same bytes) — the spawn veto in forge/ cancels
 * past-cap joins through it. Never runs.
 */
public class EntityJoinWorldEvent extends EntityEvent {
    private final World world;

    public EntityJoinWorldEvent(Entity entity, World world) {
        super(entity);
        this.world = world;
    }

    public World getWorld() {
        return world;
    }
}
