package net.minecraft.client.renderer.entity;

import net.minecraft.entity.passive.EntityPig;

/**
 * Vanilla compile stub: shape-only 1.12.2 client class used by
 * {@code forge/} sources. Never runs. Single {@code (RenderManager)}
 * ctor, measured (notch {@code cak(bzf)} from the pinned client jar —
 * the 1.7.10 3-arg saddle ctor does not exist on 2860, the saddle is a
 * layer): the beast renderer mapping rides the factory path, never a
 * recalled ctor.
 */
public class RenderPig extends RenderLiving<EntityPig> {
    public RenderPig(RenderManager manager) {
        super(manager);
    }
}
