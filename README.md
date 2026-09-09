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
(`ForgeContentCheck` pattern against `../example1`) follows in C2.

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

Gate: `tools/check.sh` (etage 1 sibling-spi compile, etage 2
forge-vs-stub compile, live skipped until C3). `SPI_PIN` pins the
validated SPI (hub `check-bridges.sh` refuses bridge drift: pins,
forge file-set, `E_FORGE_*` catalog).
