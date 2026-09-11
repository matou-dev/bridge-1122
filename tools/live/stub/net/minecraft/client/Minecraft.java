package net.minecraft.client;

import net.minecraft.entity.Entity;
import net.minecraft.world.World;
import net.minecraft.world.WorldSettings;

/**
 * Shape-only compile stub for Minecraft 1.12.2 client.
 * Never runs (compile classpath only). The single Minecraft stub — a
 * second one under tools/autoplay/stub would be a duplicate-class
 * error (found by the visual tranche: the companion had not compiled
 * since the item tranche). Two consumers share it: the forge renderer
 * needs world/getRenderViewEntity (first executed by the Prism/XVFB
 * visual run, loud at runtime until then), the dev-only autoplay
 * companion needs launchIntegratedServer/shutdown (pinned by the
 * AUTOPLAY derive in hub tools/run-client.sh — javap exact-descriptor
 * check against the pinned vanilla client jar, SRG names from the
 * pinned joined.tsrg).
 */
public class Minecraft {
    public World world;

    public static Minecraft getMinecraft() {
        return null;
    }

    public Entity getRenderViewEntity() {
        return null;
    }

    public void launchIntegratedServer(String folderName, String worldName, WorldSettings worldSettings) {
    }

    public void shutdown() {
    }
}
