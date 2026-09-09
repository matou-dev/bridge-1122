package net.minecraft.client;

import net.minecraft.world.WorldSettings;

/**
 * Autoplay compile stub: shape-only 1.12.2 client surface used by the
 * dev-only companion (tools/autoplay/, never shipped, never runs here).
 * Every member below is pinned by the AUTOPLAY derive in hub
 * tools/run-client.sh (javap exact-descriptor check against the pinned
 * vanilla client jar, SRG names from the pinned joined.tsrg) — drift
 * fails loudly, never silently. Same practice as bridge-1165.
 */
public class Minecraft {
    public static Minecraft getMinecraft() {
        return null;
    }

    public void launchIntegratedServer(String folderName, String worldName, WorldSettings worldSettings) {
    }

    public void shutdown() {
    }
}
