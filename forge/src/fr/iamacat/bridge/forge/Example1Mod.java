package fr.iamacat.bridge.forge;

import fr.iamacat.bridge.Packs;
import java.io.File;
import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import net.minecraft.block.Block;
import net.minecraft.client.renderer.entity.RenderPig;
import net.minecraft.item.Item;
import net.minecraft.util.ResourceLocation;
import net.minecraftforge.event.RegistryEvent;
import net.minecraftforge.fml.client.registry.IRenderFactory;
import net.minecraftforge.fml.client.registry.RenderingRegistry;
import net.minecraftforge.fml.common.FMLCommonHandler;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.common.event.FMLInitializationEvent;
import net.minecraftforge.fml.common.event.FMLPreInitializationEvent;
import net.minecraftforge.fml.common.eventhandler.SubscribeEvent;
import net.minecraftforge.fml.common.registry.EntityRegistry;
import net.minecraftforge.fml.relauncher.Side;
import net.minecraftforge.fml.relauncher.SideOnly;

/**
 * Registration half of example1 (see hub decisions/REGISTRATION.md):
 * a second mod in the bridge jar under example1's own frozen modid
 * ({@code NAMES.md}, never a rename target). 1.12.2 registers blocks
 * through the {@code RegistryEvent.Register} event (fired after every
 * preInit, before any init), so preInit only queues validated specs and
 * the event subscriber registers them — names registered here always
 * precede {@link MatouBridgeMod} init-time binds, whatever the mod
 * order. The same preInit registers the one generic beast (hub
 * decisions/SPAWN.md, custom entity tranche) from the single-mob spawn
 * table — pig shape and renderer reused, vanilla pigs never carry our
 * census anymore. Block-only ports came first (no beast path); this
 * tranche narrows the species, {@code MatouEntity} is wired.
 * New refusals stay
 * registration-local ({@code E_REG_*}, never in the shared error
 * catalog). Only this package may touch {@code net.minecraft} /
 * {@code net.minecraftforge}.
 */
@Mod(modid = Example1Mod.MODID, name = "MatouExample1", version = "1.2.0",
        acceptableRemoteVersions = "*")
public final class Example1Mod {
    public static final String MODID = "example1";
    static final String PACKS_PATH = "config/matoubridge/packs.cfg";
    /**
     * Entity tranche: mod-local beast id (one generic beast, never one
     * per content — a second id would be a second entity).
     */
    static final int ENTITY_BEAST_ID = 0;
    /**
     * Entity tranche: pig-like tracking (range, update ticks, velocity).
     * Constants, never defaults: the proof watches beasts move and fall
     * like the pigs they replace (same values as the lead bridge).
     */
    static final int ENTITY_TRACKING_RANGE = 64;
    static final int ENTITY_UPDATE_TICKS = 1;
    static final boolean ENTITY_SENDS_VELOCITY = true;

    private static final List<PendingBlock> PENDING =
            new ArrayList<PendingBlock>();
    private static final Map<String, Block> REGISTERED =
            new HashMap<String, Block>();
    private static final List<PendingItem> PENDING_ITEMS =
            new ArrayList<PendingItem>();
    private static final Map<String, Item> REGISTERED_ITEMS =
            new HashMap<String, Item>();
    private String registeredEntity;

    /**
     * Registration: every packs.cfg wire naming a non-vanilla block
     * gets its content {@code BlockSpec} queued here, before any
     * init-time bind resolves it. Vanilla wires skip silently — the
     * bind-time resolve owns them, unchanged. A missing packs.cfg stays
     * passive (Q1 cohabitation), same as the bridge init.
     */
    @Mod.EventHandler
    public void preInit(FMLPreInitializationEvent event) {
        File cfg = new File(PACKS_PATH);
        if (!cfg.isFile()) {
            return;
        }
        List<String> lines;
        try {
            lines = Files.readAllLines(cfg.toPath(), StandardCharsets.UTF_8);
        } catch (Exception e) {
            throw new RuntimeException("E_REG_PACKS:unreadable <"
                    + PACKS_PATH + "> (" + e.getMessage() + ")", e);
        }
        List<Packs.PackSpec> specs = Packs.parseLines(lines);
        for (Packs.PackSpec spec : specs) {
            queueCustom(spec);
        }
        queueItems(specs);
        registerBeast(specs);
    }

    /**
     * Verify + announce: the registry is only reliably queryable once
     * loading reaches init, so the resolve check and the numeric-ID line
     * the verdict greps live here, not in preInit. Binds need no order
     * against this: registration already happened one FML state ago.
     */
    @Mod.EventHandler
    public void init(FMLInitializationEvent event) {
        for (Map.Entry<String, Block> e : REGISTERED.entrySet()) {
            if (Block.getBlockFromName(e.getKey()) != e.getValue()) {
                throw new IllegalStateException(
                        "E_REG_UNRESOLVED:registered but unresolvable <"
                                + e.getKey() + ">");
            }
            System.out.println("[MatouBridge] registered <" + e.getKey()
                    + "> id " + Block.getIdFromBlock(e.getValue()));
        }
        for (Map.Entry<String, Item> e : REGISTERED_ITEMS.entrySet()) {
            if (Item.getByNameOrId(e.getKey()) != e.getValue()) {
                throw new IllegalStateException(
                        "E_REG_ITEM:unresolved <" + e.getKey() + ">");
            }
            System.out.println("[MatouBridge] registered-item <" + e.getKey()
                    + "> id " + Item.getIdFromItem(e.getValue()));
        }
        if (registeredEntity != null) {
            if (EntityRegistry.instance().lookupModSpawn(
                    MatouEntity.class, true) == null) {
                throw new IllegalStateException(
                        "E_REG_BEAST:unregistered <"
                                + registeredEntity + ">");
            }
            System.out.println("[MatouBridge] registered-entity <"
                    + registeredEntity + ">");
            if (FMLCommonHandler.instance().getSide() == Side.CLIENT) {
                registerBeastRenderer();
            }
        }
    }

    /**
     * Version-native registration (1.12.2 Forge 2860): blocks and items
     * register on the Forge event bus, never through a direct registry call.
     */
    @Mod.EventBusSubscriber(modid = MODID)
    public static final class Blocks {
        private Blocks() {
        }

        @SubscribeEvent
        public static void registerBlocks(
                RegistryEvent.Register<Block> event) {
            for (PendingBlock p : PENDING) {
                Block ore = new MatouBlock(p.hardness, p.opaque);
                // Statement, return ignored: the call links through the
                // erased interface descriptor (see stub Block), the
                // Block-typed reference below is what registers.
                ore.setRegistryName(new ResourceLocation(p.name));
                try {
                    event.getRegistry().register(ore);
                } catch (Exception e) {
                    throw new IllegalArgumentException("E_REG_BLOCK:refused <"
                            + p.name + "> (" + e.getMessage() + ")", e);
                }
                REGISTERED.put(p.name, ore);
            }
            PENDING.clear();
        }

        @SubscribeEvent
        public static void registerItems(
                RegistryEvent.Register<Item> event) {
            for (PendingItem p : PENDING_ITEMS) {
                Item item = new MatouItem(p.shortName, p.stack);
                item.setRegistryName(new ResourceLocation(p.name));
                try {
                    event.getRegistry().register(item);
                } catch (Exception e) {
                    throw new IllegalArgumentException("E_REG_ITEM:refused <"
                            + p.name + "> (" + e.getMessage() + ")", e);
                }
                REGISTERED_ITEMS.put(p.name, item);
            }
            PENDING_ITEMS.clear();
        }
    }

    /**
     * Entity registration: the single mob ref from the same owned content
     * the loot table and the spawn wire came from (parsed once, like
     * blocks — never on the tick path). No owned file anywhere means no
     * beast (Q1 cohabitation), same passivity as the spawn wire. Several
     * distinct owned files refuse loudly — silent table picks are
     * defaults, and per-mob tables are a documented re-opener.
     *
     * <p>1.12.2 shape (measured via javap on the pinned 2860 universal,
     * never the 1.7.10 call): {@code registerModEntity} takes the
     * registry name first ({@code ResourceLocation}, obf {@code nf} —
     * same slot as {@code IForgeRegistryEntry.setRegistryName}, proven
     * by the block path). The full content mob ref rides verbatim as the
     * registry name (no container-prefix guessing on the entity path);
     * the short name past the first colon is the entity name (lead
     * parity).
     */
    private void registerBeast(List<Packs.PackSpec> specs) {
        Set<String> owned = new HashSet<String>();
        for (Packs.PackSpec spec : specs) {
            String path = spec.args.get("ownedFile");
            if (path != null) {
                owned.add(path);
            }
        }
        if (owned.isEmpty()) {
            return;
        }
        if (owned.size() > 1) {
            throw new IllegalArgumentException("E_REG_TABLE:multi <"
                    + owned + "> (one beast table per bridge)");
        }
        String ownedFile = owned.iterator().next();
        String mob = loadMobRef(ownedFile);
        int colon = mob.indexOf(':');
        String shortName = mob.substring(colon + 1);
        registeredEntity = mob;
        try {
            EntityRegistry.registerModEntity(new ResourceLocation(mob),
                    MatouEntity.class, shortName, ENTITY_BEAST_ID, this,
                    ENTITY_TRACKING_RANGE, ENTITY_UPDATE_TICKS,
                    ENTITY_SENDS_VELOCITY);
        } catch (Exception e) {
            throw new IllegalArgumentException("E_REG_BEAST:refused <"
                    + mob + "> (" + e.getMessage() + ")", e);
        }
    }

    /**
     * Client-only renderer mapping: the generic beast reuses the vanilla
     * pig renderer until the custom-renderer tranche. Stripped on the
     * server ({@code @SideOnly}), so dedicated servers never resolve the
     * client classes — a missing mapping would die loudly on the client
     * instead (null renderer at first tracked spawn).
     *
     * <p>1.12.2 shape (measured: notch {@code cak} from the pinned client
     * jar has the single {@code (RenderManager)} ctor — the 1.7.10
     * 3-arg saddle ctor does not exist here, the saddle is a layer): the
     * factory path is the only honest one (the legacy {@code (Class,
     * Render)} overload still exists on 2860 but its load path is
     * unproven — never the quiet pick).
     */
    @SideOnly(Side.CLIENT)
    private static void registerBeastRenderer() {
        IRenderFactory<MatouEntity> pigs = RenderPig::new;
        RenderingRegistry.registerEntityRenderingHandler(
                MatouEntity.class, pigs);
        InstancedMeshRenderer.initClient();
    }

    /**
     * Content mob ref, reached reflectively: the bridge stays content-blind
     * at build time (Q2 — same rule as {@code loadSpecs}). The
     * single-mob rule lives in {@code SpawnTable.fromFile} — zero or
     * several mobs already refuse there, never a quiet pick here. Every
     * failure is coded E_REG_*, never a silent default.
     */
    private static String loadMobRef(String ownedFile) {
        final Class<?> cls;
        try {
            cls = Class.forName("fr.iamacat.example1.SpawnTable");
        } catch (ClassNotFoundException e) {
            throw new IllegalArgumentException("E_REG_BEAST:missing "
                    + "example1 for <" + ownedFile + "> ("
                    + e.getMessage() + ")", e);
        }
        final Method fromFile;
        try {
            fromFile = cls.getMethod("fromFile", String.class);
        } catch (NoSuchMethodException e) {
            throw new IllegalArgumentException("E_REG_BEAST:shape "
                    + "<fr.iamacat.example1.SpawnTable> ("
                    + e.getMessage() + ")", e);
        }
        try {
            Object table = fromFile.invoke(null, ownedFile);
            Object mob = table.getClass().getMethod("mob").invoke(table);
            if (!(mob instanceof String) || ((String) mob).isEmpty()
                    || ((String) mob).indexOf(':') < 0) {
                throw new IllegalStateException("E_REG_BEAST:shape "
                        + "<fromFile> (want qualified mob ref)");
            }
            return (String) mob;
        } catch (java.lang.reflect.InvocationTargetException e) {
            Throwable cause = e.getCause() != null ? e.getCause() : e;
            throw new IllegalArgumentException("E_REG_BEAST:unreadable <"
                    + ownedFile + "> (" + cause.getMessage() + ")", e);
        } catch (IllegalAccessException e) {
            throw new IllegalArgumentException("E_REG_BEAST:shape <"
                    + ownedFile + "> (" + e.getMessage() + ")", e);
        } catch (NoSuchMethodException e) {
            throw new IllegalArgumentException("E_REG_BEAST:shape "
                    + "<fr.iamacat.example1.SpawnTable> ("
                    + e.getMessage() + ")", e);
        }
    }

    private static void queueCustom(Packs.PackSpec spec) {
        String want = spec.blockName;
        int colon = want.indexOf(':');
        if (colon < 0 || want.startsWith("minecraft:")) {
            return;
        }
        if (REGISTERED.containsKey(want) || pendingContains(want)) {
            return;
        }
        if (Block.getBlockFromName(want) != null) {
            throw new IllegalArgumentException(
                    "E_REG_DUP:already registered <" + want + ">");
        }
        String shortName = want.substring(colon + 1);
        String ownedFile = spec.args.get("ownedFile");
        if (ownedFile == null) {
            throw new IllegalArgumentException("E_REG_NOSPEC:no ownedFile "
                    + "for custom <" + want + "> (operator must point at "
                    + "the content declaring it)");
        }
        float hardness = 0.0f;
        boolean opaque = true;
        boolean found = false;
        for (Object o : loadSpecs(ownedFile)) {
            if (!shortName.equals(specField(o, "name", ownedFile))) {
                continue;
            }
            if (found) {
                throw new IllegalArgumentException("E_REG_SPEC:dup <"
                        + shortName + "> in <" + ownedFile + ">");
            }
            Object h = specField(o, "hardness", ownedFile);
            Object op = specField(o, "opaque", ownedFile);
            if (!(h instanceof Float) || !(op instanceof Boolean)) {
                throw new IllegalArgumentException("E_REG_SPEC:shape <"
                        + ownedFile + "> (bad physics types)");
            }
            hardness = ((Float) h).floatValue();
            opaque = ((Boolean) op).booleanValue();
            found = true;
        }
        if (!found) {
            throw new IllegalArgumentException("E_REG_NOSPEC:no block <"
                    + shortName + "> in <" + ownedFile + "> for <" + want
                    + ">");
        }
        PENDING.add(new PendingBlock(want, hardness, opaque));
    }

    private static boolean pendingContains(String want) {
        for (PendingBlock p : PENDING) {
            if (p.name.equals(want)) {
                return true;
            }
        }
        return false;
    }

    private static final class PendingBlock {
        final String name;
        final float hardness;
        final boolean opaque;

        PendingBlock(String name, float hardness, boolean opaque) {
            this.name = name;
            this.hardness = hardness;
            this.opaque = opaque;
        }
    }

    private void queueItems(List<Packs.PackSpec> specs) {
        Set<String> owned = new HashSet<String>();
        for (Packs.PackSpec spec : specs) {
            String path = spec.args.get("ownedFile");
            if (path != null) {
                owned.add(path);
            }
        }
        for (String ownedFile : owned) {
            for (Object o : loadItemSpecs(ownedFile)) {
                String shortName = (String) specField(o, "name", ownedFile);
                String want = MODID + ":" + shortName;
                if (REGISTERED_ITEMS.containsKey(want)) {
                    continue;
                }
                if (Item.getByNameOrId(want) != null) {
                    throw new IllegalArgumentException(
                            "E_REG_ITEM:already registered <" + want + ">");
                }
                Object s = specField(o, "stack", ownedFile);
                if (!(s instanceof Integer)) {
                    throw new IllegalArgumentException(
                            "E_REG_SPEC:shape <" + ownedFile + "> (bad stack type)");
                }
                int stack = ((Integer) s).intValue();
                PENDING_ITEMS.add(new PendingItem(want, shortName, stack));
            }
        }
    }

    private static final class PendingItem {
        final String name;
        final String shortName;
        final int stack;

        PendingItem(String name, String shortName, int stack) {
            this.name = name;
            this.shortName = shortName;
            this.stack = stack;
        }
    }

    private static List<?> loadItemSpecs(String ownedFile) {
        final Class<?> cls;
        try {
            cls = Class.forName("fr.iamacat.example1.ItemSpec");
        } catch (ClassNotFoundException e) {
            throw new IllegalArgumentException("E_REG_SPEC:missing "
                    + "example1 for <" + ownedFile + "> ("
                    + e.getMessage() + ")", e);
        }
        final Method fromFile;
        try {
            fromFile = cls.getMethod("fromFile", String.class);
        } catch (NoSuchMethodException e) {
            throw new IllegalArgumentException("E_REG_SPEC:shape "
                    + "<fr.iamacat.example1.ItemSpec> ("
                    + e.getMessage() + ")", e);
        }
        try {
            Object out = fromFile.invoke(null, ownedFile);
            if (!(out instanceof List)) {
                throw new IllegalStateException("E_REG_SPEC:shape "
                        + "<fromFile> (want List)");
            }
            return (List<?>) out;
        } catch (java.lang.reflect.InvocationTargetException e) {
            Throwable cause = e.getCause() != null ? e.getCause() : e;
            throw new IllegalArgumentException("E_REG_SPEC:unreadable <"
                    + ownedFile + "> (" + cause.getMessage() + ")", e);
        } catch (IllegalAccessException e) {
            throw new IllegalArgumentException("E_REG_SPEC:shape <"
                    + ownedFile + "> (" + e.getMessage() + ")", e);
        }
    }

    /**
     * Content specs, reached reflectively: the bridge stays content-blind
     * at build time (Q2 — same rule as {@code Packs.load}). Every
     * failure is coded E_REG_*, never a silent default.
     */
    private static List<?> loadSpecs(String ownedFile) {
        final Class<?> cls;
        try {
            cls = Class.forName("fr.iamacat.example1.BlockSpec");
        } catch (ClassNotFoundException e) {
            throw new IllegalArgumentException("E_REG_SPEC:missing "
                    + "example1 for <" + ownedFile + "> ("
                    + e.getMessage() + ")", e);
        }
        final Method fromFile;
        try {
            fromFile = cls.getMethod("fromFile", String.class);
        } catch (NoSuchMethodException e) {
            throw new IllegalArgumentException("E_REG_SPEC:shape "
                    + "<fr.iamacat.example1.BlockSpec> ("
                    + e.getMessage() + ")", e);
        }
        try {
            Object out = fromFile.invoke(null, ownedFile);
            if (!(out instanceof List)) {
                throw new IllegalStateException("E_REG_SPEC:shape "
                        + "<fromFile> (want List)");
            }
            return (List<?>) out;
        } catch (java.lang.reflect.InvocationTargetException e) {
            Throwable cause = e.getCause() != null ? e.getCause() : e;
            throw new IllegalArgumentException("E_REG_SPEC:unreadable <"
                    + ownedFile + "> (" + cause.getMessage() + ")", e);
        } catch (IllegalAccessException e) {
            throw new IllegalArgumentException("E_REG_SPEC:shape <"
                    + ownedFile + "> (" + e.getMessage() + ")", e);
        }
    }

    private static Object specField(Object spec, String getter,
            String ownedFile) {
        try {
            return spec.getClass().getMethod(getter).invoke(spec);
        } catch (Exception e) {
            throw new IllegalArgumentException("E_REG_SPEC:shape <"
                    + ownedFile + "> (no " + getter + ")", e);
        }
    }
}
