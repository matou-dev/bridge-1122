package net.minecraftforge.event.world;

import java.util.List;
import net.minecraft.block.state.IBlockState;
import net.minecraft.entity.player.EntityPlayer;
import net.minecraft.item.ItemStack;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.World;
import net.minecraftforge.fml.common.eventhandler.Event;

/**
 * Loot compile stub: 2860 BlockEvent carries private world/pos/state behind
 * public getters (measured via javap against the pinned 2860 universal —
 * the 1.7.10 public-field shape does not port; reading fields would die
 * linking at runtime). Only the members forge reads are stubbed; the
 * companion tranche grows the real event ctors. Never runs.
 */
public class BlockEvent extends Event {
    private final World world;
    private final BlockPos pos;
    private final IBlockState state;

    protected BlockEvent(World world, BlockPos pos, IBlockState state) {
        this.world = world;
        this.pos = pos;
        this.state = state;
    }

    public World getWorld() {
        return world;
    }

    public BlockPos getPos() {
        return pos;
    }

    public IBlockState getState() {
        return state;
    }

    /**
     * Repop spike: the bridge hook only reads world/pos/state through the
     * base getters (the 1.7.10 public-field shape does not port). The real
     * event ctor takes the joined player as 4th arg (measured via javap
     * against the pinned 2860 universal: BreakEvent(World, BlockPos,
     * IBlockState, EntityPlayer) — the 1.7.10 int-xyz shape does not
     * port; the ctor reads the player, so the companion post is
     * player-authored, never null). The harvest event below keeps the
     * same player-authored discipline.
     */
    public static class BreakEvent extends BlockEvent {
        private final EntityPlayer player;

        public BreakEvent(World world, BlockPos pos, IBlockState state,
                EntityPlayer player) {
            super(world, pos, state);
            this.player = player;
        }

        public EntityPlayer getPlayer() {
            return player;
        }
    }

    public static class HarvestDropsEvent extends BlockEvent {        public HarvestDropsEvent(World world, BlockPos pos,
                IBlockState state, int fortuneLevel, float dropChance,
                List<ItemStack> drops, EntityPlayer harvester,
                boolean isSilkTouching) {
            super(world, pos, state);
        }
    }
}
