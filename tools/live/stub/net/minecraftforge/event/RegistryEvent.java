package net.minecraftforge.event;

import net.minecraftforge.registries.IForgeRegistry;
import net.minecraftforge.registries.IForgeRegistryEntry;

/** C1 compile stub: the registry-event surface used by {@code forge/}. */
public class RegistryEvent<T extends IForgeRegistryEntry<T>> {
    public static class Register<T extends IForgeRegistryEntry<T>>
            extends RegistryEvent<T> {
        public IForgeRegistry<T> getRegistry() {
            return null;
        }
    }
}
