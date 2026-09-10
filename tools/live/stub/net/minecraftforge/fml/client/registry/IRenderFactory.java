package net.minecraftforge.fml.client.registry;

import net.minecraft.client.renderer.entity.Render;
import net.minecraft.client.renderer.entity.RenderManager;
import net.minecraft.entity.Entity;

/**
 * Forge compile stub: shape-only 1.12.2 Forge API used by {@code forge/}
 * sources. Never runs. Serves the beast renderer mapping (the factory
 * path — the only honest one on 2860, see {@code RenderingRegistry}).
 * Generics mirror the runtime (measured by javap on the pinned 2860
 * universal): the erased descriptor is what links, never the MCP names.
 */
public interface IRenderFactory<T extends Entity> {
    Render<? super T> createRenderFor(RenderManager manager);
}
