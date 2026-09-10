package net.minecraft.entity.ai.attributes;

/**
 * Spawn compile stub: shape-only vanilla attribute marker used by the
 * spawn hp seam in forge/ (MatouBridgeMod lands the content hp on the
 * beast's max-health attribute, hub decisions/SPAWN.md hp tranche).
 * Never runs (compile classpath only). An interface live (measured on
 * 1710: IncompatibleClassChangeError when stubbed as a class — loud,
 * never silent), so an interface here: the landing's invokeinterface
 * must link. Class names are identical in SRG and MCP, so no mapping is
 * ever needed.
 */
public interface IAttribute {
}
