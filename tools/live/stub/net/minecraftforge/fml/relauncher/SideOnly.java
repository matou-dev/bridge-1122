package net.minecraftforge.fml.relauncher;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Forge compile stub: shape-only 1.12.2 Forge API used by {@code forge/}
 * sources. Never runs (compile classpath only). Marks the beast renderer
 * mapping client-only so dedicated servers strip it at load instead of
 * resolving client classes — drift fails loudly.
 *
 * Retention mirrors the pinned 2860 bytes (RUNTIME + TYPE / FIELD /
 * METHOD / CONSTRUCTOR, verified by javap on the provisioned Forge
 * server jar): without it javac files the annotation invisible, Forge
 * strips visible annotations only, the method survives on dedicated
 * servers and mod load dies resolving client classes
 * (NoClassDefFoundError, found live on 1710 T4 bytes — hub
 * decisions/SPAWN.md). tools/run-live.sh locks the visibility on the
 * exact compiled bytes.
 */
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.TYPE, ElementType.FIELD, ElementType.METHOD,
        ElementType.CONSTRUCTOR})
public @interface SideOnly {
    Side value();
}
