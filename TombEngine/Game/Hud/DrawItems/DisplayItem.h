#pragma once
#include "framework.h"
#include "Math/Math.h"
#include "Objects/game_object_ids.h"
#include "Specific/Structures/BitField.h"

using namespace TEN::Math;
using namespace TEN::Utils;

namespace TEN::Hud
{

	struct DisplayItem
	{
	private:
		std::string ItemName;
		GAME_OBJECT_ID ObjectID = GAME_OBJECT_ID::ID_NO_OBJECT;

		Vector3		Position = Vector3::Zero;
		EulerAngles Orientation = EulerAngles::Identity;

		float Scale = 0.0f;

		Color ItemColor = Vector4::One;

		BitField MeshBits = BitField::Default;

		Vector3		PrevPosition = Vector3::Zero;
		EulerAngles PrevOrientation = EulerAngles::Identity;
		float		PrevScale = 0.0f;
		Color		PrevColor = Vector4::One;

		bool Visible = true;

		std::unordered_map<int, EulerAngles> MeshRotations;
		std::unordered_map<int, EulerAngles> PrevMeshRotations;

	public:
		void SetItemName(std::string itemName);
		void SetItemObjectID(GAME_OBJECT_ID objectID);
		void SetItemPosition(const Vector3& newPos, bool disableInterpolation);
		void SetItemRotation(const EulerAngles& newRot, bool disableInterpolation);
		void SetItemScale(float newScale, bool disableInterpolation);
		void SetItemColor(Color& newColor, bool disableInterpolation);
		void SetItemVisibility(bool visible);
		void SetItemMeshBits(int meshbits);
		void SetItemMeshVisibility(int meshIndex, bool visible);
		void SetItemMeshRotation(int meshIndex, const EulerAngles& rot, bool disableInterpolation);

		std::string GetItemName() const;
		GAME_OBJECT_ID GetItemObjectID() const;
		Vector3 GetItemPosition() const;
		EulerAngles GetItemRotation() const;
		float GetItemScale() const;
		Color GetItemColor() const;
		bool GetItemVisibility() const;
		int GetItemMeshBits() const;
		bool GetItemMeshVisibility(int meshIndex) const;
		EulerAngles GetItemMeshRotation(int meshIndex) const;
		
		// Interpolation Helpers
		void StoreInterpolationData();
		Vector3 GetInterpolatedPosition(float t) const;
		EulerAngles GetInterpolatedOrientation(float t) const;
		float GetInterpolatedScale(float t) const;
		Color GetInterpolatedColor(float t) const;
		EulerAngles GetInterpolatedMeshRotation(int meshIndex, float t) const;

		//Utilities
		bool MeshExists(int index) const;
	};

}
