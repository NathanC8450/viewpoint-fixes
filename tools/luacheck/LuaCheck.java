import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.stream.Stream;

// Syntax-checks Lua files with the game's own compiler (Kahlua), so it matches what PZ accepts.
// Uses reflection only, so it compiles with any JDK and runs on the game's bundled Java.
// Run through tools/luacheck.ps1.
public class LuaCheck {
    public static void main(String[] args) throws Exception {
        Class<?> compiler = Class.forName("se.krka.kahlua.luaj.compiler.LuaCompiler");
        Class<?> table = Class.forName("se.krka.kahlua.vm.KahluaTable");
        Method loadstring = compiler.getMethod("loadstring", String.class, String.class, table);
        int failures = 0;
        int count = 0;
        for (String root : args) {
            List<Path> files;
            try (Stream<Path> walk = Files.walk(Path.of(root))) {
                files = walk.filter(p -> p.toString().endsWith(".lua")).sorted().toList();
            }
            for (Path file : files) {
                count++;
                try {
                    loadstring.invoke(null, Files.readString(file), file.getFileName().toString(), null);
                } catch (InvocationTargetException e) {
                    // A null environment can fail after a successful compile; only compiler errors count.
                    Throwable cause = e.getCause();
                    if (!(cause instanceof NullPointerException)) {
                        failures++;
                        System.out.println("FAIL " + file + ": " + cause.getMessage());
                    }
                }
            }
        }
        System.out.println(count + " file(s) checked, " + failures + " with errors");
        System.exit(failures == 0 ? 0 : 1);
    }
}
