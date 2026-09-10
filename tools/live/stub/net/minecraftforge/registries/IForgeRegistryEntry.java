package net.minecraftforge.registries;

import net.minecraft.util.ResourceLocation;

/**
 * C1 compile stub: the registration surface used by {@code forge/}.
 * Mirrors the real generic chain ({@code Block extends Impl<Block>} at
 * runtime) so {@code javac} emits erased descriptors — a concrete
 * {@code Block} return here would emit an unlinkable symbolic reference
 * (measured: NoSuchMethodError at the 1122 registry event).
 */
public interface IForgeRegistryEntry<V> {
    V setRegistryName(ResourceLocation name);

    class Impl<T extends IForgeRegistryEntry<T>>
            implements IForgeRegistryEntry<T> {
        public T setRegistryName(ResourceLocation name) {
            return null;
        }
    }
}
