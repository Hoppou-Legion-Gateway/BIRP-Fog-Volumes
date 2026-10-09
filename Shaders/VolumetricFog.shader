// Raymarched fog volume for the Built-in Render Pipeline.
//
// Usable without any scripts (e.g. in VRChat worlds): put this material on a Cube (Sphere/Cube volume types)
// or a Cylinder (Capsule/Cylinder volume types) mesh, and make sure the camera renders a depth texture.
// The FogVolume component does all of this automatically and keeps the material in sync with its profile.
Shader "Fog Volumes/Volumetric Fog"
{
	Properties
	{
		[Header(Volume)]
		[KeywordEnum(Sphere, Cube, Capsule, Cylinder)] _Shape ("Volume Type", Float) = 0
		_EdgeFade ("Edge Fade", Vector) = (0.6, 0.6, 0.6, 0)
		_FadeOffset ("Fade Offset", Vector) = (0, 0, 0, 0)
		[ToggleUI] _LightsFade ("Lighting Fade", Float) = 0
		_MaxDistance ("Max Distance", Float) = 100
		_DistanceFade ("Distance Fade", Range(0, 1)) = 1

		[Header(Appearance)]
		[HDR] _Albedo ("Albedo", Color) = (1, 1, 1, 1)
		[HDR] _Ambient ("Ambient Color", Color) = (1, 1, 1, 1)
		_AmbientOpacity ("Ambient Opacity", Float) = 1

		[Header(Ray Marching)]
		_MinStepLength ("Min Step Length", Float) = 0.5
		_MaxStepLength ("Max Step Length", Float) = 3
		_StepIncrement ("Step Increment", Range(1, 2)) = 1.1
		_MaxRayLength ("Max Ray Length", Float) = 50
		[IntRange] _SampleCount ("Sample Count", Range(1, 1024)) = 36
		_Jitter ("Jitter Strength", Float) = 0.05

		[Header(Lighting)]
		[KeywordEnum(Unlit, Lit, Shadowed)] _Lighting ("Lighting Mode", Float) = 1
		_IntensityModifier ("Light Intensity Modifier", Float) = 1
		_Scattering ("Scattering", Range(0, 1)) = 0.1
		_Extinction ("Extinction", Range(0, 1)) = 0.05
		_MieG ("Mie G", Range(0, 0.999)) = 0.1
		_BrightnessClamp ("Brightness Clamp", Range(0, 100)) = 10

		[Header(Noise)]
		[Toggle(_FOG_NOISE)] _NoiseEnabled ("Enable Noise", Float) = 0
		[NoScaleOffset] _NoiseTexture ("Noise Texture", 3D) = "white" {}
		_NoiseScale ("Noise Scale", Float) = 0.1
		_NoiseScroll ("Noise Scroll", Vector) = (0, -0.15, 0, 0)
		_NoiseIntensity ("Noise Intensity", Range(0, 1)) = 1
		_NoiseIntensityOffset ("Noise Intensity Offset", Range(0, 1)) = 0.5
	}

	CGINCLUDE

	#include "Include/Common.hlsl"
	#include "Include/Math.hlsl"
	#include "Include/Intersection.hlsl"

	ENDCG

	SubShader
	{
		// Rendered after opaques and the skybox, before regular transparents.
		// Batching would bake the object transform into the mesh, which the raymarcher relies on.
		Tags { "Queue"="Transparent-100" "RenderType"="Transparent" "IgnoreProjector"="True" "DisableBatching"="True" "PreviewType"="Sphere" }

		// Back faces with no depth test: the shader clips the ray against the scene depth itself,
		// and back faces still exist when the camera is inside the volume.
		Cull Front
		ZWrite Off
		ZTest Always

		// Pass 0 - ambient, main directional light and vertex lights. Darkens the background by the fog opacity.
		Pass
		{
			Name "FORWARD"
			Tags { "LightMode"="ForwardBase" }

			Blend One OneMinusSrcAlpha

			CGPROGRAM

			#pragma exclude_renderers d3d11_9x
    		#pragma exclude_renderers d3d9

			#pragma vertex VolumetricVertex
			#pragma fragment VolumetricFragment
			#pragma target 3.5

			#pragma multi_compile _ VERTEXLIGHT_ON

			#pragma shader_feature_local _SHAPE_SPHERE _SHAPE_CUBE _SHAPE_CAPSULE _SHAPE_CYLINDER
			#pragma shader_feature_local _LIGHTING_UNLIT _LIGHTING_LIT _LIGHTING_SHADOWED
			#pragma shader_feature_local _FOG_NOISE

			#define FOG_PASS_BASE

			#include "Include/LightAttenuation.hlsl"
			#include "Include/VolumetricFog.hlsl"

			ENDCG
		}

		// Pass 1 - one additional per-pixel light (point, spot, cookies, point/spot shadows), blended additively.
		Pass
		{
			Name "FORWARD_DELTA"
			Tags { "LightMode"="ForwardAdd" }

			Blend One One

			CGPROGRAM

			#pragma exclude_renderers d3d11_9x
    		#pragma exclude_renderers d3d9

			#pragma vertex VolumetricVertex
			#pragma fragment VolumetricFragment
			#pragma target 3.5

			#pragma multi_compile_fwdadd_fullshadows

			#pragma shader_feature_local _SHAPE_SPHERE _SHAPE_CUBE _SHAPE_CAPSULE _SHAPE_CYLINDER
			#pragma shader_feature_local _LIGHTING_UNLIT _LIGHTING_LIT _LIGHTING_SHADOWED
			#pragma shader_feature_local _FOG_NOISE

			#define FOG_PASS_ADD

			#include "Include/LightAttenuation.hlsl"
			#include "Include/VolumetricFog.hlsl"

			ENDCG
		}
	}

	Fallback Off
}
