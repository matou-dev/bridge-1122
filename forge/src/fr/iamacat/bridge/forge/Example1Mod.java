package fr.iamacat.bridge.forge;

/**
 * Tranche-1 parity shell (see hub decisions/REGISTRATION.md, Ports):
 * same basename as bridge-1710's example1 registration mod so hub
 * tools/check-bridges.sh holds its forge file-set. Never loaded by this
 * bridge (no second @Mod yet) — this bridge's own registration tranche
 * rewrites it version-native and live-proves it. Zero MC imports by
 * design: compiles anywhere, ships nothing.
 */
public final class Example1Mod {
    private Example1Mod() {
        throw new AssertionError("E_REG_SHELL:unwired parity shell");
    }
}
