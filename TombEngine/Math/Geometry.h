#pragma once
#include "Specific/trmath.h"

struct PHD_3DPOS;
struct Vector3Shrt;

namespace TEN::Math::Geometry
{
	Vector3	   TranslatePoint(Vector3 origin, short angle, float forward, float up = 0.0f, float right = 0.0f);
	Vector3Int TranslatePoint(Vector3Int origin, short angle, float forward, float up = 0.0f, float right = 0.0f);
	Vector3	   TranslatePoint(Vector3 origin, Vector3Shrt orient, float distance);
	Vector3Int TranslatePoint(Vector3Int origin, Vector3Shrt orient, float distance);
	Vector3	   TranslatePoint(Vector3 origin, Vector3 target, float distance);
	Vector3Int TranslatePoint(Vector3Int origin, Vector3Int target, float distance);

	float		GetDistanceToLine(Vector3 origin, Vector3 linePoint0, Vector3 linePoint1);
	Vector3		GetClosestPointOnLine(Vector3 origin, Vector3 linePoint0, Vector3 linePoint1);
	Vector3Shrt	GetOrientTowardPoint(Vector3 origin, Vector3 target);

	bool IsPointInFront(PHD_3DPOS pose, Vector3 target);
	bool IsPointInFront(Vector3 origin, Vector3Shrt orient, Vector3 target);
}
