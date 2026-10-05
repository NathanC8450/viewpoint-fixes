package viewpointfixes;

import me.zed_0xff.zombie_buddy.Exposer;

/** Lua side: `ViewpointFixesJava.aimX()` etc. Used by the Lua fixes, which also own the toggles. */
@Exposer.LuaClass(name = "ViewpointFixesJava")
public final class Bridge {
    private Bridge() {}

    /** "ok", or what was switched off and why. */
    public static String status() {
        return Hooks.status();
    }

    /** World point under Viewpoint's crosshair, or nil (cursor mode, nothing under the crosshair). */
    public static Double aimX() {
        return Hooks.aim(0);
    }

    public static Double aimY() {
        return Hooks.aim(1);
    }

    /** Height in floor levels. */
    public static Double aimZ() {
        return Hooks.aim(2);
    }

    /** Shows `item` (a throwaway copy) at `square` + offsets until clearPreview. False if previews are off. */
    public static boolean setPreview(Object item, Object square, double xoff, double yoff, double zoff) {
        return Hooks.setPreview(item, square, xoff, yoff, zoff);
    }

    public static void clearPreview() {
        Hooks.clearPreview();
    }

    /** VPF-004 toggle. */
    public static void setItemRotation(boolean on) {
        Hooks.itemRotation = on;
    }
}
