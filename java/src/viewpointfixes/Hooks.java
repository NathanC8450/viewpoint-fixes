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

    // VPF-004: world items drawn with their own rotation (Viewpoint passes 0 = "forced unrotated").
    static volatile boolean itemRotation = true;
    private static boolean itemRotationFailed;
    private static Field capturing; // viewpoint.models.Models.capturing

    // VPF-003: a preview-only world item shown at the place-item cursor.
    static volatile Object preview; // zombie.iso.objects.IsoWorldInventoryObject, never added to a square
    private static boolean previewFailed;
    private static Field modelItems; // viewpoint.core.Frame.modelItems

    // VPF-003: the point under Viewpoint's crosshair.
    private static boolean aimFailed;
    private static Field aimAsk, aimHit; // viewpoint.render.MousePick.aim / aimHit
    private static Method hitAsk, hitX, hitY, hitZ;

    private static final StringBuilder problems = new StringBuilder();

    static Class<?> type(String name) throws ClassNotFoundException {
        return Class.forName(name, false, ClassLoader.getSystemClassLoader());
    }

    private static void problem(String what, Throwable t) {
        String line = what + ": " + t;
        System.out.println(LOG + line);
        if (problems.length() > 0) problems.append("; ");
        problems.append(line);
    }

    static String status() {
        return problems.length() == 0 ? "ok" : problems.toString();
    }

    // ---- VPF-004 ----

    /** Advice on WorldItemModelDrawer.renderMain(item, sq, sq, x, y, z, a, forcedRotation, extended). */
    public static float itemRotation(float forced, boolean extended) {
        if (!itemRotation || itemRotationFailed || forced != 0f || extended) return forced;
        try {
            if (capturing == null) capturing = type("viewpoint.models.Models").getField("capturing");
            // Only while Viewpoint is drawing a world item (Models.item): -1 = use the item's own rotation, as
            // vanilla IsoWorldInventoryObject does.
            return capturing.getBoolean(null) ? -1f : forced;
        } catch (Throwable t) {
            itemRotationFailed = true;
            problem("item rotation off", t);
            return forced;
        }
    }

    // ---- VPF-003 preview ----

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
     * square plus offsets. The object is only handed to Viewpoint's draw list, never added to the square.
     */
    static boolean setPreview(Object item, Object square, double xoff, double yoff, double zoff) {
        if (previewFailed || item == null || square == null) return false;
        try {
            Object p = preview;
            Class<?> wio = type("zombie.iso.objects.IsoWorldInventoryObject");
            if (p == null || wio.getMethod("getItem").invoke(p) != item || wio.getMethod("getSquare").invoke(p) != square) {
                float x = (float) xoff, y = (float) yoff, z = (float) zoff;
                p = wio.getConstructor(type("zombie.inventory.InventoryItem"), type("zombie.iso.IsoGridSquare"),
                        float.class, float.class, float.class).newInstance(item, square, x, y, z);
            }
            wio.getField("xoff").setFloat(p, (float) xoff);
            wio.getField("yoff").setFloat(p, (float) yoff);
            wio.getField("zoff").setFloat(p, (float) zoff);
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
}
