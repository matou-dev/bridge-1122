package net.minecraft.item;

import net.minecraftforge.registries.IForgeRegistryEntry;

/** Loot and registration compile stub. Never runs. */
public class Item extends IForgeRegistryEntry.Impl<Item> {
    public Item setMaxStackSize(int maxStackSize) {
        return this;
    }

    public Item setUnlocalizedName(String unlocalizedName) {
        return this;
    }

    public static int getIdFromItem(Item item) {
        return 0;
    }

    public static Item getByNameOrId(String id) {
        return null;
    }
}
