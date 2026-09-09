# matou-dev/bridge-1122 — SPI ↔ Minecraft 1.12.2 translator

The only module allowed to touch MC/Forge 1.12.2 (Forge 14.23.5.2860) on
this side. Translates `matou-spi` into the game (world, registries).
Contamination forbidden: no import of the legacy `fr.iamacat.matoulib`
(`check` gate).

Modid: `matoubridge` (see hub `NAMES.md` — reused from `bridge-1710`,
safe: the two bridges never load in the same MC instance).

The decide/apply seam (`fr.iamacat.bridge`: `SpiBridge`, `CellSink`,
`ForgeCells`, `ForgeSnapshot`, `ForgeContent`, `Packs`) ships from
`matou-spi` v1.1.0 at identical FQNs — this repo carries only its Forge
side below. Pure coverage lives in SPI (`BridgeCheck`); content E2E
(`ForgeContentCheck` against `../example1`, same pattern as B2) is wired
in C2 below.

## C1 Forge wiring (Forge 14.23.5.2860)

Only `forge/` touches MC/Forge (1.12.2 deltas vs 1.7.10: `net.minecraftforge.fml`
packages, `World.setBlockState` + `BlockPos` + `IBlockState`,
`WorldProvider.getDimension()`, overworld y still `0..255`):

- `forge/src/fr/iamacat/bridge/forge`: `MatouBridgeMod`
  (`@Mod(modid="matoubridge")`, FML server tick `END` dim 0 → snapshot
  `matou:tick` → pure decide), `PackWire` (reflective bind + block
  resolve + y check, fail fast), `WorldCellSink` (`CellSink` into
  `setBlockState`, volume cells resolve their block by name, cached,
  unknown refused loudly). Passive until `packs.cfg` exists (Q1
  coexistence).
- `tools/live/stub`: shape-only 1.12.2 API used by `forge/` (compile
  classpath only, never runs). Etage 2 compiles `forge/` against it —
  green with no MC jars. `run-live.sh` (C3) asserts these members
  against the provisioned 2860 jars, as `bridge-1710` does for 1614.

Gate: `tools/check.sh` (etage 1 siblings-spi-ex1 compile + pure E2E,
etage 2 forge-vs-stub compile, etage 3 `LIVE=1` runs `tools/run-live.sh`).
`SPI_PIN` pins the validated SPI (hub `check-bridges.sh` refuses bridge
drift: pins, forge file-set, `E_FORGE_*` catalog).

## C2 content wiring (packs)

The bridge stays content-blind at build time (Q2): packs are discovered by
class name from `config/matoubridge/packs.cfg`
(`<class> <y> <block> [k=v ...]`, `#` comments, missing file = passive
like C1). Contract in `matou-spi` (`ContentPack` + optional
`ConfigurablePack`, public no-arg constructor); `ExamplePack` on the
example1 side (counts re-read from the `.matou` sources via the SPI parser,
never hardcoded).

- Pure, MC-free tested: `ForgeContent` (seal → decide → owned-first merge →
  apply) + `Packs` (strict config parse + reflective `load`) from the
  shared seam, E2E `java/test/.../ForgeContentCheck` (real example1 jobs
  from the source files + fake world; `ForgeContent.merge ==
  AdditiveScatterJob.merge` comparator; wired-pack decide keeps the legacy
  union first + 52 volume cells, and a 2D-only sink refuses the wired pack
  loudly). Body kept in sync with `bridge-1710`'s copy by convention.
- FML (`forge/`, MC only, ported in C1): `PackWire.bind` (load + configure
  + block + y `0..255`, fail fast at init), `MatouBridgeMod.onWorldTick`
  (server, `END`, dimension 0 → `applyTo`).

## C3 live proof (Forge 2860 server run)

Stage 2 compiles; only the game arbitrates runtime. C3 runs a real
2860 dedicated server with the built jars and compares the world against
the pure decision union — see `tools/run-live.sh` (manual gate, needs
network once + Java 8; env-driven, no machine paths: `C3_DIR` /
`JAVA8_HOME` / `BOOT_SECS` optional, `C3_OFFLINE=1` reuses cache).
Opt-in: `LIVE=1 ./tools/check.sh` runs the live proof after etages
1-2; default stays green without network / Java 8 (same skip pattern
as 1.7.10).

- 1.12.2 ships no `srg-mcp.srg`, so the reobf map derives inside the run
  instead of being pinned as a file: `joined.tsrg` (from the pinned MCP
  config) gives obf↔SRG per class, `javap` on the pinned vanilla server
  jar disambiguates overloads and static-ness (exactly-one assert per
  member). The map covers every vanilla member our `forge/` bytecode
  references (constant-pool truth at C3 time): `getBlockFromName` →
  `func_149684_b`, `getDefaultState` → `func_176223_P`, `setBlockState`
  → `func_175656_a`, `provider` → `field_73011_w`. `getDimension` stays
  unmapped on purpose: it is Forge-added (readable call sites in the
  pinned universal, e.g. `DimensionManager`), hence runtime-final —
  `Reobf` passes it through, and the verdict proves it behaviorally (a
  wrong dim gate would skip every tick and come back world-empty).
- Every stubbed Forge member is asserted in the provisioned universal
  jar; every derived SRG line is re-asserted before use. Upstream pins
  (installer / universal / vanilla server / MCP config / ASM sha1) fail
  the run loudly on any drift.
- The bridge jar is reobfuscated MCP→SRG (`tools/live/Reobf.java`, the
  ForgeGradle `reobf` equivalent): runtime vanilla only declares SRG
  names, so an un-reobfed jar dies linking (proven by constant-pool
  inspection: zero MCP names left, `func_*` present, `getDimension`
  untouched).
- Verdict: boot with zero `NoSuch*`/`E_*` refusals, then chunks (0..1, -1..1)
  at y=63..65 must equal the pure `ForgeContent.decideAll` union over the
  live `packs.cfg` — plane cells at the wire y=63, volume cells at their
  own y=64..65 (same per-shape-sensitive geometry as B3; the mod's writes
  force chunk generation around the origin regardless of world spawn) —
  stone only, nothing foreign, nothing missing (`tools/live/anvil.py`
  + `CellUnion`). Same 1274 cells as the 1614 proof: same content, same
  seam, second runtime.
- Reproducibility: `tools/live/Dockerfile` (JDK 8 + python3 + curl + git,
  non-root `builder` user), `C3_OFFLINE=1` cache reuse, `BUILD_ONLY=1
  VERSION=x.y.z` versioned server drop (`dist/`, same reproducible-jar
  path as the live run, `mcversion` 1.12.2). Jars stay Java 8 bytecode
  (major 52 contract enforced on both paths).
