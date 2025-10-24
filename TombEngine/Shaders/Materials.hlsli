#ifndef MATERIALSSHADER
#define MATERIALSSHADER

#include "./CBCamera.hlsli"
#include "./CBMaterial.hlsli"

#define MATERIAL_DEFAULT           0
#define MATERIAL_REFLECTIVE        1
#define MATERIAL_SKYBOX_REFLECTIVE 2

Texture2D OcclusionRoughnessSpecularTexture : register(t10);
SamplerState OcclusionRoughnessSpecularSampler : register(s10);

Texture2D EmissiveTexture : register(t11);
SamplerState EmissiveSampler : register(s11);

Texture2D LegacyReflectionsTexture : register(t12);
SamplerState LegacyReflectionsSampler : register(s12);

Texture2DArray SkyboxReflectionsTexture : register(t13);
SamplerState SkyboxReflectionsSampler : register(s13);

float2 ToCentralSquare(float2 uvEnv, float aspect)
{
    if (aspect >= 1.0)
    {
        float sx = rcp(aspect);
        return float2(uvEnv.x * sx + (0.5 - 0.5 * sx), uvEnv.y);
    }
    else
    {
        float sy = aspect;
        return float2(uvEnv.x, uvEnv.y * sy + (0.5 - 0.5 * sy));
    }
}

float3 CalculateSkyBoxReflections(float3 worldPosition, float3 normal, float specular, float3 pixelColor)
{
    float3 V = normalize(CamPositionWS - worldPosition);
    float3 R = reflect(-V, normal);

    // Angle exaggeration factor to fake angular reflection difference.
    R = normalize(lerp(V, R, 1.5f));
    float3 d = normalize(mul(float4(R, 0.0f), DualParaboloidView).xyz);

    float denom = max(1.0f + abs(d.z), EPSILON);
    float2 uv = (d.xy / denom) * 0.5f + 0.5f;

    // Crop hemisphere to avoid edge artifacts.
    uv = 0.5f + (uv - 0.5f) * 0.985f;
    uv = clamp(uv, EPSILON, 1.0f - EPSILON);

    int slice = (d.z <= 0.0f) ? 0 : 1;
    uv.y = 1.0f - uv.y;
    
    float3 reflectedColor = SkyboxReflectionsTexture.Sample(SkyboxReflectionsSampler, float3(uv, slice)).rgb;
    return lerp(pixelColor, reflectedColor, saturate(specular));
}

float3 CalculateLegacyReflections(float3 worldPosition, float3 normal, float specular, float3 pixelColor)
{
    float3 N = normalize(mul(float4(normal, 0.0f), View).xyz);
    float3 V = normalize(mul(float4(CamPositionWS - worldPosition, 0.0f), View).xyz);
    float3 R = reflect(-V, N);

    // Project reflection vector into pseudo-screen UVs
    float2 uv = R.xy * 0.5f + 0.5f;
    uv.y = 1.0f - uv.y;

    // Preserve aspect ratio
    uv = ToCentralSquare(uv, AspectRatio);

    // Sample legacy reflection buffer
    float3 reflectedColor = LegacyReflectionsTexture.Sample(LegacyReflectionsSampler, uv).rgb;
    return lerp(pixelColor, reflectedColor, specular);
}


float3 CalculateReflections(float3 position, float3 color, float3 normal, float3 specular)
{
    if (MaterialType == MATERIAL_SKYBOX_REFLECTIVE)
    {
        return CalculateSkyBoxReflections(position, normal, specular, color);
    }
    else if (MaterialType == MATERIAL_REFLECTIVE)
    {
        return CalculateLegacyReflections(position, normal, specular, color);
    }
    else
    {
        return color;
    }
}

#endif