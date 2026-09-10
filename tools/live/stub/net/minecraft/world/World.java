package net.minecraft.world;

import java.util.List;
import net.minecraft.block.state.IBlockState;
import net.minecraft.entity.Entity;
import net.minecraft.entity.player.EntityPlayer;
import net.minecraft.util.math.BlockPos;

/**
 * C1 compile stub: shape-only 1.12.2 vanilla API used by {@code forge/}
 * sources. Never runs (compile classpath only). Every member is pinned to
 * 14.23.5.2860 by tools/run-live.sh (C3) before compiling — drift fails
 * loudly. The loot companion (tools/autoplay/) reads the extra members
 * below through this same stub (one class per FQN across both stub dirs).
 */
public class World {
    public WorldProvider provider;
    public boolean isRemote;
    public List<EntityPlayer> playerEntities;
    public List<Entity> loadedEntityList;

    public boolean setBlockState(BlockPos pos, IBlockState state) {
        return false;
    }

    public boolean isAirBlock(BlockPos pos) {
        return false;
    }

    public boolean setBlockToAir(BlockPos pos) {
        return false;
    }

    public boolean spawnEntity(Entity entity) {
        return false;
    }
}
