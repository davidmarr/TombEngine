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
		
		Vector3		PrevPosition	= Vector3::Zero;
		EulerAngles PrevOrientation = EulerAngles::Identity;
		float		PrevScale		= 0.0f;
		float		PrevOpacity		= 0.0f;

		void StoreInterpolationData()
		{
			PrevPosition = Position;
			PrevOrientation = Orientation;
			PrevScale = Scale;
			PrevOpacity = Opacity;
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
	};

	class DrawItemsController
	{
	private:
		// Constants
		static constexpr auto DRAW_ITEM_COUNT_MAX	= 64;

		// Fields
		std::vector<DisplayItem> _displayItems = {};

	public:

		void AddItem(GAME_OBJECT_ID objectID, const Vector3& origin, float scale);
		void RemoveItem(GAME_OBJECT_ID objectID);

		void Update();
		void Draw() const;
		void Clear();

		DisplayItem* SelectItemByID(GAME_OBJECT_ID id);

		void DrawItemsController::SetItemPosition(GAME_OBJECT_ID id, const Vector3& newPos);
		void DrawItemsController::SetItemRotation(GAME_OBJECT_ID id, const EulerAngles& newRot);
		void DrawItemsController::SetItemScale(GAME_OBJECT_ID id, float newScale);

		std::vector<DisplayItem>& GetItems() { return _displayItems; }
	};
}
