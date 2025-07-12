struct AnimatedFrameUV
{
	float2 TopLeft;
	float2 TopRight;
	float2 BottomRight;
	float2 BottomLeft;
};

cbuffer AnimatedBuffer : register(b6)
{
	AnimatedFrameUV AnimFrames[256];
	unsigned int NumAnimFrames;
	unsigned int FPS;
	unsigned int Type;
    unsigned int Animated;
    float2 UVRotateDirection;
}

float2 CalculateUVRotate(float2 uv, unsigned int frame)
{
	if (FPS == 0)
	{
		return uv;
	}
	else
	{
		const float epsilon = 0.001f;

        AnimatedFrameUV f = AnimFrames[frame];

        float2 minUV = min(min(f.TopLeft, f.TopRight), min(f.BottomLeft, f.BottomRight));
        float2 maxUV = max(max(f.TopLeft, f.TopRight), max(f.BottomLeft, f.BottomRight));
        float2 uvSize = maxUV - minUV;

        float2 localUV = (uv - minUV) / uvSize;

        float relPos = (Frame % FPS) / (float) FPS;
        float2 scrollOffset = -UVRotateDirection * relPos;

        localUV = frac(localUV + scrollOffset);

        localUV = clamp(localUV, epsilon, 1.0f - epsilon);

        float2 scrolledUV = minUV + localUV * uvSize;

        return scrolledUV;
		
	}
}

float2 GetFrame(unsigned int index, unsigned int offset)
{
    float speed = (float)FPS / 30.0f;
    int frame = int(Frame * speed + offset) % NumAnimFrames;

	float2 result = 0;

	switch (index)
	{
	case 0:
		result = AnimFrames[frame].TopLeft;
		break;

	case 1:
		result = AnimFrames[frame].TopRight;
		break;

	case 2:
		result = AnimFrames[frame].BottomRight;
		break;

	case 3:
		result = AnimFrames[frame].BottomLeft;
		break;
	}

	return result;
}

float2 GetUVPossiblyAnimated(float2 uv, int index, int frame)
{
    float2 output = uv;
	
	if (Animated == 1 && Type == 0)
        output = GetFrame(index, frame);
	
    return output;
}