#pragma once

class EulerAngles;
struct ItemInfo;
class Pose;

//namespace TEN::Math
//{
	class BOUNDING_BOX
	{
	public:
		// Components
		int X1 = 0;
		int X2 = 0;
		int Y1 = 0;
		int Y2 = 0;
		int Z1 = 0;
		int Z2 = 0;

		// Constants
		static const BOUNDING_BOX Zero;

		// Constructors
		BOUNDING_BOX();
		BOUNDING_BOX(float x1, float x2, float y1, float y2, float z1, float z2);
		BOUNDING_BOX(ItemInfo* item, bool isAccurate = true);

		// Getters
		int GetWidth() const;
		int GetHeight() const;
		int GetDepth() const;

		// Utilities
		void RotNoPersp(const EulerAngles& orient, const BOUNDING_BOX& bounds);

		// Converters
		BoundingOrientedBox ToBoundingOrientedBox(const Pose& pose) const;
		BoundingOrientedBox ToBoundingOrientedBox(const Vector3& pos, const Quaternion& orient) const;

		// Operators
		BOUNDING_BOX operator +(const BOUNDING_BOX& bounds) const;
		BOUNDING_BOX operator +(const Pose& pose) const;
		BOUNDING_BOX operator -(const BOUNDING_BOX& bounds) const;
		BOUNDING_BOX operator -(const Pose& pose) const;
		BOUNDING_BOX operator *(float scale) const;
	};
//}