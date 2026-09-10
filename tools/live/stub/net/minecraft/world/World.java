package net.minecraft.world;

import net.minecraft.util.math.BlockPos;
import net.minecraft.block.state.IBlockState;
import net.minecraft.entity.Entity;

/**
 * C1 compile stub: shape-only 1.12.2 vanilla API used by {@code forge/}
 * sources. Never runs (compile classpath only). Every member is pinned to
 * 14.23.5.2860 by tools/run-live.sh (C3) before compiling — drift fails
 * loudly.
 */
public class World {
    public WorldProvider provider;
    public boolean isRemote;

    public boolean setBlockState(BlockPos pos, IBlockState state) {
        return false;
    }

    public boolean spawnEntity(Entity entity) {
        return false;
    }
}
