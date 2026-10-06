package viewpointfixes;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.List;

/**
 * State and logic behind the patches and the Lua bridge. Everything in the game and in Viewpoint is reached by
 * reflection (compiles with JDK 17 against ZombieBuddy.jar alone, and stays harmless if Viewpoint changes): a
 * lookup that fails switches that feature off and is reported once through {@link #status()}.
 */
public final class Hooks {
    private Hooks() {}

    private static final String LOG = "[ViewpointFixes] java: ";
    private static final StringBuilder problems = new StringBuilder();

    // VPF-003 preview: a world item that is only ever drawn, never added to a square.
    private static volatile Object preview; // zombie.iso.objects.IsoWorldInventoryObject
    private static Object previewItem; // the item it wraps, to notice when the cursor switches items
    private static boolean previewFailed;
    private static Field modelItems; // viewpoint.core.Frame.modelItems

    // VPF-003 aim: Viewpoint's depth-buffer picks (viewpoint.render.MousePick).
    private static boolean aimFailed;
    private static Field aimAsk, aimHit, cursorHit;
    private static Method hitAsk, hitX, hitY;

    // VPF-003 keys: the keyboard's own state, below Viewpoint's KeyboardState.isKeyDown patch.
    private static boolean rawFailed;
    private static Method rawKeyDown; // org.lwjglx.input.Keyboard.isKeyDown(int)

    static Class<?> type(String name) throws ClassNotFoundException {
        return Class.forName(name, false, ClassLoader.getSystemClassLoader());
    }

    private static void problem(String what, Throwable t) {
        String line = what + ": " + t;
        System.out.println(LOG + line);
        if (problems.length() > 0) problems.append("; ");
        problems.append(line);
    }

    /** "ok", or what was switched off and why. */
    static String status() {
        return problems.length() == 0 ? "ok" : problems.toString();
    }

    // ---- preview ----

    /** Advice on viewpoint.models.Models.snapshot(Frame, int): draws the preview with this frame's world items. */
    @SuppressWarnings("unchecked")
    public static void addPreview(Object frame) {
        Object p = preview;
        if (p == null || previewFailed || frame == null) return;
        try {
            if (modelItems == null) modelItems = type("viewpoint.core.Frame").getField("modelItems");
            ((List<Object>) modelItems.get(frame)).add(p);
        } catch (Throwable t) {
            previewFailed = true;
            preview = null;
            problem("preview off", t);
        }
    }

    /**
     * Shows `item` (a throwaway copy: the world-object constructor rewrites its rotation and container) at the
     * square plus offsets, until {@link #clearPreview()}.
     */
    static boolean setPreview(Object item, Object square, double xoff, double yoff, double zoff) {
        if (previewFailed || item == null || square == null) return false;
        try {
            Object p = preview;
            Class<?> wio = type("zombie.iso.objects.IsoWorldInventoryObject");
            if (p == null || previewItem != item || wio.getMethod("getSquare").invoke(p) != square) {
                // The constructor sets a random rotation on the item; keep the caller's.
                Class<?> inv = type("zombie.inventory.InventoryItem");
                float rot = (Float) inv.getMethod("getWorldZRotation").invoke(item);
                p = wio.getConstructor(inv, type("zombie.iso.IsoGridSquare"), float.class, float.class, float.class)
                        .newInstance(item, square, (float) xoff, (float) yoff, (float) zoff);
                inv.getMethod("setWorldZRotation", float.class).invoke(item, rot);
            }
            wio.getField("xoff").setFloat(p, (float) xoff);
            wio.getField("yoff").setFloat(p, (float) yoff);
            wio.getField("zoff").setFloat(p, (float) zoff);
            previewItem = item;
            preview = p;
            return true;
        } catch (Throwable t) {
            previewFailed = true;
            preview = null;
            problem("preview off", t);
            return false;
        }
    }

    static void clearPreview() {
        preview = null;
        previewItem = null;
    }

    // ---- aim ----

    private static void resolveAim() throws ReflectiveOperationException {
        if (aimAsk != null) return;
        Class<?> pick = type("viewpoint.render.MousePick");
        Class<?> hit = type("viewpoint.render.MousePick$Hit");
        aimHit = pick.getField("aimHit");
        cursorHit = pick.getField("hit");
        hitAsk = hit.getMethod("ask");
        hitX = hit.getMethod("x");
        hitY = hit.getMethod("y");
        aimAsk = pick.getField("aim");
    }

    /** Component 0/1 (x/y) of the world point under the crosshair, or null (cursor mode, nothing hit, error). */
    static Double aim(int axis) {
        if (aimFailed) return null;
        try {
            resolveAim();
            Object ask = aimAsk.get(null);
            Object hit = aimHit.get(null);
            // Viewpoint's own check (CrosshairAim): the hit must answer the current request.
            if (ask == null || hit == null || hitAsk.invoke(hit) != ask) return null;
            return (Double) (axis == 0 ? hitX : hitY).invoke(hit);
        } catch (Throwable t) {
            aimFailed = true;
            problem("crosshair aim off", t);
            return null;
        }
    }

    /**
     * Component 0/1 of Viewpoint's latest cursor pick (a depth readback a frame or two behind the mouse), or null.
     * Viewpoint's own Lua Mouse.worldX drops any pick more than 3 px from the pointer, so it is nil while the
     * mouse moves; for a moving preview a slightly late point is better than none.
     */
    static Double cursor(int axis) {
        if (aimFailed) return null;
        try {
            resolveAim();
            Object hit = cursorHit.get(null);
            return hit == null ? null : (Double) (axis == 0 ? hitX : hitY).invoke(hit);
        } catch (Throwable t) {
            aimFailed = true;
            problem("cursor aim off", t);
            return null;
        }
    }

    // ---- keys ----

    /** The keyboard's own state for `key`, before Viewpoint's KeyboardState.isKeyDown patch. */
    static boolean rawKeyDown(int key) {
        if (rawFailed || key <= 0) return false;
        try {
            if (rawKeyDown == null) rawKeyDown = type("org.lwjglx.input.Keyboard").getMethod("isKeyDown", int.class);
            return (Boolean) rawKeyDown.invoke(null, key);
        } catch (Throwable t) {
            rawFailed = true;
            problem("raw keys off", t);
            return false;
        }
    }
}
