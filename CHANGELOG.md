## 0.4.0

Ported from the Universal Render Pipeline to the Built-in Render Pipeline (Unity 2022.3, VRChat compatible).

* Fog volumes are now drawn by a regular `MeshRenderer` with a per-volume material instead of a URP renderer feature. No render feature or pipeline asset setup is needed.
* The fog shader (`Fog Volumes/Volumetric Fog`) can be used directly on a material without any scripts.
* The `FogVolume` component is editor-only in VRChat projects and is stripped on upload; the renderer and material it generates remain.
* Lighting uses the built-in forward passes: main directional light and vertex lights in the base pass, one additive pass per pixel light. Point and spot light shadows and light cookies are supported.
* Removed: `VolumetricFogFeature`, half/quarter resolution rendering, bilateral blur, temporal reprojection, the per-volume light layer mask and light limit, and APV GI sampling.
* Ambient Opacity now scales how strongly fog obscures the background.

## 0.3.0

Added APV Support
