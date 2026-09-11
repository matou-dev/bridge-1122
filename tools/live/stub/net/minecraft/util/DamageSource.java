package net.minecraft.util;

import net.minecraft.entity.Entity;

/**
 * Loot-companion compile stub: damage-source type of the LivingDropsEvent
 * ctor (the companion passes null — the bridge kill hook never reads it).
 * Combat tranche: the bridge combat hook resolves the attacker through
 * {@code getTrueSource} ({@code func_76346_g ()->Entity} on obf
 * {@code ur/j}, measured via javap against the pinned notch server jar —
 * the same-descriptor {@code func_76364_f} sibling is NOT the true
 * source, hence the SRG anchor in the narrow map). Never runs.
 */
public class DamageSource {
    public Entity getTrueSource() {
        return null;
    }
}
