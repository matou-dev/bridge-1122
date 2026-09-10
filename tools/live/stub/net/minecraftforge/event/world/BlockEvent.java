package net.minecraftforge.event.world;

import net.minecraft.block.state.IBlockState;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.World;

/**
 * Loot compile stub: 2860 BlockEvent carries world/pos/state (no x/y/z
 * ints — the 1.7.10 shape does not port). Only the members forge reads
 * are stubbed; the companion tranche grows the real event ctors. Never
 * runs.
 */
public class BlockEvent {
    public final World world;
    public final BlockPos pos;
    public final IBlockState state;

    protected BlockEvent(World world, BlockPos pos, IBlockState state) {
        this.world = world;
        this.pos = pos;
        this.state = state;
    }

    public static class HarvestDropsEvent extends BlockEvent {
        public HarvestDropsEvent(World world, BlockPos pos,
                IBlockState state) {
            super(world, pos, state);
        }
    }
}
