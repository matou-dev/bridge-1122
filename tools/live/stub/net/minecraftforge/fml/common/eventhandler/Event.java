package net.minecraftforge.fml.common.eventhandler;

/** Loot-companion compile stub: base type of posted events. The spawn
 * veto in forge/ cancels past-cap joins through setCanceled (Forge
 * class, never obfuscated — pinned by tools/run-live.sh). Never runs. */
public class Event {
    public void setCanceled(boolean cancel) {
    }

    public boolean isCanceled() {
        return false;
    }
}
