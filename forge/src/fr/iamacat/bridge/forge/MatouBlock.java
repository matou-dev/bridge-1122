package fr.iamacat.bridge.forge;

import net.minecraft.block.Block;
import net.minecraft.block.material.Material;

/**
 * Registration landing (see hub decisions/REGISTRATION.md): the one
 * generic Forge block every content block registers as. Hardness lands
 * via the setter — never hardcoded per content, never a subclass per
 * content. Opacity has no vanilla slot on 1.12.2 (no settable field,
 * and project-class method declarations pass the reobfuscator through
 * unrenamed, so an isOpaqueCube override would be a silent overload):
 * translucent specs refuse loudly at registration time, never default.
 * Only this package may touch {@code net.minecraft} /
 * {@code net.minecraftforge}.
 */
public final class MatouBlock extends Block {
    /**
     * Args are pre-validated by the registering mod (E_REG_* owns the
     * refusals); the constructor only lands them.
     */
    public MatouBlock(float hardness) {
        super(Material.ROCK);
        setHardness(hardness);
    }
}
