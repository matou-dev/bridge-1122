package net.minecraftforge.fml.client.registry;

import net.minecraft.entity.Entity;

/**
 * Forge compile stub: shape-only 1.12.2 Forge API used by {@code forge/}
 * sources. Never runs. Presence-pinned against the provisioned 2860
 * universal by tools/run-live.sh (measured by javap: the legacy
 * {@code (Class, Render)} overload still exists, but only the generic
 * factory path is wired here — its load path is the proven one).
 */
public class RenderingRegistry {
    public static <T extends Entity> void registerEntityRenderingHandler(
            Class<T> entityClass, IRenderFactory<? super T> renderFactory) {
    }
}
