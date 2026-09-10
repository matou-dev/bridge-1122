package net.minecraft.entity;

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
    public boolean isDead;

    public void setPositionAndRotation(double x, double y, double z,
            float yaw, float pitch) {
    }

    public int getEntityId() {
        return 0;
    }

    public void setDead() {
    }
}
