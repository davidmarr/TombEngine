#pragma once

struct alignas(16) CDualParaboloidShadowBuffer
{
	float NearPlane;
	float FarPlane;
	int ParaboloidDirection;
};