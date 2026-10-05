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

    /** The mod's "Debug logging" tickbox, mirrored from Lua. */
    static volatile boolean debug;

    // VPF-003: a preview-only world item shown at the place-item cursor.
    static volatile Object preview; // zombie.iso.objects.IsoWorldInventoryObject, never added to a square
    static volatile Object previewItem; // its item, to recognise it in renderMain
    private static boolean previewFailed;
    private static Field modelItems; // viewpoint.core.Frame.modelItems
    private static long lastAddLog, lastRenderLog, lastCaptureLog;
    private static int added;

    // VPF-003: the point under Viewpoint's crosshair.
    private static boolean aimFailed;
    private static Field aimAsk, aimHit; // viewpoint.render.MousePick.aim / aimHit
    private static Method hitAsk, hitX, hitY, hitZ;

    // VPF-003: raw key state (below Viewpoint's KeyboardState.isKeyDown patch).
    private static boolean rawFailed;
    private static Method rawKeyDown; // org.lwjglx.input.Keyboard.isKeyDown(int)

    private static final StringBuilder problems = new StringBuilder();

    static Class<?> type(String name) throws ClassNotFoundException {
        return Class.forName(name, false, ClassLoader.getSystemClassLoader());
    }

    static void log(String line) {
        System.out.println(LOG + line);
    }

    private static void problem(String what, Throwable t) {
        String line = what + ": " + t;
        log(line);
        if (problems.length() > 0) problems.append("; ");
        problems.append(line);
    }

    static String status() {
        return problems.length() == 0 ? "ok" : problems.toString();
    }

    // ---- VPF-003 preview ----

    /** Advice on viewpoint.models.Models.snapshot(Frame, int): draws the preview with this frame's world items. */
    @SuppressWarnings("unchecked")
    public static void addPreview(Object frame) {
        Object p = preview;
        if (p == null || previewFailed || frame == null) return;
        try {
            if (modelItems == null) modelItems = type("viewpoint.core.Frame").getField("modelItems");
            List<Object> items = (List<Object>) modelItems.get(frame);
            items.add(p);
            added++;
            if (debug && System.currentTimeMillis() - lastAddLog > 1000) {
                lastAddLog = System.currentTimeMillis();
                log("preview added to Viewpoint's world items (" + added + " frames so far, list size " + items.size() + ")");
            }
        } catch (Throwable t) {
            previewFailed = true;
            preview = null;
            problem("preview off", t);
        }
    }

    /** Debug advice on WorldItemModelDrawer.renderMain exit: what happened to the preview's draw. */
    public static void renderResult(Object item, Object status, Throwable thrown) {
        if (!debug || item == null || item != previewItem) return;
        if (thrown == null && System.currentTimeMillis() - lastRenderLog < 1000) return;
        lastRenderLog = System.currentTimeMillis();
        log("preview renderMain -> " + (thrown != null ? "threw " + thrown : status));
    }

    /** Debug advice on Viewpoint's RigidCapture.item exit: did it turn the preview's draw into a model? */
    public static void captureResult(Object item, boolean accepted, Throwable thrown) {
        if (!debug || item == null || item != previewItem) return;
        if (thrown == null && System.currentTimeMillis() - lastCaptureLog < 1000) return;
        lastCaptureLog = System.currentTimeMillis();
        log("preview RigidCapture.item -> " + (thrown != null ? "threw " + thrown : accepted));
    }

    /**
     * Shows `item` (a throwaway copy: the world-object constructor rewrites its rotation and container) at the
     * square plus offsets. The object is only handed to Viewpoint's draw list, never added to the square.
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
                if (debug) log("preview object made on " + square);
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

    // ---- VPF-003 aim ----

    /** Component 0/1/2 (x/y/z) of the world point under the crosshair, or null (cursor mode, nothing hit, error). */
    static Double aim(int axis) {
        if (aimFailed) return null;
        try {
            if (aimAsk == null) {
                Class<?> pick = type("viewpoint.render.MousePick");
                Class<?> hit = type("viewpoint.render.MousePick$Hit");
                aimHit = pick.getField("aimHit");
                hitAsk = hit.getMethod("ask");
                hitX = hit.getMethod("x");
                hitY = hit.getMethod("y");
                hitZ = hit.getMethod("z");
                aimAsk = pick.getField("aim");
            }
            Object ask = aimAsk.get(null);
            Object hit = aimHit.get(null);
            // Viewpoint's own check (CrosshairAim): the hit must answer the current request.
            if (ask == null || hit == null || hitAsk.invoke(hit) != ask) return null;
            Method m = axis == 0 ? hitX : axis == 1 ? hitY : hitZ;
            return (Double) m.invoke(hit);
        } catch (Throwable t) {
            aimFailed = true;
            problem("crosshair aim off", t);
            return null;
        }
    }

    // ---- VPF-003 keys ----

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
