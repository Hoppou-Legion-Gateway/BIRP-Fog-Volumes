#pragma once

// Each fog volume is drawn as a mesh enclosing its shape, rendering back faces only so that a fragment is
// produced for every covered pixel even when the camera is inside the volume. The fragment shader then
// intersects the view ray with the analytic shape and raymarches through it, clamped to the scene depth.
//
// FOG_PASS_BASE (ForwardBase): ambient color, main directional light and vertex lights. Outputs fog opacity in alpha.
// FOG_PASS_ADD (ForwardAdd): one additional pixel light per pass, blended additively.


struct Attributes
{
	float4 vertex : POSITION;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};


struct Varyings
{
	float4 vertex : SV_POSITION;
	float3 worldPosition : TEXCOORD0;
	float4 screenPosition : TEXCOORD1;
	UNITY_VERTEX_OUTPUT_STEREO
};


#if defined(_FOG_NOISE)
	sampler3D _NoiseTexture;
	float _NoiseScale;
	float4 _NoiseScroll;
	float _NoiseIntensity;
	float _NoiseIntensityOffset;
#endif

half4 _Albedo;

half4 _Ambient;
float _AmbientOpacity;

float _IntensityModifier;

float _SampleCount;
float _MinStepLength;
float _MaxStepLength;
float _StepIncrement;
float _MaxRayLength;
float _Jitter;

float _Scattering;
float _Extinction;
float _MieG;

float _BrightnessClamp;

float _MaxDistance;
float _DistanceFade;

float4 _EdgeFade;
float4 _FadeOffset;
float _LightsFade;


// Convert the normalized, user-facing edge fade values into per-shape fade thresholds
float3 GetEdgeFade(out float3 offset)
{
	offset = 0;

	#if defined(_SHAPE_CUBE)
		offset = _FadeOffset.xyz;
		return _EdgeFade.xyz * 2 - 1.5;
	#elif defined(_SHAPE_CYLINDER)
		offset.y = _FadeOffset.y * 2;
		return float3(_EdgeFade.x * 2 - 1.5, _EdgeFade.y * 4 - 3, 0);
	#else
		return float3(_EdgeFade.x - 0.5, 0, 0);
	#endif
}


float FadeBoxEdge(float3 localPos, float3 edgeFade)
{
	float edgeX = smoothstep(edgeFade.x, 0.5, min(localPos.x + 0.5, 0.5 - localPos.x));
	float edgeY = smoothstep(edgeFade.y, 0.5, min(localPos.y + 0.5, 0.5 - localPos.y));
    float edgeZ = smoothstep(edgeFade.z, 0.5, min(localPos.z + 0.5, 0.5 - localPos.z));

	return min(min(edgeX, edgeY), edgeZ);
}


float FadeSphereEdge(float3 localPos, float3 edgeFade)
{
	float dist = 0.5 - length(localPos);

	return smoothstep(edgeFade.x, 0.5, dist);
}


float FadeCylinderEdge(float3 localPos, float3 edgeFade)
{
	float dist = 0.5 - length(localPos.xz);

	float sphereRad = smoothstep(edgeFade.x, 0.5, dist);
	float yEdge = smoothstep(edgeFade.y, 1, min(localPos.y + 1, 1 - localPos.y));

	return min(sphereRad, yEdge);
}


float FadeCapsuleEdge(float3 localPos, float3 edgeFade)
{
	const float3 ab = float3(0, 1, 0);
	float3 ac = localPos - float3(0, -0.5, 0);
	float3 bc = localPos - float3(0, 0.5, 0);

    float e = dot(ac, ab);

	float dist;

    // Handle cases where c projects outside ab
    if (e <= 0.0f)
		dist = sqrlen(ac);
	else
	{
		float f = sqrlen(ab);
		dist = e >= f ? sqrlen(bc) : sqrlen(ac) - e * e / f;
	}

	return smoothstep(edgeFade.x, 0.5, (0.5 - sqrt(dist)));
}


float GetFade(float3 worldPosition)
{
	float3 offset;
	float3 edgeFade = GetEdgeFade(offset);

	float3 localPos = mul(unity_WorldToObject, float4(worldPosition, 1.0)).xyz + offset;

	#if defined(_SHAPE_CUBE)
		return FadeBoxEdge(localPos, edgeFade);
	#elif defined(_SHAPE_CAPSULE)
		return FadeCapsuleEdge(localPos, edgeFade);
	#elif defined(_SHAPE_CYLINDER)
		return FadeCylinderEdge(localPos, edgeFade);
	#else
		return FadeSphereEdge(localPos, edgeFade);
	#endif
}


// x: maximum fog distance, y: distance at which fog begins fading out
float2 GetFogRange()
{
	return float2(_MaxDistance, lerp(0, _MaxDistance, _DistanceFade - 0.001));
}


float GetDensity(float3 worldPosition, float distance)
{
    float density = 1.0;

	#if defined(_FOG_NOISE)
		// Scale sample position
		float3 samplePos = (worldPosition * _NoiseScale);

		// Offset sample position
		samplePos += _Time.y * (-_NoiseScroll.xyz * _NoiseScale);

		float noise = SAMPLE_BASE3D(_NoiseTexture, samplePos).x;
		density = saturate(noise - _NoiseIntensityOffset) * _NoiseIntensity;
	#endif

	// Fade density as position gets further from camera
	float2 fogRange = GetFogRange();
    return density * smoothstep(fogRange.x, fogRange.y, distance);
}


// For the record, I have no idea if the transmittance is physically accurate, and it's kind of hacky. If anyone can fix it that would be great!~ but for the meantime it looks ok.
half4 RayMarch(float3 rayStart, float3 rayDir, float rayLength, float3 cameraPos)
{
	float cameraDistance = length(cameraPos - rayStart);

	float extinction = cameraDistance * _Extinction * 0.5; // Assume density of 0.5 between camera and fog volume.

	float stepSize = _MinStepLength;

	half3 vlight = 0;
	float distance = 0;

	int sampleCount = (int)_SampleCount;

	[loop]
	for (int i = 0; i < sampleCount; ++i)
	{
		if (distance >= rayLength)
			break;

		float3 currentPosition = rayStart + rayDir * distance;

		float density = GetDensity(currentPosition, distance + cameraDistance);
		float fade = GetFade(currentPosition);

        float scattering = _Scattering * stepSize * density;
		extinction += _Extinction * stepSize * density;

		float influence = scattering * exp(-extinction);

		half3 light = GetLighting(currentPosition, rayDir, _MieG) * _IntensityModifier;
		float lightFade = _LightsFade > 0.5 ? fade : 1.0;

		half3 color = light * lightFade;

		#if defined(FOG_PASS_BASE)
			color += _Ambient.rgb * fade;
		#endif

        vlight += color * influence;

		distance += stepSize;

		stepSize = min(_MaxStepLength, stepSize * _StepIncrement);
	}

	vlight *= _Albedo.rgb;
	vlight = clamp(vlight, 0, _BrightnessClamp);

	#if defined(FOG_PASS_BASE)
		// Opacity = 1 - Transmittance, scaled by how much the fog may obscure the background
		float opacity = (1.0 - exp(-extinction)) * saturate(_AmbientOpacity);
		return half4(vlight, opacity);
	#else
		// Additional lights only add light, the base pass already darkened the background
		return half4(vlight, 0);
	#endif
}


bool IntersectVolume(float3 rayOrigin, float3 rayDir, out float near, out float far)
{
	near = 0;
	far = 0;

	#if defined(_SHAPE_CUBE)
		return RayCube(unity_WorldToObject, rayOrigin, rayDir, near, far);
	#elif defined(_SHAPE_CAPSULE)
		return RayCapsule(unity_WorldToObject, rayOrigin, rayDir, near, far);
	#elif defined(_SHAPE_CYLINDER)
		return RayCylinder(unity_WorldToObject, rayOrigin, rayDir, near, far);
	#else
		return RaySphere(unity_WorldToObject, rayOrigin, rayDir, near, far);
	#endif
}


Varyings VolumetricVertex(Attributes v)
{
	Varyings output;

	UNITY_SETUP_INSTANCE_ID(v);
	UNITY_INITIALIZE_OUTPUT(Varyings, output);
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

	float4 vertex = v.vertex;

	#if defined(_SHAPE_CAPSULE) || defined(_SHAPE_CYLINDER)
		// The built-in cylinder mesh is a polygonal prism inscribed in the true cylinder. Inflate it so it covers the analytic shape.
		vertex.xz *= 1.05;
	#endif

	output.vertex = UnityObjectToClipPos(vertex);

	// Keep back faces of volumes larger than the camera range from being clipped by the far plane.
	// Halving the clip-space distance to the near plane keeps near clipping exact, and moves the far plane
	// past infinity whenever far >= 2 * near. Depth isn't tested, and rays use the interpolated world position.
	#if defined(UNITY_REVERSED_Z)
		output.vertex.z = 0.5 * (output.vertex.z + output.vertex.w);
	#else
		output.vertex.z = 0.5 * (output.vertex.z - output.vertex.w);
	#endif

	output.worldPosition = mul(unity_ObjectToWorld, vertex).xyz;
	output.screenPosition = ComputeScreenPos(output.vertex);

	return output;
}


half4 VolumetricFragment(Varyings input) : SV_Target
{
	UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

	#if defined(FOG_PASS_ADD) && defined(_LIGHTING_UNLIT)
		// Unlit volumes receive no additional lights
		discard;
		return 0;
	#else

	float3 cameraPos = _WorldSpaceCameraPos.xyz;
	float3 rayDir = normalize(input.worldPosition - cameraPos);
	float2 screenUV = input.screenPosition.xy / input.screenPosition.w;

	float near, far;

	// No intersection
	if (!IntersectVolume(cameraPos, rayDir, near, far))
		return 0;

	// Volume begins past the maximum fog distance
	if (near > _MaxDistance)
		return 0;

	far = min(far, SceneDistance(screenUV, rayDir));
	float rayLength = far - near;

	// Object is behind scene depth
	if (rayLength < 0)
		return 0;

	// Jump to point on intersection surface, then add jitter
	float3 rayStart = cameraPos + rayDir * (near + MathRand(screenUV) * _Jitter);

	return RayMarch(rayStart, rayDir, min(rayLength, _MaxRayLength), cameraPos);
	#endif
}
