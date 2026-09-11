package net.minecraft.entity;

import net.minecraft.entity.ai.attributes.IAttribute;
import net.minecraft.entity.ai.attributes.IAttributeInstance;

/**
 * Loot compile stub: return type of
 * LivingEvent.getEntityLiving() on 2860. The spawn hp seam (hub
 * decisions/SPAWN.md hp tranche) lands the content hp through
 * getEntityAttribute / setBaseValue plus setHealth, and reads it back
 * with getMaxHealth — inherited vanilla members are always called
 * through this declaring stub type in forge/ and the companion alike
 * (owner discipline, hub decisions/LOOT.md). Never runs.
 */
public class EntityLivingBase extends Entity {
    public IAttributeInstance getEntityAttribute(
            IAttribute attribute) {
        return null;
    }

    public float getMaxHealth() {
        return 0.0f;
    }

    /**
     * Combat-companion compile stub: the autoplay combat leg polls the
     * struck beast health through this declaring type (owner discipline,
     * hub decisions/LOOT.md) — {@code getHealth} is
     * {@code func_110143_aJ ()F}, measured via javap against the pinned
     * notch server jar (the same-descriptor {@code func_110138_aP}
     * max-health sibling is NOT this, hence the SRG anchor). Never runs.
     */
    public float getHealth() {
        return 0.0f;
    }

    public void setHealth(float health) {
    }
}
