package net.minecraft.block;

import net.minecraft.block.material.Material;
import net.minecraft.block.state.IBlockState;
import net.minecraftforge.registries.IForgeRegistryEntry;

/**
 * C1 compile stub: shape-only 1.12.2 vanilla API used by {@code forge/}
 * sources. Never runs (compile classpath only). Member names follow MCP
 * stable_39; tools/run-live.sh (C3) derives the MCP-&gt;SRG map from the
 * pinned bytes and refuses loud on drift.
 */
public class Block extends IForgeRegistryEntry.Impl<Block> {
    public Block(Material material) {
    }

    public static Block getBlockFromName(String name) {
        return null;
    }

    public static int getIdFromBlock(Block block) {
        return 0;
    }

    public IBlockState getDefaultState() {
        return null;
    }

    public boolean isOpaqueCube(IBlockState state) {
        return true;
    }

    public Block setHardness(float hardness) {
        return this;
    }
}
