package net.minecraftforge.event.entity.living;

import net.minecraft.entity.EntityLivingBase;
import net.minecraftforge.fml.common.eventhandler.Event;

/**
 * Loot compile stub: 2860 LivingEvent exposes the killed entity through
 * getEntityLiving() (no public field). Never runs.
 */
public class LivingEvent extends Event {
    public LivingEvent(EntityLivingBase entity) {
    }

    public EntityLivingBase getEntityLiving() {
        return null;
    }
}
