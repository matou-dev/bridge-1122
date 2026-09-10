package net.minecraftforge.fml.common.registry;

import net.minecraft.util.ResourceLocation;

/**
 * Forge compile stub: shape-only 1.12.2 Forge API used by {@code forge/}
 * sources. Never runs. {@code registerModEntity} serves the beast preInit
 * and {@code lookupModSpawn} serves the init-time registration tripwire
 * (both presence-pinned against the provisioned 2860 universal by
 * tools/run-live.sh, measured by javap — 1.12 takes the registry name
 * first, never the 1.7.10 call shape) — drift fails loudly.
 */
public class EntityRegistry {
    public static void registerModEntity(ResourceLocation registryName,
            Class entityClass, String name, int id, Object mod,
            int trackingRange, int updateFrequency,
            boolean sendsVelocityUpdates) {
    }

    public static EntityRegistry instance() {
        return null;
    }

    public EntityRegistration lookupModSpawn(Class entityClass,
            boolean ignored) {
        return null;
    }

    public static class EntityRegistration {
    }
}
