package viewpointfixes;

/**
 * Shared plumbing for the Java part. Everything in the game and in Viewpoint is reached by reflection (compiles with
 * JDK 17 against ZombieBuddy.jar alone, and stays harmless if Viewpoint changes): a lookup that fails switches that
 * feature off and is reported once through {@link #status()}.
 */
final class Reflect {
    private Reflect() {}

    private static final String LOG = "[ViewpointFixes] java: ";
    private static final StringBuilder problems = new StringBuilder();

    static Class<?> type(String name) throws ClassNotFoundException {
        return Class.forName(name, false, ClassLoader.getSystemClassLoader());
    }

    static void problem(String what, Throwable t) {
        String line = what + ": " + t;
        System.out.println(LOG + line);
        if (problems.length() > 0) problems.append("; ");
        problems.append(line);
    }

    /** "ok", or what was switched off and why. */
    static String status() {
        return problems.length() == 0 ? "ok" : problems.toString();
    }
}
