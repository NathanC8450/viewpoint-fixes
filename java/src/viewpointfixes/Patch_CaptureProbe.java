package viewpointfixes;

import me.zed_0xff.zombie_buddy.Patch;

/**
 * VPF-003 diagnosis (debug logging only, read-only): whether Viewpoint's item capture accepted the preview.
 * Remove once the preview is verified.
 */
@Patch(className = "viewpoint.models.RigidCapture", methodName = "item")
public class Patch_CaptureProbe {
    @Patch.OnExit(onThrowable = Throwable.class)
    public static void exit(@Patch.Argument(3) Object item, @Patch.Return boolean accepted,
                            @Patch.Thrown Throwable thrown) {
        Hooks.captureResult(item, accepted, thrown);
    }
}
