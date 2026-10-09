#pragma once

// Built-in render pipeline light evaluation at arbitrary world positions.
// ForwardBase evaluates the main directional light and the 4 per-object vertex lights.
// ForwardAdd evaluates the single pixel light that pass is being drawn for.

#include "UnityLightingCommon.cginc"
#include "AutoLight.cginc"


// Original from https://github.com/SlightlyMad/VolumetricLights/blob/master/Assets/Shaders/VolumetricLight.shader under the BSD license
float MiePhase(float cosAngle, float mieG)
{
	float gSqr = sqr(mieG);

	// Magic number is 1/4pi
    return (0.07957747154) * ((1 - gSqr) / (pow(abs((1 + gSqr) - (2 * mieG) * cosAngle), 1.5)));
}


#if defined(FOG_PASS_BASE)

half3 GetLighting(float3 worldPosition, float3 rayDir, float mieG)
{
    half3 totalColor = 0;

    #if !defined(_LIGHTING_UNLIT)
        // Main directional light. _LightColor0 is black when the scene has no directional light.
        totalColor += _LightColor0.rgb * MiePhase(dot(_WorldSpaceLightPos0.xyz, rayDir), mieG);

        #if defined(VERTEXLIGHT_ON)
            // Non-important point lights, using Unity's vertex light falloff windowed to the light range
            [unroll]
            for (int i = 0; i < 4; i++)
            {
                float3 toLight = float3(unity_4LightPosX0[i], unity_4LightPosY0[i], unity_4LightPosZ0[i]) - worldPosition;
                float distanceSqr = max(sqrlen(toLight), 1e-4);
                float attenuation = 1.0 / (1.0 + distanceSqr * unity_4LightAtten0[i]);

                // unity_4LightAtten0 is 25 / range^2
                float window = saturate(1.0 - distanceSqr * unity_4LightAtten0[i] / 25.0);
                attenuation *= window * window;

                float3 lightDir = toLight * rsqrt(distanceSqr);
                totalColor += unity_LightColor[i].rgb * attenuation * MiePhase(dot(lightDir, rayDir), mieG);
            }
        #endif
    #endif

    return totalColor;
}

#elif defined(FOG_PASS_ADD)

// Light falloff and cookie of the current pixel light
float LightFalloff(float3 worldPosition)
{
    #if defined(POINT)
        float3 lightCoord = mul(unity_WorldToLight, float4(worldPosition, 1)).xyz;
        return SAMPLE_BASE(_LightTexture0, dot(lightCoord, lightCoord).rr).r;
    #elif defined(SPOT)
        float4 lightCoord = mul(unity_WorldToLight, float4(worldPosition, 1));
        float cookie = SAMPLE_BASE(_LightTexture0, lightCoord.xy / lightCoord.w + 0.5).w;
        float falloff = SAMPLE_BASE(_LightTextureB0, dot(lightCoord.xyz, lightCoord.xyz).rr).r;
        return (lightCoord.z > 0) * cookie * falloff;
    #elif defined(POINT_COOKIE)
        float3 lightCoord = mul(unity_WorldToLight, float4(worldPosition, 1)).xyz;
        float cookie = texCUBElod(_LightTexture0, float4(lightCoord, 0)).w;
        float falloff = SAMPLE_BASE(_LightTextureB0, dot(lightCoord, lightCoord).rr).r;
        return cookie * falloff;
    #elif defined(DIRECTIONAL_COOKIE)
        float2 lightCoord = mul(unity_WorldToLight, float4(worldPosition, 1)).xy;
        return SAMPLE_BASE(_LightTexture0, lightCoord).w;
    #else
        return 1;
    #endif
}


// Realtime shadows of the current pixel light.
// Only spot and point light shadow maps can be sampled at arbitrary positions - directional light shadows
// are resolved into a screen-space mask in the built-in pipeline, which is useless for raymarching.
float LightShadow(float3 worldPosition)
{
    float shadow = 1;

    #if defined(SHADOWS_DEPTH) && defined(SPOT)
        // Single hardware PCF tap, the soft shadow helpers use derivatives which are unavailable inside the raymarch loop
        float4 shadowCoord = mul(unity_WorldToShadow[0], float4(worldPosition, 1));
        shadow = UNITY_SAMPLE_SHADOW_PROJ(_ShadowMapTexture, shadowCoord);
        shadow = lerp(_LightShadowData.r, 1.0, shadow);
    #elif defined(SHADOWS_CUBE)
        shadow = UnitySampleShadowmap(worldPosition - _LightPositionRange.xyz);
    #endif

    #if (defined(SHADOWS_DEPTH) && defined(SPOT)) || defined(SHADOWS_CUBE)
        // Fade out shadows past the shadow distance
        float zDist = dot(_WorldSpaceCameraPos - worldPosition, UNITY_MATRIX_V[2].xyz);
        float fadeDist = UnityComputeShadowFadeDistance(worldPosition, zDist);
        shadow = saturate(shadow + UnityComputeShadowFade(fadeDist));
    #endif

    return shadow;
}


half3 GetLighting(float3 worldPosition, float3 rayDir, float mieG)
{
    #if defined(_LIGHTING_UNLIT)
        return 0;
    #else
        float3 lightDir = normalize(_WorldSpaceLightPos0.xyz - worldPosition * _WorldSpaceLightPos0.w);

        float attenuation = LightFalloff(worldPosition);

        #if defined(_LIGHTING_SHADOWED)
            attenuation *= LightShadow(worldPosition);
        #endif

        return _LightColor0.rgb * attenuation * MiePhase(dot(lightDir, rayDir), mieG);
    #endif
}

#endif
