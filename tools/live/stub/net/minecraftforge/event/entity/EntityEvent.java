package net.minecraftforge.event.entity;

import net.minecraft.entity.Entity;
import net.minecraftforge.fml.common.eventhandler.Event;

/**
 * Spawn compile stub: 2860 EntityEvent exposes the entity through
 * getEntity() (measured via javap against the pinned 2860 universal —
 * private final notch field, no public field). Base of the join event
 * the spawn veto reads in forge/ plus the living events the loot hook
 * already reads. Never runs.
 */
public class EntityEvent extends Event {
    private final Entity entity;

    public EntityEvent(Entity entity) {
        this.entity = entity;
    }

    public Entity getEntity() {
        return entity;
    }
}
