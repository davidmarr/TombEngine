#pragma once
#include "framework.h"
#include "Math/Math.h"
#include "Objects/game_object_ids.h"

using namespace TEN::Math;

namespace TEN::Hud
{

	struct DisplayItem
	{
		std::string ItemName;
		GAME_OBJECT_ID ObjectID = GAME_OBJECT_ID::ID_NO_OBJECT;

		Vector3		Position = Vector3::Zero;
		EulerAngles Orientation = EulerAngles::Identity;

		float Scale = 0.0f;

		Color ItemColor = Vector4::One;

		int MeshBits = 0u;

		Vector3		PrevPosition = Vector3::Zero;
		EulerAngles PrevOrientation = EulerAngles::Identity;
		float		PrevScale = 0.0f;
		Color		PrevColor = Vector4::One;

		bool Visible = true;

		std::unordered_map<int, EulerAngles> MeshRotations;
		std::unordered_map<int, EulerAngles> PrevMeshRotations;

		void SetItemObjectID(GAME_OBJECT_ID objectID);
		void SetItemPosition(const Vector3& newPos, bool disableInterpolation);
		void SetItemRotation(const EulerAngles& newRot, bool disableInterpolation);
		void SetItemScale(float newScale, bool disableInterpolation);
		void SetItemColor(Color& newColor, bool disableInterpolation);
		void SetItemMeshBits(int meshbits);
		void SetItemMeshRotation(int meshIndex, const EulerAngles& rot, bool disableInterpolation);
		void SetItemVisibility(bool visible);

		std::string GetItemName();
		GAME_OBJECT_ID GetItemObjectID();
		Vector3 GetItemPosition();
		EulerAngles GetItemRotation();
		float GetItemScale();
		Color GetItemColor();
		bool GetItemVisibility();
		EulerAngles GetItemMeshRotation(int meshIndex);

		// Interpolation Helpers
		void StoreInterpolationData();
		Vector3 GetInterpolatedPosition(float t) const;
		EulerAngles GetInterpolatedOrientation(float t) const;
		float GetInterpolatedScale(float t) const;
		Color GetInterpolatedColor(float t) const;
		EulerAngles GetInterpolatedMeshRotation(int meshIndex, float t) const;
	};

}
