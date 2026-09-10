package fr.iamacat.bridge.forge;

/**
 * Tranche-1 parity shell (see hub decisions/ITEM_REGISTRATION.md):
 * same basename as bridge-1710's generic MatouItem so hub
 * tools/check-bridges.sh holds its forge file-set. Never referenced by
 * this bridge's mod (no preInit registration yet) — this bridge's own
 * registration tranche rewrites it version-native and live-proves it.
 * Zero MC imports by design: compiles anywhere, ships nothing.
 */
public final class MatouItem {
    private MatouItem() {
        throw new AssertionError("E_REG_SHELL:unwired parity shell");
    }
}
