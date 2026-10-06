package viewpointfixes;

import me.zed_0xff.zombie_buddy.Patch;

/**
 * VPF-003. Viewpoint draws world items only from Frame.modelItems (gathered per chunk, cleared every frame), so
 * the vanilla place-item preview (Render3DItem, iso renderer) never shows. Adding the preview object to that list
 * as Models.snapshot starts lets Viewpoint draw it like any dropped item, at its live offsets.
 */
@Patch(className = "viewpoint.models.Models", methodName = "snapshot")
public class Patch_VPF_003_PreviewItem {
    @Patch.OnEnter
    public static void enter(@Patch.Argument(0) Object frame) {
        Preview.add(frame);
    }
}
