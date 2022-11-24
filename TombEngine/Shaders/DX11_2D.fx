#include "./VertexInput.hlsli"

struct PixelShaderInput
{
	float4 Position: SV_POSITION;
	float4 Color: COLOR;
};

PixelShaderInput VS(VertexShaderInput input)
{
	PixelShaderInput output;

    output.Position = float4(input.Position.xy,1.0f, 1.0f);
	output.Color = input.Color;
	return output;
}

float4 PS(PixelShaderInput input) : SV_TARGET
{
	return input.Color;
}