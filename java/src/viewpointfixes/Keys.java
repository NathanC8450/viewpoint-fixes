package viewpointfixes;

import java.lang.reflect.Method;

/** The keyboard's own state, below Viewpoint's KeyboardState.isKeyDown patch (which hides keys from the game). */
final class Keys {
    private Keys() {}

    private static boolean failed;
    private static Method isKeyDown; // org.lwjglx.input.Keyboard.isKeyDown(int)

    static boolean rawDown(int key) {
        if (failed || key <= 0) return false;
        try {
            if (isKeyDown == null) isKeyDown = Reflect.type("org.lwjglx.input.Keyboard").getMethod("isKeyDown", int.class);
            return (Boolean) isKeyDown.invoke(null, key);
        } catch (Throwable t) {
            failed = true;
            Reflect.problem("raw keys off", t);
            return false;
        }
    }
}
