package net.minecraftforge.event.entity.living;

import net.minecraft.entity.EntityLivingBase;
import net.minecraft.util.DamageSource;

/**
 * Combat compile stub: 2860 LivingHurtEvent carries the hurt entity on
 * the LivingEvent base behind getEntityLiving(), the damage source and
 * amount behind getters, the amount behind a setter (all measured via
 * javap against the pinned 2860 universal — Forge classes are never
 * obfuscated, presence is the pin). The bridge combat hook resolves the
 * struck bone through it; the autoplay combat leg drives it through the
 * genuine attack path, never by post. Never runs.
 */
public class LivingHurtEvent extends LivingEvent {
    public LivingHurtEvent(EntityLivingBase entity, DamageSource source,
            float amount) {
        super(entity);
    }

    public DamageSource getSource() {
        return null;
    }

    public float getAmount() {
        return 0.0f;
    }

    public void setAmount(float amount) {
    }
}
