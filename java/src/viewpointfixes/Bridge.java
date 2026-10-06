package viewpointfixes;

import me.zed_0xff.zombie_buddy.Exposer;

/**
 * What the Lua fixes can call, as `ViewpointFixesJava.*` (nil when ZombieBuddy hasn't approved the jar). World
 * coordinates are tiles; every aim method returns nil when there is nothing to aim at.
 */
@Exposer.LuaClass(name = "ViewpointFixesJava")
public final class Bridge {
    private Bridge() {}

    /** "ok", or what was switched off and why. */
    public static String status() {
        return Hooks.status();
    }

    /** World point under Viewpoint's crosshair (crosshair mode only). */
    public static Double aimX() {
        return Hooks.aim(0);
    }

    public static Double aimY() {
        return Hooks.aim(1);
    }

    /** World point under the mouse cursor from Viewpoint's latest pick, which may lag a frame or two (cursor mode). */
    public static Double cursorX() {
        return Hooks.cursor(0);
    }

    public static Double cursorY() {
        return Hooks.cursor(1);
    }

    /** Shows `item` (a throwaway copy) at `square` + offsets until clearPreview. False if previews are off. */
    public static boolean setPreview(Object item, Object square, double xoff, double yoff, double zoff) {
        return Hooks.setPreview(item, square, xoff, yoff, zoff);
    }

    public static void clearPreview() {
        Hooks.clearPreview();
    }

    /** The keyboard's own state for a key code, before Viewpoint hides keys from the game. */
    public static boolean rawKeyDown(double key) {
        return Hooks.rawKeyDown((int) key);
    }
}
