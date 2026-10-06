package viewpointfixes;

import java.lang.reflect.Field;
import java.lang.reflect.Method;

/** Where the player is aiming, from Viewpoint's depth-buffer picks (viewpoint.render.MousePick). */
final class Aim {
    private Aim() {}

    private static boolean failed;
    private static Field aimAsk, aimHit, cursorHit;
    private static Method hitAsk, hitX, hitY;

    private static void resolve() throws ReflectiveOperationException {
        if (aimAsk != null) return;
        Class<?> pick = Reflect.type("viewpoint.render.MousePick");
        Class<?> hit = Reflect.type("viewpoint.render.MousePick$Hit");
        aimHit = pick.getField("aimHit");
        cursorHit = pick.getField("hit");
        hitAsk = hit.getMethod("ask");
        hitX = hit.getMethod("x");
        hitY = hit.getMethod("y");
        aimAsk = pick.getField("aim");
    }

    /** Component 0/1 (x/y) of the world point under the crosshair, or null (cursor mode, nothing hit, error). */
    static Double crosshair(int axis) {
        if (failed) return null;
        try {
            resolve();
            Object ask = aimAsk.get(null);
            Object hit = aimHit.get(null);
            // Viewpoint's own check (CrosshairAim): the hit must answer the current request.
            if (ask == null || hit == null || hitAsk.invoke(hit) != ask) return null;
            return (Double) (axis == 0 ? hitX : hitY).invoke(hit);
        } catch (Throwable t) {
            failed = true;
            Reflect.problem("crosshair aim off", t);
            return null;
        }
    }

    /**
     * Component 0/1 of Viewpoint's latest cursor pick (a depth readback a frame or two behind the mouse), or null.
     * Viewpoint's own Lua Mouse.worldX drops any pick more than 3 px from the pointer, so it is nil while the
     * mouse moves; for a moving preview a slightly late point is better than none.
     */
    static Double cursor(int axis) {
        if (failed) return null;
        try {
            resolve();
            Object hit = cursorHit.get(null);
            return hit == null ? null : (Double) (axis == 0 ? hitX : hitY).invoke(hit);
        } catch (Throwable t) {
            failed = true;
            Reflect.problem("cursor aim off", t);
            return null;
        }
    }
}
