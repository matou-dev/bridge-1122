package fr.iamacat.autoplay;

import net.minecraft.client.Minecraft;
import net.minecraftforge.common.MinecraftForge;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.common.eventhandler.SubscribeEvent;
import net.minecraftforge.fml.common.gameevent.TickEvent;

/**
 * Autoplay companion (DEV ONLY, never ships): drives the scripted client
 * proof without a human at the keyboard. On the first client tick it joins
 * the pre-seeded flat world (run-client.sh preseeds saves/&lt;world&gt;,
 * refusing loudly when absent), then counts loaded ticks near spawn and
 * shuts the game down cleanly. World == pure union is judged afterwards
 * by hub tools/verify-client-save.sh — this mod never places a block, so
 * any foreign block fails loudly there, never here silently.
 *
 * <p>1.12.2 shape (measured, not assumed): the client joins by folder name
 * through {@code launchIntegratedServer(folder, name, null)} — null
 * settings are safe because the pre-seeded level.dat already exists (the
 * integrated server only consults settings when creating a fresh world,
 * same call the Singleplayer screen makes).
 *
 * <p>Stop clock: SERVER ticks, not client ticks. The bridge applies on the
 * server thread, and on one JVM the client can out-tick a loaded server
 * (or burn client ticks on the loading screen while no server tick has
 * run yet) — stopping on client ticks under-counts the addressed union
 * (measured: 967/1274 on the first 1122 run). WAIT_SERVER_TICKS overshoots
 * the 4000-tick union on purpose (slow start re-lands the same
 * deterministic cells — the union is a fixed point, same practice as the
 * 1165 WAIT_TICKS). The server handler only counts; the client handler
 * owns the shutdown call (same thread as the proven 1165 quit path), so
 * the counter crossing threads is volatile — explicitly, never by luck.
 * World name follows AUTOPLAY_WORLD (default matou), matching verify.
 */
@Mod(modid = AutoplayMod.MODID, name = "MatouAutoplay", version = "0.0-dev",
        acceptableRemoteVersions = "*")
public class AutoplayMod {
    public static final String MODID = "matouautoplay";
    static final int WAIT_SERVER_TICKS = 4600;
    static final String WORLD = System.getenv().getOrDefault("AUTOPLAY_WORLD", "matou");

    volatile int serverTicks = 0;
    boolean joined = false;
    boolean done = false;

    public AutoplayMod() {
        MinecraftForge.EVENT_BUS.register(this);
    }

    @SubscribeEvent
    public void onServerTick(TickEvent.ServerTickEvent event) {
        if (event.phase != TickEvent.Phase.END) {
            return;
        }
        serverTicks++;
    }

    @SubscribeEvent
    public void onClientTick(TickEvent.ClientTickEvent event) {
        if (event.phase != TickEvent.Phase.END) {
            return;
        }
        Minecraft mc = Minecraft.getMinecraft();
        if (!joined) {
            joined = true;
            mc.launchIntegratedServer(WORLD, WORLD, null);
            return;
        }
        if (serverTicks >= WAIT_SERVER_TICKS && !done) {
            done = true;
            mc.shutdown();
        }
    }
}
