package viewpointfixes;

import me.zed_0xff.zombie_buddy.Patch;

/**
 * VPF-004. Viewpoint draws world items through WorldItemModelDrawer.renderMain(..., 0f, 0f, false), and a forced
 * rotation of 0 (anything >= 0) makes ItemModelRenderer ignore the item's own worldX/Y/ZRotation, so every dropped
 * or placed item shows unrotated in 3D. Vanilla passes -1. @Argument(7) limits this to the 9-argument overload.
 */
@Patch(className = "zombie.core.skinnedmodel.model.WorldItemModelDrawer", methodName = "renderMain")
public class Patch_ItemRotation {
    @Patch.OnEnter
    public static void enter(@Patch.Argument(value = 7, readOnly = false) float forcedRotation,
                             @Patch.Argument(8) boolean extended) {
        forcedRotation = Hooks.itemRotation(forcedRotation, extended);
    }
}
