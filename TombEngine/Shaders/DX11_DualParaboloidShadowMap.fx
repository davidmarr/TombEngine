#include "./CameraMatrixBuffer.hlsli"
#include "./AlphaTestBuffer.hlsli"
#include "./VertexInput.hlsli"

cbuffer ItemBuffer : register(b1)
{
	float4x4 World;
	float4x4 Bones[32];
	float4 ItemPosition;
	float4 AmbientLight;
};

cbuffer DualParaboloidShadowBuffer : register(b13)
{
	float NearPlane;
	float FarPlane;
	int ParaboloidDirection;
}

struct PixelShaderInput
{
	float4 Position: SV_POSITION;
	float ClipDepth : TEXCOORD1;
	float Depth : TEXCOORD2;
};

Texture2D Texture : register(t0);
SamplerState Sampler : register(s0);

PixelShaderInput VS(VertexShaderInput input)
{
	PixelShaderInput output;

	float4x4 world = mul(Bones[input.Bone], World);

	// transform vertex to DP-space
	output.Position = mul(mul(float4(input.Position, 1.0f), world), ViewProjection);
	output.Position /= output.Position.w;

	// for the back-map z has to be inverted
	output.Position.z *= ParaboloidDirection;

	// because the origin is at 0 the proj-vector
	// matches the vertex-position
	float fLength = length(output.Position.xyz);

	// normalize
	output.Position /= fLength;

	// save for clipping 	
	output.ClipDepth = output.Position.z;

	// calc "normal" on intersection, by adding the 
	// reflection-vector(0,0,1) and divide through 
	// his z to get the texture coords
	output.Position.x /= output.Position.z + 1.0f;
	output.Position.y /= output.Position.z + 1.0f;

	// set z for z-buffering and neutralize w
	output.Position.z = (fLength - NearPlane) / (FarPlane - NearPlane);
	output.Position.w = 1.0f;

	// DP-depth
	output.Depth = output.Position.z;

	return output;
}

float4 PS(PixelShaderInput input) : SV_TARGET
{
	clip(input.ClipDepth);
	return float4(input.Depth, 0, 0, 0);
}