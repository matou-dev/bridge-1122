package net.minecraftforge.client.event;

import net.minecraftforge.fml.common.eventhandler.Event;

/**
 * Shape-only compile stub for Forge 1.12.2 RenderWorldLastEvent.
 * Never runs (compile classpath only).
 */
public class RenderWorldLastEvent extends Event {
    private float partialTicks;

    public RenderWorldLastEvent(float partialTicks) {
        this.partialTicks = partialTicks;
    }

    public float getPartialTicks() {
        return partialTicks;
    }
}
