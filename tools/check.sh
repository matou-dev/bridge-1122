#!/bin/sh
# Gate bridge-1122 : anti-contamination + forge isole 1.12.2.
# Etage 1 (toujours vert, sans MC) : sibling ../spi present + compile (ce
# repo ne porte aucun java/ pur : le seam fr.iamacat.bridge vient de
# matou-spi v1.1.0, couvert par BridgeCheck cote SPI). Etage 2 (Forge
# 14.23.5.2860) : compile forge/ contre tools/live/stub (shape-only,
# jamais execute) — vert sans MC_JAR. Etage 3 (live, C3) : pas de
# tools/run-live.sh encore, skip. Jamais de chemin machine en dur ici.
set -eu
cd "$(dirname "$0")/.."
hits=$(rg -n --no-heading "fr\.iamacat\.matoulib" \
  --glob '!tools/**' --glob '!.git/**' --glob '!*.md' . || true)
if [ -n "$hits" ]; then
  echo "FAIL no-legacy-matoulib :"
  echo "$hits"
  exit 1
fi
echo "ok (no-legacy-matoulib)"
# Etage 1 : compile contre le checkout sibling ../spi (convention
# siblings, cf. hub README). Refus bruyant.
SPI=../spi/java/src
[ -d "$SPI" ] || { echo "FAIL bridge-skeleton : spi sibling absent (cloner hub+spi+bridge-1122 en siblings)"; exit 1; }
mkdir -p build/sib
javac --release 8 -d build/sib $(find "$SPI" -name '*.java')
echo "ok (sib-spi)"
# Etage 2 : forge/ seul touche MC/Forge (1.12.2). Stub shape-only, pas de
# MC_JAR requis : vert partout, le live C3 prouvera contre le vrai jar.
mkdir -p forge/build
javac --release 8 -cp build/sib -d forge/build $(find forge/src tools/live/stub -name '*.java')
echo "ok (forge-2860-stub)"
# Etage 3 (C3) : live opt-in, pas de harness encore.
echo "skip live (C3, no run-live.sh)"
