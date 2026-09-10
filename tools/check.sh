#!/bin/sh
# Gate bridge-1122 : anti-contamination + contenu-wire + forge isole 1.12.2.
# Etage 1 (toujours vert, sans MC) : siblings ../spi + ../example1 presents
# + compile + E2E pur C2 (ForgeContentCheck, pattern B2 : packs issus des
# vrais .matou, monde fake enregistreur) + repop spike-repop (RepopCheck :
# MinedStore/RepopSeal contre RepopJob, pattern 1710) + loot spike-loot
# (LootCheck : DropStore/LootSeal/OperatorPolicy contre
# LootJob/LootTable, pattern 1710) + spawn spike-spawn (SpawnCheck : SpawnStore/SpawnSeal/OperatorPolicy
# contre SpawnJob/SpawnTable, pattern 1710).
# Le seam fr.iamacat.bridge vient de matou-spi v1.1.0, couvert par
# BridgeCheck cote SPI ; le pur bridge-owned (spike, loot, wire) vit dans
# java/src (zero-MC). Etage 2 (Forge 14.23.5.2860) : compile forge/ contre
# tools/live/stub (shape-only, jamais execute) — vert sans MC_JAR.
# Etage 3 (live, C3) : LIVE=1 runs tools/run-live.sh (needs Java 8 +
# network once, C3_OFFLINE=1 reuses cache), skip otherwise. Jamais de
# chemin machine en dur ici.
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
# Etage 1 : compile contre les checkouts siblings ../spi + ../example1
# (convention siblings, cf. hub README) + E2E pur C2. Refus bruyant.
SPI=../spi/java/src
[ -d "$SPI" ] || { echo "FAIL bridge-skeleton : spi sibling absent (cloner hub+spi+bridge-1122 en siblings)"; exit 1; }
EX1=../example1/java/src
[ -d "$EX1" ] || { echo "FAIL bridge-content : example1 sibling absent (cloner hub+spi+bridge-1122+example1 en siblings)"; exit 1; }
[ -f ../example1/content/owned.matou ] || { echo "FAIL bridge-content : example1 content absent"; exit 1; }
# SPI_PIN : ce bridge est valide contre ce SPI-la, pas un autre. Un sibling
# qui ne matche pas = bridge en avance/retard — re-valider puis bumper.
PIN=$(tr -d '[:space:]' < SPI_PIN)
[ -n "$PIN" ] || { echo "FAIL spi-pin : empty SPI_PIN"; exit 1; }
want=$(git -C ../spi rev-list -n 1 "$PIN" 2>/dev/null) || { echo "FAIL spi-pin : unknown pin <$PIN> (fetch tags?)"; exit 1; }
got=$(git -C ../spi rev-parse HEAD) || { echo "FAIL spi-pin : ../spi not a git checkout"; exit 1; }
[ "$want" = "$got" ] || { echo "FAIL spi-pin : want $PIN ($want), sibling $got (re-validate, then bump SPI_PIN)"; exit 1; }
echo "ok (spi-pin : $PIN)"
# C2 E2E pur : java/ ne touche jamais MC/Forge (ni 1.7.10 ni 1.12.2).
# Seuls les imports comptent : les commentaires peuvent les nommer.
# (net.minecraftforge.* matche deja net\.minecraft en prefixe, comme en 1710.)
mc_hits=$(rg -n --no-heading "^\s*import\s+(net\.minecraft|cpw\.mods)" \
  java --glob '!build/**' || true)
if [ -n "$mc_hits" ]; then
  echo "FAIL zero-mc-bridge :"
  echo "$mc_hits"
  exit 1
fi
echo "ok (zero-mc-bridge)"
# Les stubs ne tournent jamais (compile classpath only) — un final sur un
# primitif y est une constante compile-time que javac plie dans les bytes
# prod au lieu de lire le live (mesuré 2026-09-09 sur 1710 : event.x/y/z
# pliés à 0,0,0 dans le hook spike, attrapé live). Refus.
const_hits=$(rg -n --no-heading "final\s+(byte|short|int|long|float|double|boolean|char)\s+\w+\s*=" \
  tools/live/stub tools/autoplay/stub 2>/dev/null || true)
if [ -n "$const_hits" ]; then
  echo "FAIL no-stub-const :"
  echo "$const_hits"
  exit 1
fi
echo "ok (no-stub-const)"
# T3 registry gate, closed by T4 pack-driven (hub
# decisions/SPI_STATE_VOCABULARY.md): neither java/ nor forge/ knows any
# content by import — tables, jobs and kinds ride the SPI PolicyPack
# served by the reflectively loaded pack (AGENTS.md sect. 3). Seuls les
# imports comptent : les commentaires peuvent les nommer. Les tests
# gardent leurs imports (le comparateur lit les deux cotes).
ex1_hits=$(rg -n --no-heading "^\s*import\s+fr\.iamacat\.example1" \
  java/src forge/src || true)
if [ -n "$ex1_hits" ]; then
  echo "FAIL no-lateral-import :"
  echo "$ex1_hits"
  exit 1
fi
echo "ok (no-lateral-import)"
mkdir -p build/sib
javac --release 8 -d build/sib $(find "$SPI" "$EX1" java/src -name '*.java')
echo "ok (sib-spi-ex1-bridge)"
javac --release 8 -cp build/sib -d build/sib $(find java/test -name '*.java')
java -cp build/sib fr.iamacat.bridge.ForgeContentCheck
java -cp build/sib fr.iamacat.bridge.spike.RepopCheck
java -cp build/sib fr.iamacat.bridge.loot.LootCheck
java -cp build/sib fr.iamacat.bridge.spawn.SpawnCheck
# Etage 2 : forge/ seul touche MC/Forge (1.12.2). Stub shape-only, pas de
# MC_JAR requis : vert partout, le live C3 prouve contre le vrai jar
# (etage 3, LIVE=1).
# Clean before compile: javac never deletes stale classes, so a renamed or
# deleted source would linger in forge/build and lie to surface scans.
rm -rf forge/build && mkdir -p forge/build
javac --release 8 -cp build/sib -d forge/build $(find forge/src tools/live/stub -name '*.java')
echo "ok (forge-2860-stub)"
# Etage 3 (C3) : live opt-in. Default skip keeps CI green without
# network/Java 8; LIVE=1 fails loudly without them, never silently.
if [ "${LIVE:-}" != "1" ]; then
  echo "skip live (LIVE!=1)"
  exit 0
fi
exec sh tools/run-live.sh
