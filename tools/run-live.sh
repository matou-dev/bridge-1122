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
# the 8-line narrow map derives deterministically from the pinned vanilla
# server + joined.tsrg (see step 2), so the pins below are the whole
# upstream surface.
set -eu
cd "$(dirname "$0")/.."
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
# 1a. C3_DIR preflight: docker runs leave root-owned leftovers (build/,
#     world/, logs/, matou-content/) that a host run cannot clear file by
#     file (rm needs write on the root-owned parent). Fail fast with the fix
#     instead of dying mid-run or reusing stale state silently.
if [ -e "$C3_DIR" ]; then
  BAD_OWNER=$(find "$C3_DIR" ! -user "$(id -un)" -print -quit 2>/dev/null || true)
  if [ -n "$BAD_OWNER" ]; then
    echo "FAIL c3-live : C3_DIR=<$C3_DIR> has non-owned leftovers (e.g. <$BAD_OWNER> from a docker run as root)"
    echo "fix: sudo rm -rf <$C3_DIR/build> <$C3_DIR/server/world> <$C3_DIR/server/logs> <$C3_DIR/server/matou-content> OR C3_DIR=/tmp/matou-c3-clean $0"
    exit 1
  fi
  if [ ! -w "$C3_DIR" ]; then
    echo "FAIL c3-live : C3_DIR=<$C3_DIR> not writable (fix ownership or point C3_DIR at a user-owned dir)"
    exit 1
  fi
fi
if [ ! -f "$C3_DIR/forge-installer.jar" ]; then
  if [ "${C3_OFFLINE:-}" = "1" ]; then
    echo "FAIL c3-live : offline and installer absent ($C3_DIR/forge-installer.jar)"
    exit 1
  fi
  curl -sL -o "$C3_DIR/forge-installer.jar" "$FORGE_URL" \
    || { echo "FAIL c3-live : installer download"; exit 1; }
fi
echo "$INSTALLER_SHA1  $C3_DIR/forge-installer.jar" | sha1sum -c - >/dev/null 2>&1 \
  || { echo "FAIL c3-live : installer sha1 drift (want $INSTALLER_SHA1)"; exit 1; }
UNI="$SERV/forge-1.12.2-14.23.5.2860.jar"
if [ ! -f "$UNI" ]; then
  (cd "$SERV" && "$J8/java" -jar "$C3_DIR/forge-installer.jar" --installServer >/dev/null 2>&1) \
    || { echo "FAIL c3-live : --installServer"; exit 1; }
fi
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
if [ ! -f "$C3_DIR/mcp_config-1.12.2.zip" ]; then
  if [ "${C3_OFFLINE:-}" = "1" ]; then
    echo "FAIL c3-live : offline and MCP config absent ($C3_DIR/mcp_config-1.12.2.zip)"
    exit 1
  fi
  curl -sL -o "$C3_DIR/mcp_config-1.12.2.zip" "$MCP_CONFIG_URL" \
    || { echo "FAIL c3-live : MCP config download"; exit 1; }
fi
echo "$MCP_CONFIG_SHA1  $C3_DIR/mcp_config-1.12.2.zip" | sha1sum -c - >/dev/null 2>&1 \
  || { echo "FAIL c3-live : MCP config sha1 drift (want $MCP_CONFIG_SHA1)"; exit 1; }
echo "ok c3-live : server provisioned (pins verified)"

# 2. Derive the narrow MCP->SRG map from pinned bytes (no srg-mcp.srg on
#    1.12.2): joined.tsrg gives obf<->SRG per class, the notch server jar
#    disambiguates overloads and static-ness via javap (exactly-one assert
#    per member, loud otherwise). The map covers every vanilla member our
#    forge/ bytecode references (verified by constant-pool scan at C3 time:
#    getBlockFromName, getDefaultState, setBlockState, provider, plus the
#    registration tranche: setHardness, getIdFromBlock, isOpaqueCube,
#    Material/ROCK, plus the loot tranche: spawnEntity, EntityItem/ItemStack
#    getItem, Items/diamond, Entity/world/posX/posY/posZ, World/isRemote,
#    IBlockState/getBlock, Vec3i/getX/getY/getZ).
#    WorldProvider.getDimension is NOT mapped on purpose: it is Forge-added
#    (11 readable call sites in the pinned universal, e.g. DimensionManager),
#    hence runtime-final — Reobf passes it through by design, and the live
#    verdict proves it behaviorally (a wrong dim gate skips every tick, so
#    the world would come back empty, never silently wrong).
python3 - "$C3_DIR/mcp_config-1.12.2.zip" "$MCSERV" "$J8/javap" "$C3_DIR/srg-narrow.srg" <<'EOF'
import re, subprocess, sys, zipfile
mcpcfg, server, javap, outpath = sys.argv[1:5]
tsrg = zipfile.ZipFile(mcpcfg).read("config/joined.tsrg").decode("utf-8")
# (owner_srg, mcp_name, desc_srg, kind, static?) — the full vanilla surface
# of forge/ (constant-pool truth, C3 time). Rows with a 6th element carry
# an SRG anchor (stable_39 names, de.oceanlabs.mcp:mcp_stable:39-1.12 on
# Forge Maven): several vanilla members share one descriptor (e.g.
# setHardness/setResistance, every Material field), so the anchor picks
# the intended one — an anchor missing from the pinned bytes fails loud.
WANT = [
    ("net/minecraft/block/Block", "getBlockFromName", "(Ljava/lang/String;)Lnet/minecraft/block/Block;", "method", True),
    ("net/minecraft/block/Block", "getDefaultState", "()Lnet/minecraft/block/state/IBlockState;", "method", False),
    ("net/minecraft/world/World", "setBlockState", "(Lnet/minecraft/util/math/BlockPos;Lnet/minecraft/block/state/IBlockState;)Z", "method", False),
    ("net/minecraft/world/World", "provider", "Lnet/minecraft/world/WorldProvider;", "field", False),
    ("net/minecraft/block/Block", "setHardness", "(F)Lnet/minecraft/block/Block;", "method", False, "func_149711_c"),
    ("net/minecraft/block/Block", "getIdFromBlock", "(Lnet/minecraft/block/Block;)I", "method", True, "func_149682_b"),
    ("net/minecraft/block/Block", "isOpaqueCube", "(Lnet/minecraft/block/state/IBlockState;)Z", "method", False, "func_149662_c"),
    ("net/minecraft/block/material/Material", "ROCK", "Lnet/minecraft/block/material/Material;", "field", True, "field_151576_e"),
    ("net/minecraft/world/World", "spawnEntity", "(Lnet/minecraft/entity/Entity;)Z", "method", False, "func_72838_d"),
    ("net/minecraft/entity/item/EntityItem", "getItem", "()Lnet/minecraft/item/Item;", "method", False, "func_92059_d"),
    ("net/minecraft/item/ItemStack", "getItem", "()Lnet/minecraft/item/Item;", "method", False, "func_77973_b"),
    ("net/minecraft/init/Items", "diamond", "Lnet/minecraft/item/Item;", "field", True, "field_151045_i"),
    ("net/minecraft/entity/Entity", "world", "Lnet/minecraft/world/World;", "field", False, "field_70170_p"),
    ("net/minecraft/entity/Entity", "posX", "D", "field", False, "field_70165_t"),
    ("net/minecraft/entity/Entity", "posY", "D", "field", False, "field_70165_u"),
    ("net/minecraft/entity/Entity", "posZ", "D", "field", False, "field_70165_v"),
    ("net/minecraft/world/World", "isRemote", "Z", "field", False, "field_72995_K"),
    ("net/minecraft/block/state/IBlockState", "getBlock", "()Lnet/minecraft/block/Block;", "method", False, "func_177230_c"),
    ("net/minecraft/util/math/Vec3i", "getX", "()I", "method", False, "func_177958_n"),
    ("net/minecraft/util/math/Vec3i", "getY", "()I", "method", False, "func_177956_o"),
    ("net/minecraft/util/math/Vec3i", "getZ", "()I", "method", False, "func_177952_p"),
]
srg2obf, classes = {}, {}
cur = None
for raw in tsrg.splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    if raw[0] in (" ", "\t"):
        classes.setdefault(cur, []).append(line.split())
    else:
        obf, srg = line.split()
        srg2obf[srg] = obf
        cur = srg

def obf_desc(d):
    return re.sub(r"L([^;]+);",
                  lambda m: "L" + srg2obf.get(m.group(1), m.group(1)) + ";", d)

# javap spells primitive field types by name (double, boolean, ...), never
# by descriptor char — the loot tranche pins Entity/posX (D) and
# World/isRemote (Z), so the field-type key maps single-char descriptors
# (object types keep the obf_desc path above).
PRIM = {"Z": "boolean", "B": "byte", "C": "char", "D": "double",
        "F": "float", "I": "int", "J": "long", "S": "short"}

def obf_ftype(d):
    if d in PRIM:
        return PRIM[d]
    return obf_desc(d)[1:-1]

def javap_flags(cls):
    # -> {(name, descriptor-or-F:type): is_static} from the notch server jar.
    out = subprocess.check_output([javap, "-p", "-s", "-cp", server, cls]).decode()
    res, name, static = {}, None, False
    for l in out.splitlines():
        s = l.strip()
        if s.startswith("descriptor:"):
            res[(name, s.split(None, 1)[1])] = static
        elif s and not s.startswith("Compiled"):
            m = re.match(r".*\s([\w$<>]+)\(", s)
            if m:
                static = bool(re.search(r"\bstatic\b", s.split("(")[0]))
                name = m.group(1)
            elif "(" not in s and s.endswith(";") and "{" not in s:
                m2 = re.match(r"(?:(.*)\s)?([\w.$\[\]<>, ]+?)\s+([\w$]+);", s)
                assert m2, "E_SRG_DERIVE:unparsed javap line <%s> in <%s>" % (s, cls)
                static = bool(re.search(r"\bstatic\b", m2.group(1) or ""))
                name = m2.group(3)
                res[(name, "F:" + re.sub(r"<.*>", "", m2.group(2)))] = static
    return res

lines = []
for row in WANT:
    owner, mcp, desc, kind, want_static = row[:5]
    anchor = row[5] if len(row) > 5 else None
    obf_owner = srg2obf[owner]
    members = classes[owner]
    if kind == "method":
        od = obf_desc(desc)
        cands = [(m[0], m[2]) for m in members if len(m) == 3 and m[1] == od]
        if anchor is not None:
            cands = [(n, s) for n, s in cands if s == anchor]
        assert cands, "E_SRG_DERIVE:no tsrg member <%s %s>" % (owner, mcp)
        flags = javap_flags(obf_owner)
        hits = [(n, s) for n, s in cands if flags.get((n, od)) == want_static]
        assert len(hits) == 1, "E_SRG_DERIVE:ambiguous <%s %s> %s" % (owner, mcp, hits)
        lines.append("MD: %s/%s %s %s/%s %s" % (owner, hits[0][1], desc, owner, mcp, desc))
    else:
        if anchor is not None:
            found = [m for m in members if len(m) == 2 and m[1] == anchor]
            assert len(found) == 1, "E_SRG_DERIVE:no tsrg field <%s %s>" % (owner, anchor)
            ftype_obf = obf_ftype(desc)
            flags = javap_flags(obf_owner)
            assert flags.get((found[0][0], "F:" + ftype_obf)) == want_static, \
                "E_SRG_DERIVE:field shape <%s %s>" % (owner, anchor)
            lines.append("FD: %s/%s %s/%s" % (owner, anchor, owner, mcp))
            continue
        ftype_obf = obf_ftype(desc)
        flags = javap_flags(obf_owner)
        flds = [n for (n, d), st in flags.items()
                if d == "F:" + ftype_obf and st == want_static]
        assert len(flds) == 1, "E_SRG_DERIVE:ambiguous field <%s %s> %s" % (owner, mcp, flds)
        hits = [m for m in members if len(m) == 2 and m[0] == flds[0]]
        assert len(hits) == 1, "E_SRG_DERIVE:no tsrg field <%s %s>" % (owner, mcp)
        lines.append("FD: %s/%s %s/%s" % (owner, hits[0][1], owner, mcp))
assert len(lines) == 21, "E_SRG_DERIVE:want 21 lines, got %d" % len(lines)
open(outpath, "w").write("\n".join(lines) + "\n")
print("ok c3-live : narrow SRG derived (%d lines)" % len(lines))
EOF
SRG_NARROW="$C3_DIR/srg-narrow.srg"
# 2b. Pin every derived line: a derivation the SRG does not confirm is a loud
#     failure, never a silent default. getDimension stays unmapped by design.
pin_method() {
  grep -q "^MD: [^ ]* [^ ]* $1 $2\$" "$SRG_NARROW" \
    || { echo "FAIL c3-live : stub member unpinned <$1 $2>"; exit 1; }
}
pin_field() {
  grep -q "^FD: [^ ]* $1\$" "$SRG_NARROW" \
    || { echo "FAIL c3-live : stub field unpinned <$1>"; exit 1; }
}
pin_method "net/minecraft/block/Block/getBlockFromName" "(Ljava/lang/String;)Lnet/minecraft/block/Block;"
pin_method "net/minecraft/block/Block/getDefaultState" "()Lnet/minecraft/block/state/IBlockState;"
pin_method "net/minecraft/world/World/setBlockState" "(Lnet/minecraft/util/math/BlockPos;Lnet/minecraft/block/state/IBlockState;)Z"
pin_method "net/minecraft/block/Block/setHardness" "(F)Lnet/minecraft/block/Block;"
pin_method "net/minecraft/block/Block/getIdFromBlock" "(Lnet/minecraft/block/Block;)I"
pin_method "net/minecraft/block/Block/isOpaqueCube" "(Lnet/minecraft/block/state/IBlockState;)Z"
pin_field "net/minecraft/world/World/provider"
pin_field "net/minecraft/block/material/Material/ROCK"
pin_method "net/minecraft/world/World/spawnEntity" "(Lnet/minecraft/entity/Entity;)Z"
pin_method "net/minecraft/entity/item/EntityItem/getItem" "()Lnet/minecraft/item/Item;"
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
grep -q "getDimension" "$SRG_NARROW" \
  && { echo "FAIL c3-live : getDimension must stay unmapped (Forge-added, runtime-final)"; exit 1; }
[ "$(grep -c . "$SRG_NARROW")" = "21" ] \
  || { echo "FAIL c3-live : narrow map drift (want 21 lines)"; exit 1; }
echo "ok c3-live : stubs pinned to derived SRG"

# 2c. Pin every stubbed Forge member against the provisioned 2860 universal.
#     Forge classes are never obfuscated, so names are final — presence is
#     the pin. (Vanilla-typed Forge members reference notch classes in
#     the universal, which is why forge/ compiles against stubs, not it.)
pin_uni() {
  "$J8/javap" -p -cp "$UNI" "$1" 2>/dev/null | grep -q "$2" \
    || { echo "FAIL c3-live : universal pin unmet <$1 :: $2>"; exit 1; }
}
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
pin_uni 'net.minecraftforge.event.world.BlockEvent' 'BlockPos pos'
pin_uni 'net.minecraftforge.event.world.BlockEvent' 'IBlockState state'
pin_uni 'net.minecraftforge.event.world.BlockEvent' 'World world'
pin_uni 'net.minecraftforge.event.world.BlockEvent$HarvestDropsEvent' 'HarvestDropsEvent('
pin_uni 'net.minecraftforge.event.entity.living.LivingEvent' 'getEntityLiving('
pin_uni 'net.minecraftforge.event.entity.living.LivingDropsEvent' 'LivingDropsEvent('
echo "ok c3-live : forge stubs pinned to universal"

# 3. Build all mod jars with Java 8. forge/ compiles against the pinned
#    stubs (vanilla shape + Forge shape); the live run is the semantic arbiter.
#    R2: jar entries are sorted with timestamps clamped to EPOCH (same
#    commit + same toolchain == same bytes, see normjar), manifests carry
#    VERSION, the bridge jar embeds mcmod.info.
#    These are the exact bytes the live run proves AND the release ships.
#    Bridge-owned pure (java/src: loot store/seal, operator policy) compiles
#    beside the seam and stages into the forge classes (same shape as 1710:
#    java/ ships inside the bridge jar, never standalone).
BLD="$C3_DIR/build"
rm -rf "$BLD" \
  || { echo "FAIL c3-live : cannot clear <$BLD> (root-owned docker leftovers? point C3_DIR at a user-owned dir)"; exit 1; }
mkdir -p "$BLD/spi" "$BLD/ex1" "$BLD/mini" "$BLD/forge" "$BLD/jars"
"$J8/javac" -source 8 -target 8 -nowarn -d "$BLD/spi" $(find ../spi/java/src -name '*.java')
"$J8/javac" -source 8 -target 8 -nowarn -cp "$BLD/spi" -d "$BLD/ex1" $(find ../example1/java/src -name '*.java')
"$J8/javac" -source 8 -target 8 -nowarn -cp "$BLD/spi" -d "$BLD/mini" $(find ../minimap/java/src -name '*.java')
"$J8/javac" -source 8 -target 8 -nowarn -cp "$BLD/spi:$BLD/ex1" -d "$BLD/bridge" $(find java/src -name '*.java')
"$J8/javac" -source 8 -target 8 -nowarn -cp "$BLD/spi:$BLD/ex1:$BLD/bridge" -d "$BLD/forge" $(find tools/live/stub forge/src -name '*.java')
# Bridge-owned pure stages into the forge classes (ships in the bridge jar).
cp -r "$BLD/bridge/"* "$BLD/forge/"
EPOCH="${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct)}"
printf 'Manifest-Version: 1.0\nImplementation-Version: %s\n' "$VERSION" > "$BLD/MANIFEST.MF"
cat > "$BLD/mcmod.info" <<EOF
[{"modid": "matoubridge", "name": "MatouBridge", "description": "SPI bridge for Minecraft 1.12.2 (reobfuscated SRG).", "version": "$VERSION", "mcversion": "1.12.2", "authorList": ["matou-dev"], "url": "https://github.com/matou-dev/bridge-1122"}, {"modid": "example1", "name": "MatouExample1", "description": "Example1 content: registers example1 blocks (registry event) for the bridge wire.", "version": "$VERSION", "mcversion": "1.12.2", "authorList": ["matou-dev"], "url": "https://github.com/matou-dev/example1"}]
EOF
find "$BLD/spi" "$BLD/ex1" "$BLD/mini" "$BLD/forge" "$BLD/MANIFEST.MF" "$BLD/mcmod.info" -exec touch -h -d "@$EPOCH" {} +
# mkjar: sorted entries, pinned mtimes, VERSION manifest. File lists stay
# explicit because jar -C . walks in readdir order (not reproducible).
# normjar then clamps every zip entry timestamp: the JDK 8 jar tool stamps
# META-INF entries with the wall clock (verified by diff), and Reobf does
# the same for its output. python3 is already a hard dependency (anvil).
# Scope: same commit + same toolchain == same bytes (zlib/JDK may vary
# across machines; use tools/live/Dockerfile to pin the toolchain).
normjar() {
  python3 - "$1" "$EPOCH" <<'EOF'
import sys, zipfile, datetime
path, epoch = sys.argv[1], int(sys.argv[2])
dt = datetime.datetime.utcfromtimestamp(epoch).timetuple()[:6]
zin = zipfile.ZipFile(path)
items = [(i, zin.read(i.filename)) for i in zin.infolist()]
zin.close()
zout = zipfile.ZipFile(path + ".norm", "w", zipfile.ZIP_DEFLATED)
for info, data in items:
    info.date_time = dt
    info.create_system = 0
    zout.writestr(info, data)
zout.close()
EOF
  mv "$1.norm" "$1"
}
mkjar() {
  out="$1"; stage="$2"
  files=$(cd "$stage" && find . -type f | LC_ALL=C sort)
  # Controlled tree, no spaces in class paths: word-splitting is intended.
  (cd "$stage" && "$J8/jar" cfm "$out" "$BLD/MANIFEST.MF" $files)
  normjar "$out"
}
mkjar "$BLD/jars/matou-spi.jar" "$BLD/spi"
mkjar "$BLD/jars/matou-example1.jar" "$BLD/ex1"
mkjar "$BLD/jars/matou-minimap.jar" "$BLD/mini"
rm -rf "$BLD/bridgemod" && mkdir -p "$BLD/bridgemod"
cp -r "$BLD/forge/"* "$BLD/bridgemod/"
# Stubs are compile-only: they must never ship (a fake Block on the
# runtime classpath would shadow vanilla). Refuse loudly if leaked.
rm -rf "$BLD/bridgemod/net"
if [ -e "$BLD/bridgemod/net" ]; then
  echo "FAIL c3-live : stub leak into mod jar"
  exit 1
fi
cp "$BLD/mcmod.info" "$BLD/bridgemod/mcmod.info"
touch -h -d "@$EPOCH" "$BLD/bridgemod/mcmod.info"
mkjar "$BLD/jars/matoubridge.jar" "$BLD/bridgemod"
echo "ok c3-live : jars built (VERSION=$VERSION)"

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
  printf '# Copy to <server>/config/matoubridge/packs.cfg and replace <SERVER>.\n# Wire y=63 keeps plane cells on their own slice, off the structure slices (64..65).\n# The wire block is the registered custom ore (registry event registers example1:my_ore from owned.matou); aliases stay vanilla stone.\n# Vein clusters land on the BASE_Y=60 band (slices 60..61) as the registered ore via the veinblock alias.\nfr.iamacat.example1.ExamplePack 63 example1:my_ore ownedFile=<SERVER>/matou-content/owned.matou scatterFile=<SERVER>/matou-content/additive.matou structureFile=<SERVER>/matou-content/structure.matou block.example1.structures:hut_wall=minecraft:stone block.example1.structures:hut_roof=minecraft:stone veinFile=<SERVER>/matou-content/vein.matou veinblock.example1.content:my_ore=example1:my_ore\n' > dist/packs.cfg.example
  (cd dist && sha256sum "matou-spi-$VERSION.jar" "matou-example1-$VERSION.jar" "matou-minimap-$VERSION.jar" "matoubridge-$VERSION.jar" matou-content/owned.matou matou-content/additive.matou matou-content/structure.matou matou-content/vein.matou packs.cfg.example > SHA256SUMS.txt)
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
echo "eula=true" > "$SERV/eula.txt"
printf 'online-mode=false\nlevel-type=FLAT\ngamemode=1\ndifficulty=0\nmotd=C3 live proof\nmax-tick-time=-1\n' > "$SERV/server.properties"
rm -rf "$SERV/world" "$SERV/logs"
set +e
(cd "$SERV" && timeout "$BOOT_SECS" "$J8/java" -Xmx1G -jar "$UNI" nogui > boot-c3.log 2>&1)
code=$?
set -e
[ "$code" -eq 124 ] || { echo "FAIL c3-live : server exited early (code $code, see $SERV/boot-c3.log)"; exit 1; }
echo "ok c3-live : server ran ($BOOT_SECS s)"

# 6. Fail loudly on any runtime refusal or linkage error (stdout log plus
#    the rolling server log — FML splits output across both).
LOGS="$SERV/boot-c3.log"
[ -f "$SERV/logs/latest.log" ] && LOGS="$LOGS $SERV/logs/latest.log"
if grep -a -q "NoSuchMethodError\|NoSuchFieldError\|E_FORGE\|E_BRIDGE\|E_EXAMPLE\|E_REG\|E_LOOT\|Encountered an unexpected exception" $LOGS; then
  echo "FAIL c3-live : runtime refusal (see $SERV/boot-c3.log)"
  grep -a -m5 "NoSuchMethodError\|NoSuchFieldError\|E_FORGE\|E_BRIDGE\|E_EXAMPLE\|E_REG\|E_LOOT\|Caused by" $LOGS
  exit 1
fi
grep -a -q "matoubridge" $LOGS \
  || { echo "FAIL c3-live : mod never loaded"; exit 1; }
echo "ok c3-live : bind clean, ticks clean"

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
: > "$BLD/world.txt"
for spec in "r.0.0.mca 0 0" "r.0.0.mca 1 0" "r.0.0.mca 0 1" \
    "r.0.0.mca 1 1" "r.0.-1.mca 0 -1" "r.0.-1.mca 1 -1"; do
  set -- $spec
  for y in 60 61 63 64 65; do
    python3 tools/live/anvil.py "$SERV/world/region/$1" "$2" "$3" "$y" \
      | awk -v cx="$2" -v cz="$3" -v y="$y" \
        '{split($1, a, ","); print (cx*16+a[1])" "y" "(cz*16+a[2])" "$2}' \
      >> "$BLD/world.txt"
  done
done
python3 - "$BLD/union.txt" "$BLD/world.txt" "$SERV/config/matoubridge/packs.cfg" "minecraft:stone=1,example1:my_ore=$ORE_ID" <<'EOF'
import sys
# Block names resolve to numeric IDs through the argv table (frozen
# vanilla IDs plus the dynamic custom IDs the shell resolved from the
# boot log) — never hardcoded, never guessed. A world name outside the
# table fails loudly (extend the table explicitly).
table = {}
for pair in sys.argv[4].split(","):
    name, num = pair.split("=", 1)
    table[name] = num
wire_y, wire_block = None, None
for line in open(sys.argv[3]):
    line = line.strip()
    if line and not line.startswith("#"):
        toks = line.split()
        wire_y, wire_block = int(toks[1]), toks[2]
if wire_y is None:
    print("FAIL c3-live : no wire in packs.cfg")
    sys.exit(1)
if wire_block not in table:
    print("FAIL c3-live : no numeric ID for wire block <%s>" % wire_block)
    sys.exit(1)
u = {}
for line in open(sys.argv[1]):
    cell = line.split()[0]
    parts = cell.split(",")
    if len(parts) == 3 and ":" in parts[2]:
        z, bname = parts[2].split(":", 1)
        pos = (int(parts[0]), int(parts[1]), int(z))
    else:
        x, z = cell.split(",")
        pos, bname = (int(x), wire_y, int(z)), wire_block
    if bname not in table:
        print("FAIL c3-live : no numeric ID for block <%s> (extend the table, never guess)" % bname)
        sys.exit(1)
    u[pos] = table[bname]
rows = [l.split() for l in open(sys.argv[2])]
w = {(int(x), int(y), int(z)): i for x, y, z, i in rows}
if not w:
    print("FAIL c3-live : world empty at y=60..61,63..65 (no tick applied?)")
    sys.exit(1)
if set(w.values()) - set(table.values()):
    print("FAIL c3-live : foreign block ids %s" % sorted(set(w.values()) - set(table.values())))
    sys.exit(1)
bad = {p: (w[p], u.get(p)) for p in w if u.get(p) != w[p]}
if bad:
    print("FAIL c3-live : id mismatch at %s (want pure union ids)" % sorted(bad.items())[:5])
    sys.exit(1)
if u.keys() - w.keys():
    print("FAIL c3-live : pure cells missing from world (%d)" % len(u.keys() - w.keys()))
    sys.exit(1)
print("ok c3-live : world == pure union (%d cells, ids %s)" % (len(w), sorted(set(w.values()))))
EOF
