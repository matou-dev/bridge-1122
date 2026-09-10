package fr.iamacat.bridge.forge;

/**
 * Tranche-1 parity shell (see hub decisions/REGISTRATION.md, Ports):
 * same basename as bridge-1710's generic MatouBlock so hub
 * tools/check-bridges.sh holds its forge file-set. Never referenced by
 * this bridge's mod (no preInit registration yet) — this bridge's own
 * registration tranche rewrites it version-native and live-proves it.
 * Zero MC imports by design: compiles anywhere, ships nothing.
 */
public final class MatouBlock {
    private MatouBlock() {
        throw new AssertionError("E_REG_SHELL:unwired parity shell");
    }
}
