package viewpointfixes;

import me.zed_0xff.zombie_buddy.Patch;

/**
 * VPF-003 diagnosis (debug logging only): what WorldItemModelDrawer.renderMain returned, or threw, for the
 * preview item when Viewpoint drew it. Remove once the preview is verified.
 */
@Patch(className = "zombie.core.skinnedmodel.model.WorldItemModelDrawer", methodName = "renderMain")
public class Patch_PreviewProbe {
    @Patch.OnExit(onThrowable = Throwable.class)
    public static void exit(@Patch.Argument(0) Object item, @Patch.Return Object status,
                            @Patch.Thrown Throwable thrown) {
        Hooks.renderResult(item, status, thrown);
    }
}
