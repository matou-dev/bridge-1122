package net.minecraftforge.registries;

/** C1 compile stub: the registration surface used by {@code forge/}. */
public interface IForgeRegistry<V extends IForgeRegistryEntry<V>> {
    void register(V value);
}
