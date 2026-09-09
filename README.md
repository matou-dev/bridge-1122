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
  green with no MC jars. `run-live.sh` (C3) will assert these members
  in the provisioned 2860 jar, as `bridge-1710` does for 1614.

Gate: `tools/check.sh` (etage 1 siblings-spi-ex1 compile + pure E2E,
etage 2 forge-vs-stub compile, live skipped until C3). `SPI_PIN` pins the
validated SPI (hub `check-bridges.sh` refuses bridge drift: pins,
forge file-set, `E_FORGE_*` catalog).

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
