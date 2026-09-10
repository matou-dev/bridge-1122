package net.minecraftforge.event.entity.living;

import java.util.List;
import net.minecraft.entity.EntityLivingBase;
import net.minecraft.entity.item.EntityItem;
import net.minecraft.util.DamageSource;

/**
 * Loot compile stub: 2860 LivingDropsEvent ctor is 5-arg (measured via
 * javap against the pinned 2860 universal — the 1.7.10 6-arg shape with
 * specialDropValue does not port). Never runs.
 */
public class LivingDropsEvent extends LivingEvent {
    public LivingDropsEvent(EntityLivingBase entity, DamageSource source,
            List<EntityItem> drops, int lootingLevel,
            boolean recentlyHit) {
        super(entity);
    }
}
