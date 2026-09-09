package net.minecraftforge.fml.common;

import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;

/**
 * C1 compile stub: shape-only 1.12.2 Forge API used by {@code forge/}
 * sources. Never runs. Forge classes are never obfuscated, so member names
 * are final; tools/run-live.sh (C3) will assert their presence in the
 * provisioned 2860 jar — drift fails loudly.
 */
@Retention(RetentionPolicy.RUNTIME)
public @interface Mod {
    String modid();

    String name() default "";

    String version() default "";

    String acceptableRemoteVersions() default "";

    @Retention(RetentionPolicy.RUNTIME)
    @interface EventHandler {
    }
}
