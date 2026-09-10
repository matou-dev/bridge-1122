package net.minecraft.util.math;

/** C1 compile stub, never runs (see Mod.java). Loot: inherits getX/getY/getZ
 * from Vec3i (the declaring type — forge reads coords through it). */
public class BlockPos extends Vec3i {
    public final int x;
    public final int y;
    public final int z;

    public BlockPos(int x, int y, int z) {
        this.x = x;
        this.y = y;
        this.z = z;
    }
}
