# Raymarched Fog Volumes for Unity's Built-in RP

This repository is a port of [sinnwrig's URP Fog Volumes](https://github.com/sinnwrig/URP-Fog-Volumes) to Unity's Built-in Render Pipeline (Unity 2022.3), built to work in VRChat worlds: every volume is a plain mesh renderer with a material, so no scripts or render pipeline hooks are needed at runtime.

Scenes | Outdoors Light Shafts | URP Samples- Japanese Garden | Nighttime streetlights
:-:|:-:|:-:|:-:|
Fog | ![Outdoors Fog](Assets~/Images/Terrain-Fog.png) | ![Garden Fog](Assets~/Images/Garden-Fog.png) | ![Building Fog](Assets~/Images/Building-Fog.png)
No Fog | ![Outdoors](Assets~/Images/Terrain.png)<br> | ![Garden](Assets~/Images/Garden.png)<br> | ![Building](Assets~/Images/Building.png)<br>

_Screenshots are from the original URP version._

[More Examples](#examples)

## Installation

* Open the package manager and select the _Add package from Git URL_ option found under the top left dropdown.<br>
![From Git URL](Assets~/Images/giturl.png)<br>
* Add this repository git URL in the prompt, using the following link: https://github.com/Hoppou-Legion-Gateway/BIRP-Fog-Volumes.git<br>

This also works in VRChat Creator Companion projects.

## Usage

* Create a new Fog Volume using the options under _GameObject/Volume/_, or add the FogVolume component to any object.
* Create or assign a new profile.
* Adjust object scale and profile settings until you get your desired look.

The FogVolume component adds a `MeshFilter` and `MeshRenderer` to its object and writes its settings and profile into a material owned by the volume. The material is saved with the scene, and is updated whenever the volume or its profile changes.

### VRChat

* The FogVolume component is editor-only in projects with the VRChat SDK (it implements `IEditorOnly`) and is stripped on upload. The mesh renderer and material it generated remain and render the fog. Save the scene after editing volumes and profiles.
* To change fog at runtime from Udon, modify the volume's material (e.g. `_Albedo`, `_Ambient`, `_Scattering`) instead of the profile.
* The fog needs the camera depth texture. VRChat only renders it when the scene contains a **realtime Directional Light with shadows enabled**. If your world has none, add one with a very low intensity and a culling mask containing only an otherwise-unused layer. The FogVolume inspector warns when no such light exists.

### Using the shader without the component

The shader is named `Fog Volumes/Volumetric Fog` and exposes every setting as a material property:

* Use a **Cube** mesh for the Sphere and Cube volume types, and a **Cylinder** mesh for the Capsule and Cylinder types (Unity's built-in meshes have the right size).
* Don't mark the object _Batching Static_: the shader works in object space, and static batching bakes the transform into the mesh.
* Disable shadow casting on the renderer, and keep _Receive Shadows_ enabled for point and spot light shadows.
* Outside VRChat, make sure the camera renders a depth texture (`Camera.depthTextureMode`). The FogVolume component does this automatically.

## Features

* Animated scrolling 3D texture noise
* 4 primitive shapes that support non-uniform scale and rotation:
    * Cube
    * Capsule
    * Sphere
    * Cylinder
* Lighting from the built-in forward renderer:
    * The main directional light and the 4 per-object vertex (non-important) lights in the base pass.
    * One additive pass per pixel light, with spot and point light shadows and light cookies.
    * _Lighting is not entirely physically-based, and instead exposes artistic controls for finer tweaking._<br>
    * _Light attenuation is only single-bounce, and fog does not self-shadow._<br>
* Works in single-pass stereo and single-pass instanced VR.
* Samples for the [_Gas Station_](#gas-station-with-and-without-fog),  [_Forest_](#japanese-forest-with-and-without-fog), and [_Office Building_](#building-with-and-without-fog) scenes. These can be imported through the package manager.

## Differences from the URP version

* Fog renders at full resolution directly into the camera target. Half/quarter resolution, the bilateral blur and temporal reprojection relied on a render pipeline pass, which isn't available in the Built-in pipeline without runtime scripts (and therefore not in VRChat).
* **Directional light shadows don't affect fog.** The Built-in pipeline resolves directional shadows into a screen-space texture, which can't be sampled inside a volume. Point and spot light shadows work.
* Which lights affect a volume is decided by Unity's forward renderer: the _Pixel Light Count_ quality setting, each light's _Render Mode_, and each light's _Culling Mask_ against the volume's layer. The per-volume light layer mask and light limit were removed.
* Each pixel light re-runs the raymarch in its own pass, so many overlapping pixel lights are expensive. Lights set to _Not Important_ are cheaper (evaluated in the base pass) but unshadowed.
* Point and spot lights use the Built-in pipeline's falloff instead of URP's inverse-square falloff, so _Light Intensity Modifier_ values may need retuning.
* APV global illumination is not sampled.
* _Ambient Opacity_ scales how strongly the fog obscures what's behind it (0 is purely additive).

## Limitations

* Does not support DirectX 9 or DirectX 11 9.x. These shader models are incompatible with dynamic loops.
* Orthographic cameras do not work.
* Baked lighting and light probes do not affect fog.
* Volumes render in the transparent queue (`Transparent-100`), after opaques and the skybox but before regular transparent objects, so transparent objects are not fogged. Change the material's render queue to render fog after them instead.
* Like other depth-based effects, fog may render incorrectly in VRChat mirrors.

## Potential Issues

This port has not been verified in-engine on every platform. The original asset was tested on OpenGL 4.5, DirectX 11/12 and Vulkan on Windows and Linux.

# Examples
### Japanese Forest with and without fog
![Outdoors Fog](Assets~/Images/Terrain-Fog.png)
![Outdoors](Assets~/Images/Terrain.png)<br>
### Oasis with and without fog
![Oasis Fog](Assets~/Images/Oasis-Fog.png)
![Oasis](Assets~/Images/Oasis.png)<br>
### Building with and without fog
![Building Fog](Assets~/Images/Building-Fog.png)
![Building](Assets~/Images/Building.png)<br>
### Japanese Garden with and without fog
![Garden Fog](Assets~/Images/Garden-Fog.png)
![Garden](Assets~/Images/Garden.png)<br>
### Gas station with and without fog
![Gas Station Fog](Assets~/Images/GasStation-Fog.png)
![Gas Station](Assets~/Images/GasStation.png)<br>
### Demo Terminal Building with fog
![Terminal Fog](Assets~/Images/Terminal-Fog.png)<br>
