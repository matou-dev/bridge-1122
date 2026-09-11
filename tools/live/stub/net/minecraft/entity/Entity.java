package net.minecraft.entity;

import net.minecraft.nbt.NBTTagCompound;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.World;

/**
 * Loot compile stub: declaring type of world/pos on 2860 (forge reads
 * inherited vanilla members through this type — hub decisions/LOOT.md
 * owner discipline). The loot companion positions and cleans its pig
 * through this same declaring type. The spawn census in forge/ records
 * landings under getEntityId and the companion counts the living only
 * through isDead (hub decisions/SPAWN.md — dead beasts linger in the
 * loaded list). Never runs (compile classpath only).
 */
public class Entity {
    public World world;
    public double posX;
    public double posY;
    public double posZ;
    public double lastTickPosX;
    public double lastTickPosY;
    public double lastTickPosZ;
    public float rotationYaw;
    public float rotationPitch;
    public boolean isDead;

    public void setPositionAndRotation(double x, double y, double z,
            float yaw, float pitch) {
    }

    public int getEntityId() {
        return 0;
    }

    public void setDead() {
    }

    /**
     * Combat compile stub: 2860 {@code Entity} declares the attacker
     * eye/look surface the bridge combat hook reads through this
     * declaring type (owner discipline, hub decisions/LOOT.md) —
     * {@code getLookVec} is {@code func_70040_Z ()->Vec3d} and
     * {@code getEyeHeight} is {@code func_70047_e ()F}, both measured
     * via javap against the pinned notch server jar (obf owners
     * {@code vg/aJ} and {@code vg/by}). Never runs.
     */
    public Vec3d getLookVec() {
        return null;
    }

    public float getEyeHeight() {
        return 0.0f;
    }

    /**
     * Persist surface (unused by the bridge beast — it overrides the
     * Pig-declared helpers writeEntityToNBT/readEntityFromNBT instead,
     * see the EntityPig stub; the public writeToNBT is func_189511_e,
     * readFromNBT is func_70020_e, never the protected abstract
     * helpers func_70014_b/func_70037_a). Kept for hierarchy shape,
     * never called. Never runs.
     */
    public NBTTagCompound writeToNBT(NBTTagCompound compound) {
        return null;
    }

    public void readFromNBT(NBTTagCompound compound) {
    }
}
