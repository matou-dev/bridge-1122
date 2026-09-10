package net.minecraft.entity;

import net.minecraft.world.World;

/**
 * Loot compile stub: declaring type of world/pos on 2860 (forge reads
 * inherited vanilla members through this type — hub decisions/LOOT.md
 * owner discipline). The loot companion positions and cleans its pig
 * through this same declaring type. Never runs (compile classpath only).
 */
public class Entity {
    public World world;
    public double posX;
    public double posY;
    public double posZ;

    public void setPositionAndRotation(double x, double y, double z,
            float yaw, float pitch) {
    }

    public void setDead() {
    }
}
