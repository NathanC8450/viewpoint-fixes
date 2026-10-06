package viewpointfixes;

import java.lang.reflect.Field;
import java.util.List;

/**
 * VPF-003 preview: a world item that is only ever drawn, never added to a square. Public because the patch's advice
 * is inlined into Viewpoint's Models class, which can only call public members.
 */
public final class Preview {
    private Preview() {}

    private static volatile Object preview; // zombie.iso.objects.IsoWorldInventoryObject
    private static Object previewItem; // the item it wraps, to notice when the cursor switches items
    private static boolean failed;
    private static Field modelItems; // viewpoint.core.Frame.modelItems

    /** Advice on viewpoint.models.Models.snapshot(Frame, int): draws the preview with this frame's world items. */
    @SuppressWarnings("unchecked")
    public static void add(Object frame) {
        Object p = preview;
        if (p == null || failed || frame == null) return;
        try {
            if (modelItems == null) modelItems = Reflect.type("viewpoint.core.Frame").getField("modelItems");
            ((List<Object>) modelItems.get(frame)).add(p);
        } catch (Throwable t) {
            failed = true;
            preview = null;
            Reflect.problem("preview off", t);
        }
    }

    /**
     * Shows `item` (a throwaway copy: the world-object constructor rewrites its rotation and container) at the
     * square plus offsets, until {@link #clear()}.
     */
    static boolean set(Object item, Object square, double xoff, double yoff, double zoff) {
        if (failed || item == null || square == null) return false;
        try {
            Object p = preview;
            Class<?> wio = Reflect.type("zombie.iso.objects.IsoWorldInventoryObject");
            if (p == null || previewItem != item || wio.getMethod("getSquare").invoke(p) != square) {
                // The constructor sets a random rotation on the item; keep the caller's.
                Class<?> inv = Reflect.type("zombie.inventory.InventoryItem");
                float rot = (Float) inv.getMethod("getWorldZRotation").invoke(item);
                p = wio.getConstructor(inv, Reflect.type("zombie.iso.IsoGridSquare"), float.class, float.class, float.class)
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
            failed = true;
            preview = null;
            Reflect.problem("preview off", t);
            return false;
        }
    }

    static void clear() {
        preview = null;
        previewItem = null;
    }
}
