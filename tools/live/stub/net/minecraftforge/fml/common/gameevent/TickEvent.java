package net.minecraftforge.fml.common.gameevent;

import net.minecraft.world.World;
import net.minecraftforge.fml.relauncher.Side;

/**
 * C1 compile stub, never runs (see Mod.java). Mirrors the 2860 shape:
 * side/phase live on the TickEvent parent, world on WorldTickEvent.
 */
public class TickEvent {
    public enum Type {
        WORLD, PLAYER, CLIENT, SERVER, RENDER
    }

    public enum Phase {
        START, END
    }

    public final Type type;
    public final Side side;
    public final Phase phase;

    public TickEvent(Type type, Side side, Phase phase) {
        this.type = type;
        this.side = side;
        this.phase = phase;
    }

    public static class WorldTickEvent extends TickEvent {
        public final World world;

        public WorldTickEvent(Side side, Phase phase, World world) {
            super(Type.WORLD, side, phase);
            this.world = world;
        }
    }
}
