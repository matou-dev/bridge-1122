#!/bin/sh
# C3 live gate: Forge 1.12.2-2860 server run proving PackWire.bind
# (real Block resolve) plus world-tick apply on a real world, then comparing
# the world against the pure decision union (tools/live).
#
# Manual gate (needs network once + Java 8); opt-in from tools/check.sh via
# LIVE=1, never blocking by default. Never silent: any mismatch fails loudly,
# never defaulted.
#
# Env (no machine paths hardcoded):
#   C3_DIR     work dir (default ${TMPDIR:-/tmp}/matou-c3-live; non-owned
#              leftovers refused loudly by the preflight — clean or fresh dir)
#   JAVA8_HOME Java 8 home (default /usr/lib/jvm/java-8-openjdk)
#   FORGE_URL  installer URL (default Maven 2860 installer)
#   MCP_CONFIG_URL  MCP config URL (default Forge Maven mcp_config 1.12.2,
#              carries joined.tsrg, the obf<->SRG map the narrow SRG derives from)
#   BOOT_SECS  server run time (default 150; short runs fail coverage loudly)
#   C3_OFFLINE=1  never download (fail loudly if cache files missing)
#
# R2 release assembly: BUILD_ONLY=1 VERSION=x.y.z assembles dist/ (versioned
# jars + content + packs.cfg.example + SHA256SUMS) and exits before booting
# the server. Release demands strict X.Y.Z, a clean tree in all 4 code repos,
# and @Mod version == VERSION; anything else fails loudly, never defaulted.
# SOURCE_DATE_EPOCH pins jar entry timestamps (default: bridge HEAD commit
# time); with a pinned toolchain (tools/live/Dockerfile) the same commit
# always yields the same bytes.
#
# Reproducibility pins: installer / universal / vanilla server / MCP config /
# ASM sha1 below. Any upstream drift fails loudly instead of running against
# unknown bytes. 1.12.2 ships no srg-mcp.srg (ForgeGradle is not required):
# the 48-line narrow map derives deterministically from the pinned vanilla
# server + joined.tsrg (see step 2), so the pins below are the whole
# upstream surface.
set -eu
cd "$(dirname "$0")/.."
# Shared harness steps (hub SSOT, thin version wrapper — hub
# decisions/LIVE_SHELL_COMMON.md): sibling-absent fails loud, same shim
# discipline as tools/run-client.sh.
[ -f ../hub/tools/live-common.sh ] \
  || { echo "FAIL c3-live : hub sibling absent (clone hub next to bridge-1122 — live steps source ../hub/tools/live-common.sh)"; exit 1; }
[ -f ../hub/tools/live-derive.sh ] \
  || { echo "FAIL c3-live : hub sibling absent (clone hub next to bridge-1122 — derive steps source ../hub/tools/live-derive.sh)"; exit 1; }
# shellcheck disable=SC1091
. ../hub/tools/live-common.sh
# shellcheck disable=SC1091
. ../hub/tools/live-derive.sh
live_init "c3-live"
# Era-bound adapters: the hub libs own the mechanics; these bind the
# caller-owned map/jars so every pin/jar call site below stays byte-identical.
pin_method() { live_pin_method "$SRG_NARROW" "$@"; }
pin_field() { live_pin_field "$SRG_NARROW" "$@"; }
pin_uni() { live_pin_uni "$J8" "$UNI" "$@"; }
mkjar() { live_mkjar "$1" "$2" "$BLD/MANIFEST.MF" "$J8/jar" "$EPOCH"; }
normjar() { live_normjar "$1" "$EPOCH"; }
C3_DIR="${C3_DIR:-${TMPDIR:-/tmp}/matou-c3-live}"
JAVA8_HOME="${JAVA8_HOME:-/usr/lib/jvm/java-8-openjdk}"
FORGE_URL="${FORGE_URL:-https://maven.minecraftforge.net/net/minecraftforge/forge/1.12.2-14.23.5.2860/forge-1.12.2-14.23.5.2860-installer.jar}"
MCP_CONFIG_URL="${MCP_CONFIG_URL:-https://maven.minecraftforge.net/de/oceanlabs/mcp/mcp_config/1.12.2/mcp_config-1.12.2.zip}"
BOOT_SECS="${BOOT_SECS:-150}"
# Pins: measured 2026-09-09 from the Maven installer + installed universal +
# Mojang vanilla server + MCP config + provisioned ASM 5.2. Drift = loud
# failure, never silent upgrade.
INSTALLER_SHA1="5e8a91f71ef3d1f77de3f8d3261aedcc2f551c9d"
UNIVERSAL_SHA1="029250575d3aa2cf80b56dffb66238a1eeaea2ac"
MC_SERVER_SHA1="886945bfb2b978778c3a0288fd7fab09d315b25f"
MCP_CONFIG_SHA1="b5a744c9310b05c91e71f0648eb5e3d33410fb92"
ASM_PIN="asm-debug-all-5.2.jar"
ASM_SHA1="3354e11e2b34215f06dab629ab88e06aca477c19"
J8="$JAVA8_HOME/bin"
[ -x "$J8/java" ] || { echo "FAIL c3-live : no Java 8 at <$JAVA8_HOME>"; exit 1; }
[ -d ../spi/java/src ] || { echo "FAIL c3-live : spi sibling absent"; exit 1; }
[ -d ../example1/java/src ] || { echo "FAIL c3-live : example1 sibling absent"; exit 1; }
[ -d ../minimap/java/src ] || { echo "FAIL c3-live : minimap sibling absent"; exit 1; }
command -v python3 >/dev/null || { echo "FAIL c3-live : python3 required (srg derive + anvil verify)"; exit 1; }
# R2 versioning: VERSION stamps manifests + mcmod.info. Dev live runs take an
# explicit non-release default; release assembly demands strict X.Y.Z.
VERSION="${VERSION:-0.0-dev}"
if [ "${BUILD_ONLY:-}" = "1" ]; then
  printf '%s' "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' \
    || { echo "FAIL r2-release : VERSION=<$VERSION> not X.Y.Z (want e.g. 1.0.0)"; exit 1; }
  for r in . ../spi ../example1 ../minimap; do
    git -C "$r" diff --quiet && git -C "$r" diff --cached --quiet \
      || { echo "FAIL r2-release : dirty tree in <$r> (release from clean checkouts only)"; exit 1; }
  done
  grep -q "version = \"$VERSION\"" forge/src/fr/iamacat/bridge/forge/MatouBridgeMod.java \
    || { echo "FAIL r2-release : @Mod version != VERSION=<$VERSION> (bump source first)"; exit 1; }
  grep -q "version = \"$VERSION\"" forge/src/fr/iamacat/bridge/forge/Example1Mod.java \
    || { echo "FAIL r2-release : example1 @Mod version != VERSION=<$VERSION> (bump source first, both @Mods ride together)"; exit 1; }
fi

# 1. Provision the 2860 server once (idempotent, checksum-verified).
#    C3_OFFLINE=1 never touches the network: missing cache fails loudly.
mkdir -p "$C3_DIR"
SERV="$C3_DIR/server"
mkdir -p "$SERV"
# 1a. C3_DIR preflight (docker root-owned leftovers fail fast, loudly).
live_preflight_dir "C3_DIR" "$C3_DIR"
live_fetch "$C3_DIR/forge-installer.jar" "$FORGE_URL" "$INSTALLER_SHA1" "${C3_OFFLINE:-0}"
UNI="$SERV/forge-1.12.2-14.23.5.2860.jar"
live_install_server "$SERV" "$C3_DIR/forge-installer.jar" "$J8"
echo "$UNIVERSAL_SHA1  $UNI" | sha1sum -c - >/dev/null 2>&1 \
  || { echo "FAIL c3-live : universal sha1 drift (want $UNIVERSAL_SHA1)"; exit 1; }
MCSERV="$SERV/minecraft_server.1.12.2.jar"
[ -f "$MCSERV" ] || { echo "FAIL c3-live : vanilla server absent ($MCSERV, re-run --installServer online)"; exit 1; }
echo "$MC_SERVER_SHA1  $MCSERV" | sha1sum -c - >/dev/null 2>&1 \
  || { echo "FAIL c3-live : vanilla server sha1 drift (want $MC_SERVER_SHA1)"; exit 1; }
ASM=$(find "$SERV/libraries/org/ow2/asm" -name "$ASM_PIN" | head -n 1)
[ -n "$ASM" ] || { echo "FAIL c3-live : ASM $ASM_PIN missing from server libs"; exit 1; }
echo "$ASM_SHA1  $ASM" | sha1sum -c - >/dev/null 2>&1 \
  || { echo "FAIL c3-live : ASM sha1 drift (want $ASM_SHA1)"; exit 1; }
live_fetch "$C3_DIR/mcp_config-1.12.2.zip" "$MCP_CONFIG_URL" "$MCP_CONFIG_SHA1" "${C3_OFFLINE:-0}"
echo "ok c3-live : server provisioned (pins verified)"
# Vanilla CLIENT jar (pinned once in tools/autoplay/client-pin.txt — the
# companion derive already trusts it; this script reuses the same bytes,
# never its own pin): client-only vanilla members (net/minecraft/client/*,
# e.g. the renderer tranche's Minecraft/getMinecraft) cannot javap-verify
# against the notch SERVER jar (no client classes in it), so the derive
# below checks those rows against these bytes instead. Same offline rule
# as every other fetch above.
CLIENT_PIN_URL="$(sed -n 's/^URL=//p' tools/autoplay/client-pin.txt)"
CLIENT_PIN_SHA1="$(sed -n 's/^SHA1=//p' tools/autoplay/client-pin.txt)"
[ -n "$CLIENT_PIN_URL" ] && [ -n "$CLIENT_PIN_SHA1" ] \
  || { echo "FAIL c3-live : malformed tools/autoplay/client-pin.txt (want URL= + SHA1=)"; exit 1; }
MCCLIENT="$C3_DIR/vanilla-client.jar"
if [ ! -f "$MCCLIENT" ] || ! echo "$CLIENT_PIN_SHA1  $MCCLIENT" | sha1sum -c - >/dev/null 2>&1; then
  if [ "${C3_OFFLINE:-}" = "1" ]; then
    echo "FAIL c3-live : offline and vanilla client absent ($MCCLIENT)"
    exit 1
  fi
  echo "note c3-live : fetching pinned vanilla client (network once, $CLIENT_PIN_SHA1)"
  rm -f "$MCCLIENT"
  curl -sL -o "$MCCLIENT" "$CLIENT_PIN_URL" \
    || { echo "FAIL c3-live : vanilla client download failed"; exit 1; }
  echo "$CLIENT_PIN_SHA1  $MCCLIENT" | sha1sum -c - >/dev/null 2>&1 \
    || { echo "FAIL c3-live : vanilla client sha1 drift (want $CLIENT_PIN_SHA1, never silent upgrade)"; exit 1; }
fi
echo "ok c3-live : vanilla client pinned ($CLIENT_PIN_SHA1)"

# 2. Derive the narrow MCP->SRG map from pinned bytes (no srg-mcp.srg on
#    1.12.2): joined.tsrg gives obf<->SRG per class, the notch jars
#    disambiguate overloads and static-ness via javap (exactly-one assert
#    per member, loud otherwise): the notch SERVER jar for shared classes,
#    the pinned vanilla CLIENT jar for net/minecraft/client/* rows (no
#    client classes in the server jar). The map covers every vanilla
#    member our forge/ bytecode references (step 3b scans the built MCP
#    jar against it — Reobf passes unmapped names through silently, so an
#    uncovered ref dies linking live, never here quietly):
#    getBlockFromName, getDefaultState, setBlockState, provider, plus the
#    registration tranche: setHardness, getIdFromBlock, isOpaqueCube,
#    Material/ROCK, plus the custom entity tranche (Forge-side, pinned in
#    step 2c, never in the narrow map: EntityRegistry, RenderingRegistry,
#    IRenderFactory, FMLCommonHandler/getSide), plus the loot tranche: spawnEntity, EntityItem/ItemStack
#    getItem, Items/diamond, Entity/world/posX/posY/posZ, World/isRemote,
#    IBlockState/getBlock, Vec3i/getX/getY/getZ, plus the spawn tranche:
#    Entity/getEntityId/isDead/setPositionAndRotation,
#    World/loadedEntityList, EntityLivingBase/getEntityAttribute/
#    getMaxHealth/setHealth, IAttributeInstance/setBaseValue,
#    SharedMonsterAttributes/maxHealth).
#    The combat tranche (hub decisions/VIRTUAL_HITBOXES.md, server
#    weakspot hook) adds 6 rows: Entity/getLookVec + getEyeHeight (the
#    attacker eye/look surface, owner Entity), DamageSource/getTrueSource
#    (the true attacker behind the hurt source) and Vec3d/x/y/z (the
#    look components) — the narrow map grows 42 -> 48 lines (40 server
#    rows plus the 8 renderer rows below).
#    The repop tranche (hub decisions/REPOP_SPIKE.md, T1 stone) adds no
#    vanilla member: the break hook reads world/pos/state (Forge getters,
#    pinned below) + isRemote/provider/getDimension (passthrough) +
#    IBlockState/getBlock + Vec3i/getX/getY/getZ, the stone resolve and
#    the sink land reuse getBlockFromName/getDefaultState/setBlockState —
#    all pinned by earlier tranches, so the narrow map stays 48 lines
#    (40 server rows plus the 8 renderer rows below).
#    The second-beast tranche (hub decisions/VIRTUAL_HITBOXES.md,
#    per-mob NBT identity) adds 5 rows: EntityPig/writeEntityToNBT +
#    readEntityFromNBT (the persist helpers, owner EntityPig — the
#    public writeToNBT/readFromNBT live one level up on Entity and
#    their super calls would emit an unmappable intermediate owner, so
#    the beast overrides the Pig-declared helpers func_70014_b/func_70037_a
#    instead) and NBTTagCompound/hasKey + getString + setString (the
#    string-tag surface) — the narrow map grows 48 -> 53 lines (45
#    server rows plus the 8 renderer rows below).
#    WorldProvider.getDimension is NOT mapped on purpose: it is Forge-added
#    (11 readable call sites in the pinned universal, e.g. DimensionManager),
#    hence runtime-final — Reobf passes it through by design, and the live
#    verdict proves it behaviorally (a wrong dim gate skips every tick, so
#    the world would come back empty, never silently wrong).
# Mechanics live in hub/tools/live-derive.sh (era 1.12), rows in
# tools/live/want.tsv — same 53 lines, byte-identical output.
SRG_NARROW="$C3_DIR/srg-narrow.srg"
live_derive_mcp_anchor "$C3_DIR/mcp_config-1.12.2.zip" "$MCSERV" "$J8/javap" "$SRG_NARROW" "$MCCLIENT" "tools/live/want.tsv"
# 2b. Pin every derived line: a derivation the SRG does not confirm is a loud
#     failure, never a silent default. getDimension stays unmapped by design.
pin_method "net/minecraft/block/Block/getBlockFromName" "(Ljava/lang/String;)Lnet/minecraft/block/Block;"
pin_method "net/minecraft/block/Block/getDefaultState" "()Lnet/minecraft/block/state/IBlockState;"
pin_method "net/minecraft/world/World/setBlockState" "(Lnet/minecraft/util/math/BlockPos;Lnet/minecraft/block/state/IBlockState;)Z"
pin_method "net/minecraft/block/Block/setHardness" "(F)Lnet/minecraft/block/Block;"
pin_method "net/minecraft/block/Block/getIdFromBlock" "(Lnet/minecraft/block/Block;)I"
pin_method "net/minecraft/block/Block/isOpaqueCube" "(Lnet/minecraft/block/state/IBlockState;)Z"
pin_field "net/minecraft/world/World/provider"
pin_field "net/minecraft/block/material/Material/ROCK"
pin_method "net/minecraft/world/World/spawnEntity" "(Lnet/minecraft/entity/Entity;)Z"
pin_method "net/minecraft/entity/item/EntityItem/getItem" "()Lnet/minecraft/item/ItemStack;"
pin_method "net/minecraft/item/ItemStack/getItem" "()Lnet/minecraft/item/Item;"
pin_field "net/minecraft/init/Items/diamond"
pin_field "net/minecraft/entity/Entity/world"
pin_field "net/minecraft/entity/Entity/posX"
pin_field "net/minecraft/entity/Entity/posY"
pin_field "net/minecraft/entity/Entity/posZ"
pin_field "net/minecraft/world/World/isRemote"
pin_method "net/minecraft/block/state/IBlockState/getBlock" "()Lnet/minecraft/block/Block;"
pin_method "net/minecraft/util/math/Vec3i/getX" "()I"
pin_method "net/minecraft/util/math/Vec3i/getY" "()I"
pin_method "net/minecraft/util/math/Vec3i/getZ" "()I"
pin_method "net/minecraft/entity/Entity/getEntityId" "()I"
pin_field "net/minecraft/entity/Entity/isDead"
pin_field "net/minecraft/world/World/loadedEntityList"
pin_method "net/minecraft/entity/Entity/setPositionAndRotation" "(DDDFF)V"
pin_method "net/minecraft/entity/EntityLivingBase/getEntityAttribute" "(Lnet/minecraft/entity/ai/attributes/IAttribute;)Lnet/minecraft/entity/ai/attributes/IAttributeInstance;"
pin_method "net/minecraft/entity/EntityLivingBase/getMaxHealth" "()F"
pin_method "net/minecraft/entity/EntityLivingBase/setHealth" "(F)V"
pin_method "net/minecraft/entity/ai/attributes/IAttributeInstance/setBaseValue" "(D)V"
pin_field "net/minecraft/entity/SharedMonsterAttributes/maxHealth"
pin_method "net/minecraft/item/Item/setMaxStackSize" "(I)Lnet/minecraft/item/Item;"
pin_method "net/minecraft/item/Item/setUnlocalizedName" "(Ljava/lang/String;)Lnet/minecraft/item/Item;"
pin_method "net/minecraft/item/Item/getIdFromItem" "(Lnet/minecraft/item/Item;)I"
pin_method "net/minecraft/item/Item/getByNameOrId" "(Ljava/lang/String;)Lnet/minecraft/item/Item;"
pin_method "net/minecraft/client/Minecraft/getMinecraft" "()Lnet/minecraft/client/Minecraft;"
pin_field "net/minecraft/client/Minecraft/world"
pin_method "net/minecraft/client/Minecraft/getRenderViewEntity" "()Lnet/minecraft/entity/Entity;"
pin_field "net/minecraft/entity/Entity/lastTickPosX"
pin_field "net/minecraft/entity/Entity/lastTickPosY"
pin_field "net/minecraft/entity/Entity/lastTickPosZ"
pin_field "net/minecraft/entity/Entity/rotationYaw"
pin_field "net/minecraft/entity/Entity/rotationPitch"
pin_method "net/minecraft/entity/Entity/getLookVec" "()Lnet/minecraft/util/math/Vec3d;"
pin_method "net/minecraft/entity/Entity/getEyeHeight" "()F"
pin_method "net/minecraft/util/DamageSource/getTrueSource" "()Lnet/minecraft/entity/Entity;"
pin_field "net/minecraft/util/math/Vec3d/x"
pin_field "net/minecraft/util/math/Vec3d/y"
pin_field "net/minecraft/util/math/Vec3d/z"
pin_method "net/minecraft/entity/passive/EntityPig/writeEntityToNBT" "(Lnet/minecraft/nbt/NBTTagCompound;)V"
pin_method "net/minecraft/entity/passive/EntityPig/readEntityFromNBT" "(Lnet/minecraft/nbt/NBTTagCompound;)V"
pin_method "net/minecraft/nbt/NBTTagCompound/hasKey" "(Ljava/lang/String;)Z"
pin_method "net/minecraft/nbt/NBTTagCompound/getString" "(Ljava/lang/String;)Ljava/lang/String;"
pin_method "net/minecraft/nbt/NBTTagCompound/setString" "(Ljava/lang/String;Ljava/lang/String;)V"
grep -q "getDimension" "$SRG_NARROW" \
  && { echo "FAIL c3-live : getDimension must stay unmapped (Forge-added, runtime-final)"; exit 1; }
[ "$(grep -c . "$SRG_NARROW")" = "53" ] \
  || { echo "FAIL c3-live : narrow map drift (want 53 lines)"; exit 1; }
echo "ok c3-live : stubs pinned to derived SRG"

# 2c. Pin every stubbed Forge member against the provisioned 2860 universal.
#     Forge classes are never obfuscated, so names are final — presence is
#     the pin. (Vanilla-typed Forge members reference notch classes in
#     the universal, which is why forge/ compiles against stubs, not it.)
pin_uni 'net.minecraftforge.fml.common.gameevent.TickEvent$WorldTickEvent' 'world'
pin_uni 'net.minecraftforge.fml.common.gameevent.TickEvent$ClientTickEvent' 'ClientTickEvent('
pin_uni 'net.minecraftforge.fml.common.gameevent.TickEvent$ServerTickEvent' 'ServerTickEvent('
pin_uni 'net.minecraftforge.common.MinecraftForge' 'EVENT_BUS'
pin_uni 'net.minecraftforge.fml.common.gameevent.TickEvent' 'side'
pin_uni 'net.minecraftforge.fml.common.gameevent.TickEvent' 'phase'
pin_uni 'net.minecraftforge.fml.common.gameevent.TickEvent$Phase' 'END'
pin_uni 'net.minecraftforge.fml.relauncher.Side' 'SERVER'
pin_uni 'net.minecraftforge.fml.common.Mod' 'modid()'
pin_uni 'net.minecraftforge.fml.common.FMLCommonHandler' 'instance()'
pin_uni 'net.minecraftforge.fml.common.FMLCommonHandler' 'bus()'
pin_uni 'net.minecraftforge.fml.common.eventhandler.EventBus' 'register('
pin_uni 'net.minecraftforge.fml.common.event.FMLPreInitializationEvent' 'FMLPreInitializationEvent('
pin_uni 'net.minecraftforge.fml.common.Mod$EventBusSubscriber' 'modid()'
pin_uni 'net.minecraftforge.event.RegistryEvent$Register' 'getRegistry('
pin_uni 'net.minecraftforge.registries.IForgeRegistry' 'register('
pin_uni 'net.minecraftforge.registries.IForgeRegistryEntry' 'setRegistryName('
pin_uni 'net.minecraftforge.event.world.BlockEvent' 'getWorld('
pin_uni 'net.minecraftforge.event.world.BlockEvent' 'getPos('
pin_uni 'net.minecraftforge.event.world.BlockEvent' 'getState('
pin_uni 'net.minecraftforge.event.world.BlockEvent$BreakEvent' 'BreakEvent('
pin_uni 'net.minecraftforge.event.world.BlockEvent$HarvestDropsEvent' 'HarvestDropsEvent('
pin_uni 'net.minecraftforge.event.entity.living.LivingEvent' 'getEntityLiving('
pin_uni 'net.minecraftforge.event.entity.living.LivingDropsEvent' 'LivingDropsEvent('
pin_uni 'net.minecraftforge.event.entity.living.LivingHurtEvent' 'LivingHurtEvent('
pin_uni 'net.minecraftforge.event.entity.living.LivingHurtEvent' 'getSource('
pin_uni 'net.minecraftforge.event.entity.living.LivingHurtEvent' 'getAmount('
pin_uni 'net.minecraftforge.event.entity.living.LivingHurtEvent' 'setAmount('
pin_uni 'net.minecraftforge.event.entity.EntityJoinWorldEvent' 'EntityJoinWorldEvent('
pin_uni 'net.minecraftforge.event.entity.EntityJoinWorldEvent' 'getWorld('
pin_uni 'net.minecraftforge.event.entity.EntityEvent' 'getEntity('
pin_uni 'net.minecraftforge.fml.common.eventhandler.Event' 'setCanceled('
# Custom entity tranche (hub decisions/SPAWN.md): the generic beast
# registers through EntityRegistry (registry name first on 1.12, never
# the 1.7.10 call shape), the init-time tripwire reads it back, the
# client-only renderer rides the IRenderFactory path (the single
# (RenderManager) pig ctor, measured from the pinned client jar), and
# the side guard keeps the mapping off dedicated servers. Forge names
# are runtime-final: presence is the pin.
pin_uni 'net.minecraftforge.fml.common.registry.EntityRegistry' 'registerModEntity('
pin_uni 'net.minecraftforge.fml.common.registry.EntityRegistry' 'lookupModSpawn('
pin_uni 'net.minecraftforge.fml.client.registry.RenderingRegistry' 'registerEntityRenderingHandler('
pin_uni 'net.minecraftforge.fml.client.registry.IRenderFactory' 'createRenderFor('
pin_uni 'net.minecraftforge.fml.common.FMLCommonHandler' 'getSide('
echo "ok c3-live : forge stubs pinned to universal"

# 3. Build all mod jars with Java 8. forge/ compiles against the pinned
#    stubs (vanilla shape + Forge shape); the live run is the semantic arbiter.
#    R2: jar entries are sorted with timestamps clamped to EPOCH (same
#    commit + same toolchain == same bytes, see normjar), manifests carry
#    VERSION, the bridge jar embeds mcmod.info.
#    These are the exact bytes the live run proves AND the release ships.
#    Bridge-owned pure (java/src: spike store/seal, loot store/seal,
#    spawn store/seal, operator policy) compiles beside the seam and
#    stages into the forge classes (same shape as 1710: java/ ships
#    inside the bridge jar, never standalone).
BLD="$C3_DIR/build"
rm -rf "$BLD" \
  || { echo "FAIL c3-live : cannot clear <$BLD> (root-owned docker leftovers? point C3_DIR at a user-owned dir)"; exit 1; }
mkdir -p "$BLD/spi" "$BLD/ex1" "$BLD/mini" "$BLD/bridge" "$BLD/forge" "$BLD/jars"
"$J8/javac" -source 8 -target 8 -nowarn -d "$BLD/spi" $(find ../spi/java/src -name '*.java')
"$J8/javac" -source 8 -target 8 -nowarn -cp "$BLD/spi" -d "$BLD/ex1" $(find ../example1/java/src -name '*.java')
"$J8/javac" -source 8 -target 8 -nowarn -cp "$BLD/spi" -d "$BLD/mini" $(find ../minimap/java/src -name '*.java')
"$J8/javac" -source 8 -target 8 -nowarn -cp "$BLD/spi:$BLD/ex1" -d "$BLD/bridge" $(find java/src -name '*.java')
"$J8/javac" -source 8 -target 8 -nowarn -cp "$BLD/spi:$BLD/ex1:$BLD/bridge" -d "$BLD/forge" $(find tools/live/stub forge/src -name '*.java')
# @SideOnly must survive into RuntimeVisibleAnnotations on the exact
# compiled bytes: Forge strips client-only methods on dedicated servers
# only when the annotation is runtime-visible (real SideOnly is RUNTIME,
# measured by javap on the pinned 2860 bytes). A stub without retention
# compiles it invisible, the strip silently misses, and mod load dies
# resolving client classes (NoClassDefFoundError — found live on 1710 T4
# bytes, never again silently; hub decisions/SPAWN.md). javap -v names
# the block, never the pool ref.
"$J8/javap" -v -p -cp "$BLD/forge" fr.iamacat.bridge.forge.Example1Mod > "$BLD/sideonly-javap.txt"
python3 - "$BLD/sideonly-javap.txt" <<'EOF'
import sys
txt = open(sys.argv[1]).read()
i = txt.find("registerBeastRenderer();")
if i < 0:
    print("FAIL c3-live : registerBeastRenderer absent from javap")
    sys.exit(1)
block = txt[i:i + 4000]
j = block.find("RuntimeVisibleAnnotations")
k = block.find("RuntimeInvisibleAnnotations")
if j < 0 or (k >= 0 and k < j):
    print("FAIL c3-live : @SideOnly invisible on registerBeastRenderer (server strip would miss it)")
    sys.exit(1)
print("ok c3-live : SideOnly runtime-visible on registerBeastRenderer")
EOF
# Bridge-owned pure stages into the forge classes (ships in the bridge jar).
cp -r "$BLD/bridge/"* "$BLD/forge/"
EPOCH="${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct)}"
printf 'Manifest-Version: 1.0\nImplementation-Version: %s\n' "$VERSION" > "$BLD/MANIFEST.MF"
cat > "$BLD/mcmod.info" <<EOF
[{"modid": "matoubridge", "name": "MatouBridge", "description": "SPI bridge for Minecraft 1.12.2 (reobfuscated SRG).", "version": "$VERSION", "mcversion": "1.12.2", "authorList": ["matou-dev"], "url": "https://github.com/matou-dev/bridge-1122"}, {"modid": "example1", "name": "MatouExample1", "description": "Example1 content: registers example1 blocks (registry event) + the generic beast for the bridge wire.", "version": "$VERSION", "mcversion": "1.12.2", "authorList": ["matou-dev"], "url": "https://github.com/matou-dev/example1"}]
EOF
find "$BLD/spi" "$BLD/ex1" "$BLD/mini" "$BLD/forge" "$BLD/MANIFEST.MF" "$BLD/mcmod.info" -exec touch -h -d "@$EPOCH" {} +
mkjar "$BLD/jars/matou-spi.jar" "$BLD/spi"
mkjar "$BLD/jars/matou-example1.jar" "$BLD/ex1"
mkjar "$BLD/jars/matou-minimap.jar" "$BLD/mini"
rm -rf "$BLD/bridgemod" && mkdir -p "$BLD/bridgemod"
cp -r "$BLD/forge/"* "$BLD/bridgemod/"
# Stubs are compile-only: they must never ship (a fake Block on the
# runtime classpath would shadow vanilla). Refuse loudly if leaked.
rm -rf "$BLD/bridgemod/net" "$BLD/bridgemod/org"
if [ -e "$BLD/bridgemod/net" ] || [ -e "$BLD/bridgemod/org" ]; then
  echo "FAIL c3-live : stub leak into mod jar"
  exit 1
fi
cp "$BLD/mcmod.info" "$BLD/bridgemod/mcmod.info"
touch -h -d "@$EPOCH" "$BLD/bridgemod/mcmod.info"
mkjar "$BLD/jars/matoubridge.jar" "$BLD/bridgemod"
echo "ok c3-live : jars built (VERSION=$VERSION)"

# 3b. Narrow-map coverage: every net/minecraft/* member the built MCP jar
#     references must resolve in the derived map. Reobf passes unmapped
#     names through silently, so an uncovered ref dies linking live (the
#     visual tranche found the first RenderWorldLastEvent crashing on
#     unmapped getMinecraft — the map covered server refs only, and the
#     step-2 comment claiming full coverage had no check behind it). The
#     walk mirrors Reobf.walk exactly (in-jar superclass chain, fields by
#     name): <init>/<clinit> never rename, Forge/LWJGL owners pass through
#     by design, so neither is asserted. ALLOW is Forge-added runtime-final
#     (MCP name at runtime — the registration paths execute every server
#     run, and 2b refuses these names IN the map).
python3 - "$BLD/jars/matoubridge.jar" "$SRG_NARROW" <<'EOF'
import struct, sys, zipfile
jar, mapf = sys.argv[1:3]
methods, fields = set(), set()
for raw in open(mapf):
    t = raw.split()
    if not t:
        continue
    if t[0] == "MD:":
        own, name = t[3].rsplit("/", 1)
        methods.add((own, name, t[4]))
    elif t[0] == "FD:":
        own, name = t[2].rsplit("/", 1)
        fields.add((own, name))
ALLOW = {
    ("net/minecraft/world/WorldProvider", "getDimension"),
    ("net/minecraft/block/Block", "setRegistryName"),
    ("net/minecraft/item/Item", "setRegistryName"),
}
def u(pool, i):
    return pool[i][1].decode("utf-8")
def parse(data):
    assert data[:4] == b"\xca\xfe\xba\xbe", "E_MAP_COVER:not a class"
    n = struct.unpack(">H", data[8:10])[0]
    pool = [None] * n
    i, p = 1, 10
    while i < n:
        tag = data[p]
        p += 1
        if tag == 1:
            ln = struct.unpack(">H", data[p:p + 2])[0]
            pool[i] = (tag, data[p + 2:p + 2 + ln])
            p += 2 + ln
        elif tag in (7, 8, 16, 19, 20):
            pool[i] = (tag, struct.unpack(">H", data[p:p + 2])[0])
            p += 2
        elif tag in (9, 10, 11, 12, 17, 18):
            pool[i] = (tag, struct.unpack(">H", data[p:p + 2])[0],
                       struct.unpack(">H", data[p + 2:p + 4])[0])
            p += 4
        elif tag == 15:
            p += 3
        elif tag in (3, 4):
            p += 4
        elif tag in (5, 6):
            p += 8
            i += 1
        else:
            raise AssertionError("E_MAP_COVER:bad tag %d" % tag)
        i += 1
    this_idx = struct.unpack(">H", data[p + 2:p + 4])[0]
    super_idx = struct.unpack(">H", data[p + 4:p + 6])[0]
    this_name = u(pool, pool[this_idx][1])
    super_name = u(pool, pool[super_idx][1]) if super_idx else None
    refs = []
    for e in pool[1:]:
        if e is None or e[0] not in (9, 10, 11):
            continue
        owner = u(pool, pool[e[1]][1])
        _, ni, di = pool[e[2]]
        refs.append((owner, u(pool, ni), u(pool, di), e[0] == 9))
    return this_name, super_name, refs
z = zipfile.ZipFile(jar)
supers, allrefs = {}, []
for info in z.infolist():
    if not info.filename.endswith(".class"):
        continue
    this_name, super_name, refs = parse(z.read(info.filename))
    supers[this_name] = super_name
    allrefs.extend(refs)
missing = []
for owner, name, desc, is_field in allrefs:
    if not owner.startswith("net/minecraft/") or name in ("<init>", "<clinit>"):
        continue
    o, hit = owner, False
    while o is not None:
        if is_field:
            if (o, name) in fields:
                hit = True
                break
        elif (o, name, desc) in methods:
            hit = True
            break
        o = supers.get(o)
    if not hit and (owner, name) not in ALLOW:
        missing.append("%s %s %s %s" % ("FD" if is_field else "MD", owner, name, desc))
assert not missing, "E_MAP_COVER:unmapped vanilla refs:\n%s" % "\n".join(sorted(set(missing)))
print("ok c3-live : narrow map covers forge refs")
EOF
echo "ok c3-live : narrow map covers forge refs"

# 4. Reobfuscate MCP-named refs to SRG (ForgeGradle reobf equivalent:
#    runtime vanilla only declares SRG names, so un-reobfed jars die with
#    NoSuchMethodError — found live in B3, never again silently).
#    getDimension passes through untouched (Forge-added, runtime-final).
"$J8/javac" -cp "$ASM" -d "$BLD" tools/live/Reobf.java
"$J8/java" -cp "$BLD:$ASM" Reobf "$SRG_NARROW" "$BLD/jars/matoubridge.jar" "$BLD/jars/matoubridge-reobf.jar"
normjar "$BLD/jars/matoubridge-reobf.jar"
echo "ok c3-live : bridge reobfuscated"

# Dual-runtime contract (Java 8 vanilla + modern JVM via lwjgl3ify):
# shipped bytes stay major 52 with no module-info and no multi-release
# entries — v52 loads on 8 and 21 alike. Anything newer fails loudly here,
# on both the live and the release path, never silently.
python3 - "$BLD/jars" <<'EOF'
import sys, zipfile, struct
jars = ["matou-spi.jar", "matou-example1.jar", "matou-minimap.jar",
        "matoubridge-reobf.jar"]
bad = []
for j in jars:
    zf = zipfile.ZipFile("%s/%s" % (sys.argv[1], j))
    for n in zf.namelist():
        if n == "module-info.class" or n.startswith("META-INF/versions/"):
            bad.append("%s!%s (multi-release)" % (j, n))
        elif n.endswith(".class"):
            major = struct.unpack(">H", zf.read(n)[6:8])[0]
            if major != 52:
                bad.append("%s!%s (major %d, want 52)" % (j, n, major))
if bad:
    print("FAIL c3-live : java-52 contract broken:")
    print("\n".join("  " + b for b in bad))
    sys.exit(1)
print("ok c3-live : java 52 contract (4 jars, no multi-release)")
EOF

# R2 release assembly: versioned server drop, then exit before booting.
# The MCP-named bridge jar never ships (only the reobf one is copied).
if [ "${BUILD_ONLY:-}" = "1" ]; then
  rm -rf dist && mkdir -p dist/matou-content
  cp "$BLD/jars/matou-spi.jar" "dist/matou-spi-$VERSION.jar"
  cp "$BLD/jars/matou-example1.jar" "dist/matou-example1-$VERSION.jar"
  cp "$BLD/jars/matou-minimap.jar" "dist/matou-minimap-$VERSION.jar"
  cp "$BLD/jars/matoubridge-reobf.jar" "dist/matoubridge-$VERSION.jar"
  cp ../example1/content/owned.matou ../example1/content/additive.matou ../example1/content/structure.matou ../example1/content/vein.matou dist/matou-content/
  cp tools/live/my_beast.geo.json dist/my_beast.geo.json
  cp tools/live/my_beast.png dist/my_beast.png
  printf '# Copy to <server>/config/matoubridge/packs.cfg and replace <SERVER>.\n# Wire y=63 keeps plane cells on their own slice, off the structure slices (64..65).\n# The wire block is the registered custom ore (registry event registers example1:my_ore from owned.matou); aliases stay vanilla stone.\n# Vein clusters land on the BASE_Y=60 band (slices 60..61) as the registered ore via the veinblock alias.\nfr.iamacat.example1.ExamplePack 63 example1:my_ore ownedFile=<SERVER>/matou-content/owned.matou scatterFile=<SERVER>/matou-content/additive.matou structureFile=<SERVER>/matou-content/structure.matou block.example1.structures:hut_wall=minecraft:stone block.example1.structures:hut_roof=minecraft:stone veinFile=<SERVER>/matou-content/vein.matou veinblock.example1.content:my_ore=example1:my_ore\n' > dist/packs.cfg.example
  (cd dist && sha256sum "matou-spi-$VERSION.jar" "matou-example1-$VERSION.jar" "matou-minimap-$VERSION.jar" "matoubridge-$VERSION.jar" matou-content/owned.matou matou-content/additive.matou matou-content/structure.matou matou-content/vein.matou packs.cfg.example my_beast.geo.json my_beast.png > SHA256SUMS.txt)
  (cd dist && sha256sum -c SHA256SUMS.txt)
  echo "ok r2-release : dist/ assembled (VERSION=$VERSION)"
  exit 0
fi

# 5. Deploy mods + content + packs.cfg, boot the server.
mkdir -p "$SERV/mods" "$SERV/config/matoubridge"
rm -f "$SERV/mods/"*.jar
cp "$BLD/jars/matou-spi.jar" "$BLD/jars/matou-example1.jar" "$BLD/jars/matoubridge-reobf.jar" "$SERV/mods/"
mv "$SERV/mods/matoubridge-reobf.jar" "$SERV/mods/matoubridge.jar"
rm -rf "$SERV/matou-content" && cp -r ../example1/content "$SERV/matou-content"
# Wire y=63: plane cells stay on their own slice, off the structure
# slices (64..65), so the verdict stays per-shape sensitive despite the
# set collapse (a 2D and a 3D cell can share x,z, never y). The wire
# block is the registered custom ore (preInit queues it from owned.matou,
# the registry event registers it before init binds resolve it). Vein
# clusters land on their own band (BASE_Y=60, slices 60..61) as the
# registered ore through the veinblock alias.
printf 'fr.iamacat.example1.ExamplePack 63 example1:my_ore ownedFile=%s/matou-content/owned.matou scatterFile=%s/matou-content/additive.matou structureFile=%s/matou-content/structure.matou block.example1.structures:hut_wall=minecraft:stone block.example1.structures:hut_roof=minecraft:stone veinFile=%s/matou-content/vein.matou veinblock.example1.content:my_ore=example1:my_ore\n' "$SERV" "$SERV" "$SERV" "$SERV" > "$SERV/config/matoubridge/packs.cfg"
# Beast shape: the shipped Blockbench geometry the renderer bakes and the
# hitboxes derive from (hub decisions/MATOU_MODEL.md). Deployed beside
# packs.cfg, operator-replaceable like it.
cp tools/live/my_beast.geo.json "$SERV/config/matoubridge/my_beast.geo.json"
# Beast texture: the shipped 64x64 skin the V2 renderer samples (hub
# decisions/MATOU_MODEL.md). Deployed beside the geometry,
# operator-replaceable like it.
cp tools/live/my_beast.png "$SERV/config/matoubridge/my_beast.png"
echo "eula=true" > "$SERV/eula.txt"
printf 'online-mode=false\nlevel-type=FLAT\ngamemode=1\ndifficulty=0\nmotd=C3 live proof\nmax-tick-time=-1\n' > "$SERV/server.properties"
rm -rf "$SERV/world" "$SERV/logs"
live_boot "$SERV" "$BOOT_SECS" "boot-c3.log" "$J8/java" -Xmx1G -jar "$UNI" nogui

# 6. Fail loudly on any runtime refusal or linkage error (stdout log plus
#    the rolling server log — FML splits output across both). E_MODEL rides
#    the grep: the model path is client-only, so any model refusal on the
#    server is a no-regression breach, never a silent pass (hub
#    decisions/MATOU_MODEL.md, server half of the live proof). E_HIT rides
#    it too: the combat hook refuses corrupt attacker state loudly out of
#    SPI (hub decisions/VIRTUAL_HITBOXES.md) — a NaN eye that passed would
#    mean a defaulted multiplier somewhere.
LOGS="$SERV/boot-c3.log"
[ -f "$SERV/logs/latest.log" ] && LOGS="$LOGS $SERV/logs/latest.log"
live_verdict "NoSuchMethodError\|NoSuchFieldError\|E_FORGE\|E_BRIDGE\|E_EXAMPLE\|E_REG\|E_LOOT\|E_SPAWN\|E_MODEL\|E_HIT\|Encountered an unexpected exception" "NoSuchMethodError\|NoSuchFieldError\|E_FORGE\|E_BRIDGE\|E_EXAMPLE\|E_REG\|E_LOOT\|E_SPAWN\|E_MODEL\|E_HIT\|Caused by" $LOGS

# 7. Positive proof: world blocks in chunks (0..1, -1..1) at y=60..61
#    plus y=63..65 must equal the pure decision union — nothing foreign,
#    nothing missing.
#    Plane cells land the wire block at y=63 (the registered custom ore,
#    whose runtime numeric ID is dynamic — resolved below from the init
#    registration line in the boot log, never hardcoded); volume cells
#    land at their own y=64..65 under their landable names (vanilla
#    stone, frozen ID 1); vein clusters land at their own y=60..61 as
#    the registered ore (dynamic ID, same table). Structure offsets reach
#    x,z=17, and the hut anchor z=-4 spills into chunk row -1 (region
#    r.0.-1.mca) — hence the 6-chunk, 5-slice read. (Same geometry as B3:
#    the mod writes force chunk generation around the origin regardless
#    of world spawn.)
"$J8/javac" -cp "$BLD/spi:$BLD/ex1" -d "$BLD" tools/live/CellUnion.java
"$J8/java" -cp "$BLD:$BLD/spi:$BLD/ex1" CellUnion \
  "$SERV/config/matoubridge/packs.cfg" 4000 "$BLD/union.txt"
ORE_ID=$(grep -a -o '\[MatouBridge\] registered <example1:my_ore> id [0-9][0-9]*' "$SERV/boot-c3.log" | tail -n 1 | grep -a -o '[0-9][0-9]*$' || true)
[ -n "$ORE_ID" ] || { echo "FAIL c3-live : my_ore registration line absent from boot log (registry event never registered? see $SERV/boot-c3.log)"; exit 1; }
echo "ok c3-live : my_ore id $ORE_ID (dynamic, from boot log)"
ITEM_ID=$(grep -a -o '\[MatouBridge\] registered-item <example1:my_gem> id [0-9][0-9]*' "$SERV/boot-c3.log" | tail -n 1 | grep -a -o '[0-9][0-9]*$' || true)
[ -n "$ITEM_ID" ] || { echo "FAIL c3-live : my_gem registration line absent from boot log (registry event never registered? see $SERV/boot-c3.log)"; exit 1; }
echo "ok c3-live : my_gem id $ITEM_ID (dynamic, from boot log)"
live_anvil_loop "$SERV" "$BLD"
live_compare_ids "$BLD/union.txt" "$BLD/world.txt" "$SERV/config/matoubridge/packs.cfg" "minecraft:stone=1,example1:my_ore=$ORE_ID"
