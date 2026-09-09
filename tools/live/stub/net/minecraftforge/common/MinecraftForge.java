package net.minecraftforge.common;

import net.minecraftforge.fml.common.eventhandler.EventBus;

/**
 * C2 compile stub: shape-only Forge 1.12.2-2860 API (universal jar, never
 * obfuscated). Serves the dev-only autoplay companion (tools/autoplay/,
 * never shipped) — the bridge itself registers via FMLCommonHandler. Never
 * runs (compile classpath only). Member {@code EVENT_BUS} is pinned by
 * tools/run-live.sh (C3 step 2c) and tools/autoplay/universal-pin.txt —
 * drift fails loudly. Same practice as bridge-1165.
 */
public class MinecraftForge {
    public static final EventBus EVENT_BUS = null;
}
