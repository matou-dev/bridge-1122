package net.minecraft.entity;

import net.minecraft.entity.ai.attributes.IAttribute;

/**
 * Spawn compile stub: shape-only vanilla attribute holder used by the
 * spawn hp seam in forge/ (MatouBridgeMod lands the content hp on
 * maxHealth, hub decisions/SPAWN.md hp tranche). Never runs (compile
 * classpath only). Pinned to 14.23.5.2860 by tools/run-live.sh (SRG
 * field_111267_a, static — same stable name as the 1710 pin); drift
 * fails loudly on the owning side.
 *
 * <p>NEVER final on a field here: non-final statics read live, final
 * statics with initializers would fold the stub fiction into prod bytes
 * (same rule as the Entity stub, measured 2026-09-09 on 1710).
 */
public class SharedMonsterAttributes {
    public static IAttribute maxHealth;
}
