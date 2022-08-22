#include "framework.h"
#include "Math/Geometry.h"

#include "Game/items.h"
#include "Specific/phd_global.h"
#include "Specific/trmath.h"

namespace TEN::Math::Geometry
{
	Vector3 TranslatePoint(Vector3 origin, short angle, float forward, float up, float right)
	{
		if (forward == 0.0f && up == 0.0f && right == 0.0f)
			return origin;

		float sinAngle = phd_sin(angle);
		float cosAngle = phd_cos(angle);

		origin.x += (forward * sinAngle) + (right * cosAngle);
		origin.y += up;
		origin.z += (forward * cosAngle) - (right * sinAngle);
		return origin;
	}

	Vector3Int TranslatePoint(Vector3Int origin, short angle, float forward, float up, float right)
	{
		auto newPoint = TranslatePoint(origin.ToVector3(), angle, forward, up, right);
		return Vector3Int(
			(int)round(newPoint.x),
			(int)round(newPoint.y),
			(int)round(newPoint.z)
		);
	}

	Vector3 TranslatePoint(Vector3 origin, Vector3Shrt orient, float distance)
	{
		if (distance == 0.0f)
			return origin;

		float sinX = phd_sin(orient.x);
		float cosX = phd_cos(orient.x);
		float sinY = phd_sin(orient.y);
		float cosY = phd_cos(orient.y);

		origin.x += distance * (sinY * cosX);
		origin.y -= distance * sinX;
		origin.z += distance * (cosY * cosX);
		return origin;
	}

	Vector3Int TranslatePoint(Vector3Int origin, Vector3Shrt orient, float distance)
	{
		auto newPoint = TranslatePoint(origin.ToVector3(), orient, distance);
		return Vector3Int(
			(int)round(newPoint.x),
			(int)round(newPoint.y),
			(int)round(newPoint.z)
		);
	}

	Vector3 TranslatePoint(Vector3 origin, Vector3 target, float distance)
	{
		if (distance == 0.0f)
			return origin;

		float distanceBetweenPoints = Vector3::Distance(origin, target);
		if (distance > distanceBetweenPoints)
			return target;

		auto direction = target - origin;
		direction.Normalize();
		return (origin + (direction * distance));
	}

	Vector3Int TranslatePoint(Vector3Int origin, Vector3Int target, float distance)
	{
		auto newPoint = TranslatePoint(origin.ToVector3(), target.ToVector3(), distance);
		return Vector3Int(
			(int)round(newPoint.x),
			(int)round(newPoint.y),
			(int)round(newPoint.z)
		);
	}

	float GetDistanceToLine(Vector3 origin, Vector3 linePoint0, Vector3 linePoint1)
	{
		auto closestPointOnLine = GetClosestPointOnLine(origin, linePoint0, linePoint1);
		return Vector3::Distance(origin, closestPointOnLine);
	}

	Vector3 GetClosestPointOnLine(Vector3 origin, Vector3 linePoint0, Vector3 linePoint1)
	{
		if (linePoint0 == linePoint1)
			return linePoint0;

		auto direction = linePoint1 - linePoint0;
		float distance = direction.Dot(origin - linePoint0) / direction.Dot(direction);

		if (distance < 0.0f)
			return linePoint0;
		else if (distance > 1.0f)
			return linePoint1;

		return (linePoint0 + (direction * distance));
	}

	Vector3Shrt GetOrientTowardPoint(Vector3 origin, Vector3 target)
	{
		auto direction = target - origin;
		float angle = atan2(direction.x, direction.z);

		auto vector = direction;
		auto matrix = Matrix::CreateRotationY(-angle);
		Vector3::Transform(vector, matrix, vector);

		return Vector3Shrt(
			FROM_RAD(-atan2(direction.y, vector.z)),
			FROM_RAD(angle),
			0
		);
	}

	bool IsPointInFront(PHD_3DPOS pose, Vector3 target)
	{
		return IsPointInFront(pose.Position.ToVector3(), pose.Orientation, target);
	}

	bool IsPointInFront(Vector3 origin, Vector3Shrt orient, Vector3 target)
	{
		float sinY = phd_sin(orient.y);
		float cosY = phd_cos(orient.y);

		auto normalizedDirection2D = Vector3(sinY, 0.0f, cosY);
		auto direction = origin - target;

		float dot = normalizedDirection2D.Dot(direction);
		if (dot >= 0.0f)
			return false;

		return true;
	}
}
