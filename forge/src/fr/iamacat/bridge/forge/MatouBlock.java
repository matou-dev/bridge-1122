package fr.iamacat.bridge.forge;

import net.minecraft.block.Block;
import net.minecraft.block.material.Material;
import net.minecraft.block.state.IBlockState;

/**
 * Registration landing (see hub decisions/REGISTRATION.md): the one
 * generic Forge block every content block registers as. Physics lands
 * from the spec — hardness via the setter, opacity in a project-side
 * slot read by the override below — never hardcoded per content, never
 * a subclass per content, never a shadow field (no vanilla {@code
 * opaque} member exists on 1.12.2, so the project slot splits no
 * reader). The override declaration reobfuscates through the
 * superclass-chain walk (tools/live/Reobf.java), so it links as a true
 * override, never a silent overload. Only this package may touch {@code
 * net.minecraft} / {@code net.minecraftforge}.
 */
public final class MatouBlock extends Block {
    private final boolean opaque;

    /**
     * Args are pre-validated by the registering mod (E_REG_* owns the
     * refusals); the constructor only lands them.
     */
    public MatouBlock(float hardness, boolean opaque) {
        super(Material.ROCK);
        setHardness(hardness);
        this.opaque = opaque;
    }

    @Override
    public boolean isOpaqueCube(IBlockState state) {
        return opaque;
    }
}
