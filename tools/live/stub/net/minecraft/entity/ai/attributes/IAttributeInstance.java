package net.minecraft.entity.ai.attributes;

/**
 * Spawn compile stub: shape-only vanilla attribute instance used by the
 * spawn hp seam in forge/ (MatouBridgeMod lands the content hp through
 * setBaseValue, hub decisions/SPAWN.md hp tranche). Never runs (compile
 * classpath only). An interface live (measured on 1710:
 * IncompatibleClassChangeError when stubbed as a class — loud, never
 * silent), so an interface here: the landing's invokeinterface must
 * link. Pinned to 14.23.5.2860 by tools/run-live.sh (SRG
 * func_111128_a, same stable name as the 1710 pin); drift fails loudly
 * on the owning side.
 */
public interface IAttributeInstance {
    void setBaseValue(double value);

    double getBaseValue();
}
