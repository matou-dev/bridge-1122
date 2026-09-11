package net.minecraft.client.multiplayer;

import net.minecraft.world.World;

/**
 * Shape-only compile stub for the 1.12.2 integrated-client world.
 * Never runs (compile classpath only). Exists so the merged Minecraft
 * stub can declare the true world type: field_71438_f is WorldClient,
 * not World (field_71439_g is the player — measured via javap on the
 * pinned client bytes, never recalled). The renderer reads
 * loadedEntityList through this subclass (inherited from World);
 * Reobf.walk remaps it via the World row, like every inherited ref.
 */
public class WorldClient extends World {
}
