#pragma once

#include "UnityCG.cginc"

// LOD 0 sampler macros to prevent use of gradient functions inside the raymarch loop
#define SAMPLE_BASE(tex, uv) tex2Dlod(tex, float4((uv), 0, 0))
#define SAMPLE_BASE3D(tex, uvw) tex3Dlod(tex, float4((uvw), 0))


UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);


// Distance along a normalized world-space ray to the opaque scene depth at the given screen UV.
float SceneDistance(float2 screenUV, float3 rayDir)
{
    float rawDepth = SAMPLE_DEPTH_TEXTURE_LOD(_CameraDepthTexture, float4(screenUV, 0, 0));
    float eyeDepth = LinearEyeDepth(rawDepth);

    // Eye depth is measured along the camera forward axis, convert it to a distance along the ray
    float3 cameraForward = -UNITY_MATRIX_V[2].xyz;
    return eyeDepth / max(dot(rayDir, cameraForward), 1e-4);
}
