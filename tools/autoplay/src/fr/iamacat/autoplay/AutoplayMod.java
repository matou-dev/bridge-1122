package fr.iamacat.autoplay;

import java.util.ArrayList;
import net.minecraft.block.Block;
import net.minecraft.block.state.IBlockState;
import net.minecraft.client.Minecraft;
import net.minecraft.entity.Entity;
import net.minecraft.entity.item.EntityItem;
import net.minecraft.entity.passive.EntityPig;
import net.minecraft.entity.player.EntityPlayer;
import net.minecraft.init.Items;
import net.minecraft.item.ItemStack;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.World;
import net.minecraftforge.common.MinecraftForge;
import net.minecraftforge.event.entity.living.LivingDropsEvent;
import net.minecraftforge.event.world.BlockEvent;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.common.eventhandler.SubscribeEvent;
import net.minecraftforge.fml.common.gameevent.TickEvent;
import net.minecraftforge.fml.relauncher.Side;

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
 *
 * <p>Loot proof (LOOT=1, DEV ONLY): at LOOT_HARVEST_TICK server-world
 * ticks the companion harvests the registered ore at an isolated coords
 * outside the union slices (8,10,8 — place + clear + an 8-arg
 * {@code HarvestDropsEvent} post authored by the joined player, spike
 * honesty standard) and, five ticks later, kills a spawned vanilla pig
 * at (12,10,8) with a simulated 5-arg {@code LivingDropsEvent} post
 * (T1 any-kill-pays — hub decisions/LOOT.md; the species narrows when
 * custom-entity registration lands) — then polls both spots for the
 * diamond carrier the bridge loot sink spawns per due drop. The posts
 * are simulated, honestly: place + clear + bus posts exercise the
 * shipped hooks ({@code onHarvest} reads world/dim/block only through
 * the 2860 getters; {@code onKill} reads the entity only) through the
 * live seal ({@code LootSeal}), the pure {@code LootJob} and the live
 * sink — that seam is what loot owns. What is NOT re-proven is vanilla
 * firing the events on a genuine harvest/kill (Forge-owned, shape-pinned
 * in universal-pin.txt). A carrier observed late, or never, fails loudly
 * (loot FAILED) and shuts the game down for post-mortem. Without LOOT=1
 * nothing here runs and the proof is byte-for-byte the proven union run.
 */
@Mod(modid = AutoplayMod.MODID, name = "MatouAutoplay", version = "0.0-dev",
        acceptableRemoteVersions = "*")
public class AutoplayMod {
    public static final String MODID = "matouautoplay";
    static final int WAIT_SERVER_TICKS = 4600;
    static final String WORLD = System.getenv().getOrDefault("AUTOPLAY_WORLD", "matou");
    static final boolean LOOT = "1".equals(System.getenv("LOOT"));
    static final int LOOT_ORE_X = 8;
    static final int LOOT_ORE_Y = 10;
    static final int LOOT_ORE_Z = 8;
    static final String LOOT_ORE_BLOCK = "example1:my_ore";
    static final int LOOT_BEAST_X = 12;
    static final int LOOT_BEAST_Y = 10;
    static final int LOOT_BEAST_Z = 8;
    static final int LOOT_HARVEST_TICK = 1000;
    static final int LOOT_BEAST_DELAY = 5;
    static final int LOOT_TIMEOUT = 600;

    volatile int serverTicks = 0;
    volatile int worldTicks = 0;
    volatile int lootOreTick = -1;
    volatile int lootBeastTick = -1;
    volatile boolean oreDropped = false;
    volatile boolean beastDropped = false;
    volatile boolean lootFailed = false;
    volatile int oreDropTick = -1;
    volatile int beastDropTick = -1;
    World world = null;
    boolean foreignNoted = false;
    boolean playerNoted = false;
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
    public void onWorldTick(TickEvent.WorldTickEvent event) {
        if (event.side != Side.SERVER
                || event.phase != TickEvent.Phase.END) {
            return;
        }
        if (!LOOT) {
            return;
        }
        if (event.world.provider.getDimension() != 0) {
            if (!foreignNoted) {
                foreignNoted = true;
                System.out.println("[MatouAutoplay] note loot-proof : "
                        + "ignoring non-zero-dim world ticks (the integrated "
                        + "server ticks dim 0/1/-1 from boot)");
            }
            return;
        }
        if (world == null) {
            world = event.world;
            System.out.println("[MatouAutoplay] loot armed <ore "
                    + LOOT_ORE_X + "," + LOOT_ORE_Y + ","
                    + LOOT_ORE_Z + ":" + LOOT_ORE_BLOCK + " + pig "
                    + LOOT_BEAST_X + "," + LOOT_BEAST_Y + ","
                    + LOOT_BEAST_Z + "> harvestAt="
                    + LOOT_HARVEST_TICK + " (LOOT=1)");
        }
        worldTicks++;
        if (!lootFailed) {
            lootTick();
        }
    }

    private void lootFail(String what) {
        lootFailed = true;
        System.out.println("[MatouAutoplay] FAIL loot-proof : " + what);
    }

    private void lootTick() {
        if (lootOreTick < 0 && worldTicks >= LOOT_HARVEST_TICK) {
            lootOre();
        } else if (lootOreTick >= 0 && lootBeastTick < 0
                && worldTicks >= lootOreTick + LOOT_BEAST_DELAY) {
            lootBeast();
        }
        if ((lootOreTick >= 0 && !oreDropped)
                || (lootBeastTick >= 0 && !beastDropped)) {
            lootPoll();
        }
        if (!(oreDropped && beastDropped)
                && worldTicks > LOOT_HARVEST_TICK + LOOT_TIMEOUT) {
            lootFail("timeout (oreDropped=" + oreDropped + " beastDropped="
                    + beastDropped + " " + LOOT_TIMEOUT
                    + " ticks after harvest at worldTick "
                    + LOOT_HARVEST_TICK + ")");
        }
    }

    /**
     * Joined player or null (postponed, loudly once): both simulated
     * events are authored by the joined player — the harvest-drops post
     * carries it like the 1710 spike break post, and an authorless kill
     * proves nothing. Checked before touching the world.
     */
    private EntityPlayer lootPlayer() {
        if (world.playerEntities == null
                || world.playerEntities.isEmpty()) {
            if (!playerNoted) {
                playerNoted = true;
                System.out.println("[MatouAutoplay] note loot-proof : "
                        + "player absent at harvest tick, postponing");
            }
            return null;
        }
        return world.playerEntities.get(0);
    }

    private void lootOre() {
        EntityPlayer player = lootPlayer();
        if (player == null) {
            return;
        }
        Block ore = Block.getBlockFromName(LOOT_ORE_BLOCK);
        if (ore == null) {
            lootFail("unknown <" + LOOT_ORE_BLOCK + "> (want registered ore)");
            return;
        }
        IBlockState oreState = ore.getDefaultState();
        BlockPos at = new BlockPos(LOOT_ORE_X, LOOT_ORE_Y, LOOT_ORE_Z);
        if (!world.isAirBlock(at)) {
            lootFail("loot cell occupied before place (want air)");
            return;
        }
        if (!world.setBlockState(at, oreState)) {
            lootFail("place refused (setBlockState false at worldTick "
                    + worldTicks + ")");
            return;
        }
        if (world.isAirBlock(at)) {
            lootFail("place invisible (still air after setBlockState)");
            return;
        }
        if (!world.setBlockToAir(at)) {
            lootFail("clear refused (setBlockToAir false)");
            return;
        }
        if (!world.isAirBlock(at)) {
            lootFail("clear invisible (not air after setBlockToAir)");
            return;
        }
        MinecraftForge.EVENT_BUS.post(new BlockEvent.HarvestDropsEvent(
                world, at, oreState, 0, 1.0f,
                new ArrayList<ItemStack>(), player, false));
        lootOreTick = worldTicks;
        System.out.println("[MatouAutoplay] loot ore harvested <"
                + LOOT_ORE_X + "," + LOOT_ORE_Y + "," + LOOT_ORE_Z + ":"
                + LOOT_ORE_BLOCK + "> at worldTick " + lootOreTick);
    }

    private void lootBeast() {
        if (lootPlayer() == null) {
            return;
        }
        // T1 any-kill-pays (hub decisions/LOOT.md): the loot kill lands
        // on a vanilla pig — every kill pays the single table entry
        // (per-mob filtering stays a re-opener).
        EntityPig pig = new EntityPig(world);
        // Owner discipline (measured live on 1710, same walk on 1122):
        // inherited vanilla members go through the declaring stub type,
        // never the pig.
        Entity body = pig;
        body.setPositionAndRotation(LOOT_BEAST_X + 0.5, LOOT_BEAST_Y,
                LOOT_BEAST_Z + 0.5, 0.0f, 0.0f);
        if (!world.spawnEntity(pig)) {
            lootFail("pig spawn refused at worldTick " + worldTicks);
            return;
        }
        MinecraftForge.EVENT_BUS.post(new LivingDropsEvent(pig, null,
                new ArrayList<EntityItem>(), 0, true));
        body.setDead();
        lootBeastTick = worldTicks;
        System.out.println("[MatouAutoplay] loot beast killed <"
                + LOOT_BEAST_X + "," + LOOT_BEAST_Y + ","
                + LOOT_BEAST_Z + ":pig> at worldTick "
                + lootBeastTick);
    }

    private void lootPoll() {
        if (world.loadedEntityList == null) {
            return;
        }
        for (Entity e : world.loadedEntityList) {
            if (!(e instanceof EntityItem)) {
                continue;
            }
            EntityItem item = (EntityItem) e;
            ItemStack stack = item.getItem();
            if (stack == null || stack.getItem() != Items.diamond) {
                continue;
            }
            if (!oreDropped && near(e, LOOT_ORE_X, LOOT_ORE_Y,
                    LOOT_ORE_Z)) {
                oreDropped = true;
                oreDropTick = worldTicks;
                System.out.println("[MatouAutoplay] loot ore dropped "
                        + "<diamond> at worldTick " + oreDropTick
                        + " (elapsed " + (oreDropTick - lootOreTick)
                        + ", want immediate)");
            }
            if (!beastDropped && near(e, LOOT_BEAST_X, LOOT_BEAST_Y,
                    LOOT_BEAST_Z)) {
                beastDropped = true;
                beastDropTick = worldTicks;
                System.out.println("[MatouAutoplay] loot beast dropped "
                        + "<diamond> at worldTick " + beastDropTick
                        + " (elapsed " + (beastDropTick - lootBeastTick)
                        + ", want immediate)");
            }
        }
    }

    private static boolean near(Entity e, int x, int y, int z) {
        return Math.abs(e.posX - (x + 0.5)) < 3.0
                && Math.abs(e.posY - (y + 0.5)) < 3.0
                && Math.abs(e.posZ - (z + 0.5)) < 3.0;
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
        if (LOOT && lootFailed && !done) {
            done = true;
            System.out.println("[MatouAutoplay] loot FAILED, shutting down");
            mc.shutdown();
            return;
        }
        if (serverTicks >= WAIT_SERVER_TICKS
                && (!LOOT || (oreDropped && beastDropped))
                && !done) {
            done = true;
            System.out.println("[MatouAutoplay] done after " + serverTicks + " server ticks, shutting down");
            mc.shutdown();
        }
    }
}
