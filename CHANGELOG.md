# Changelog — matou-dev/bridge-1122

Notable changes to this repo. The bridge jar is the only loadable Forge
mod and it never ships alone: releases are versioned source + server drops
(`dist/`, reproducible). Store listings stay DRAFT (see hub `NAMES.md`).
Full notes per tag: https://github.com/matou-dev/bridge-1122/releases.

## [Unreleased]

- C1 scaffold: `forge/` ported to 1.12.2 (Forge 14.23.5.2860,
  `net.minecraftforge.fml`, `World.setBlockState` + `BlockPos` +
  `IBlockState`, `WorldProvider.getDimension()`), seam consumed from
  `matou-spi` v1.1.0 at identical FQNs (no pure copy here). Gate
  `tools/check.sh`: etage 1 sibling-spi compile, etage 2 forge-vs-stub
  compile green with no MC jars (live proof followed in C3).
- C2 content wiring: pure E2E `ForgeContentCheck` (same pattern as B2,
  body in sync with `bridge-1710`'s copy) against the `../example1`
  sibling (packs from the real `.matou` sources, fake recording world,
  merge comparator, wired-pack 52 volume cells, loud refusals). Gate
  etage 1 now requires the `../example1` sibling, enforces
  `zero-mc-bridge` on `java/`, and runs the E2E; CI checks out the
  `example1` sibling.
- C3 live proof: `tools/run-live.sh` (Forge 1.12.2-2860 dedicated server,
  `LIVE=1` opt-in from `tools/check.sh`, manual `live-proof` CI): narrow
  MCP→SRG map derived in-run from pinned bytes (no `srg-mcp.srg` on
  1.12.2), upstream sha1 pins (installer / universal / vanilla server /
  MCP config / ASM), reobf + java-52 contract, verdict world == pure
  union (1274 cells, stone only — same count as the 1614 proof).
  `getDimension` verified as Forge-added passthrough (readable call sites
  in the pinned universal, behavioral proof via the dim gate).
