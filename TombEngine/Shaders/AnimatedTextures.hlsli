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
	unsigned int padding2;
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
#ifdef OLDCODE 
		float2 step = uv.y - AnimFrames[frame].TopLeft.y;
		float vert = AnimFrames[frame].TopLeft.y + (step / 2);

		float height = (AnimFrames[frame].BottomLeft.y - AnimFrames[frame].TopLeft.y) / 2;
		float relPos = 1.0f - (Frame % FPS) / (float)FPS;

		float newUV = vert + height * relPos;
		return float2(uv.x, newUV);
 #endif
		
      // Parametri
        const float epsilon = 0.001f; // Per evitare sampling ai bordi

    // Frame UV corners
        AnimatedFrameUV f = AnimFrames[frame];

        float2 minUV = min(min(f.TopLeft, f.TopRight), min(f.BottomLeft, f.BottomRight));
        float2 maxUV = max(max(f.TopLeft, f.TopRight), max(f.BottomLeft, f.BottomRight));
        float2 uvSize = maxUV - minUV;

    // UV normalizzata all’interno della tile
        float2 localUV = (uv - minUV) / uvSize;

    // Scroll nel tempo (invertito per direzione visiva corretta)
        float relPos = (Frame % FPS) / (float) FPS;
        float2 scrollOffset = -UVRotateDirection * relPos;

    // Applica offset e wrap internamente alla tile
        localUV = frac(localUV + scrollOffset);

    // Clamping per evitare sampling oltre i bordi (anti-bordino)
        localUV = clamp(localUV, epsilon, 1.0f - epsilon);

    // Converti di nuovo in spazio UV globale
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
