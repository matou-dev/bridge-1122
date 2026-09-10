package fr.iamacat.bridge.forge;

/**
 * Tranche-1 parity shell (see hub decisions/SPAWN.md, custom entity
 * tranche): same basename as bridge-1710's generic MatouEntity so hub
 * tools/check-bridges.sh holds its forge file-set. Never referenced by
 * this bridge's mod (no entity registration yet) — this bridge's own
 * entity tranche rewrites it version-native and live-proves it. Zero MC
 * imports by design: compiles anywhere, ships nothing.
 */
public final class MatouEntity {
    private MatouEntity() {
        throw new AssertionError("E_REG_SHELL:unwired parity shell");
    }
}
