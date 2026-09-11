package net.minecraft.entity.passive;

import net.minecraft.entity.EntityLivingBase;
import net.minecraft.nbt.NBTTagCompound;
import net.minecraft.world.World;

/**
 * Loot-companion compile stub: the T1 any-kill-pays victim (a vanilla pig
 * — the species narrows when custom-entity registration lands, hub
 * decisions/LOOT.md). Hierarchy flattened to EntityLivingBase (the only
 * supertype the companion needs: LivingDropsEvent takes EntityLivingBase,
 * coords go through Entity). Never runs.
 */
public class EntityPig extends EntityLivingBase {
    public EntityPig(World world) {
    }

    /**
     * Spawn-identity compile stub: 2860 {@code EntityPig} declares the
     * concrete persist helpers the bridge beast extends with its short
     * mob name ({@code writeEntityToNBT} is {@code func_70014_b},
     * {@code readEntityFromNBT} is {@code func_70037_a}, both measured
     * via javap + joined.tsrg against the pinned bytes — the public
     * writeToNBT/readFromNBT live one level up on {@code Entity} and
     * their super calls would emit an unmappable intermediate owner,
     * hub decisions/VIRTUAL_HITBOXES.md second-beast row). Never runs.
     */
    protected void writeEntityToNBT(NBTTagCompound compound) {
    }

    protected void readEntityFromNBT(NBTTagCompound compound) {
    }
}
