#pragma once
#include "Math/Math.h"
#include "Objects/game_object_ids.h"

using namespace TEN::Math;

namespace TEN::Hud
{

	struct DisplayItem
	{

		GAME_OBJECT_ID ObjectID = GAME_OBJECT_ID::ID_NO_OBJECT;

		Vector3		Position	= Vector3::Zero;
		EulerAngles Orientation = EulerAngles::Identity;

		float Scale		   = 0.0f;
		float Opacity	   = 0.0f;

		int MeshBits = 0u;
		
		Vector3		PrevPosition	= Vector3::Zero;
		EulerAngles PrevOrientation = EulerAngles::Identity;
		float		PrevScale		= 0.0f;
		float		PrevOpacity		= 0.0f;

		std::unordered_map<int, EulerAngles> MeshRotations;
		std::unordered_map<int, EulerAngles> PrevMeshRotations;

		void StoreInterpolationData()
		{
			PrevPosition = Position;
			PrevOrientation = Orientation;
			PrevScale = Scale;
			PrevOpacity = Opacity;
			PrevMeshRotations = MeshRotations;
		}

		// Interpolation Helpers
		Vector3 GetInterpolatedPosition(float t) const
		{
			return Vector3::Lerp(PrevPosition, Position, t);
		}

		EulerAngles GetInterpolatedOrientation(float t) const
		{
			return EulerAngles::Lerp(PrevOrientation, Orientation, t);
		}

		float GetInterpolatedScale(float t) const
		{
			return Lerp(PrevScale, Scale, t);
		}

		float GetInterpolatedOpacity(float t) const
		{
			return Lerp(PrevOpacity, Opacity, t);
		}

		EulerAngles GetInterpolatedMeshRotation(int meshIndex, float t) const
		{
			auto itNow = MeshRotations.find(meshIndex);
			auto itPrev = PrevMeshRotations.find(meshIndex);

			// If only current rotation exists, or no interpolation available, return it
			if (itNow == MeshRotations.end())
				return EulerAngles::Identity;
			if (itPrev == PrevMeshRotations.end())
				return itNow->second;

			return EulerAngles::Lerp(itPrev->second, itNow->second, t);
		}

	};

	class DrawItemsController
	{
	private:
		// Constants
		static constexpr auto DRAW_ITEM_COUNT_MAX	= 64;

		// Fields
		std::vector<DisplayItem> _displayItems = {};
		
		Vector3 _cameraPosition = Vector3(0.0f, 0.0f, -BLOCK(1));
		Vector3 _targetPosition = Vector3::Zero;

		Vector3 _cameraPreviousPosition = _cameraPosition;
		Vector3 _targetPreviousPosition = _targetPosition;

		bool _inventoryOverride = false;
		int _openInventory = NO_VALUE;

	public:

		void AddItem(GAME_OBJECT_ID objectID, const Vector3& origin, float scale, float opacity = 1.0f, int meshBits = 0u);
		void RemoveItem(GAME_OBJECT_ID objectID);

		void Update();
		void Draw() const;
		void Clear();

		DisplayItem* SelectItemByID(GAME_OBJECT_ID objectID);

		void SetItemPosition(GAME_OBJECT_ID objectID, const Vector3& newPos);
		void SetItemRotation(GAME_OBJECT_ID objectID, const EulerAngles& newRot);
		void SetItemScale(GAME_OBJECT_ID objectID, float newScale);
		void SetItemAlpha(GAME_OBJECT_ID objectID, float newAlpha);
		void SetItemMeshBits(GAME_OBJECT_ID objectID, int meshbits);
		void SetItemMeshRotation(GAME_OBJECT_ID objectID, int meshIndex, const EulerAngles& rot);

		Vector3 GetItemPosition(GAME_OBJECT_ID objectID);
		EulerAngles GetItemRotation(GAME_OBJECT_ID objectID);
		float GetItemScale(GAME_OBJECT_ID objectID);
		EulerAngles GetItemMeshRotation(GAME_OBJECT_ID objectID, int meshIndex);

		std::vector<DisplayItem>& GetItems();

		//Camera settings
		void SetCameraPosition(const Vector3& pos);
		void SetCameraTargetPosition(const Vector3& target);

		Vector3 GetCameraPosition() const;
		Vector3 GetCameraTargetPosition() const;

		Vector3 GetInterpolatedCameraPosition(float t) const;
		Vector3 GetInterpolatedCameraTargetPosition(float t) const;

		void StoreCameraInterpolationData();

		//Inventory override
		bool GetInventoryOverride() const;
		void SetInventoryOverride(bool value);

		int GetInventoryOpenStatus() const;
		void SetInventoryOpenStatus(int value);

	};

	extern DrawItemsController g_DrawItems;
}
