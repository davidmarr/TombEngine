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

		void Update(bool isHead);

		void StoreInterpolationData()
		{
			PrevPosition = Position;
			PrevOrientation = Orientation;
			PrevScale = Scale;
			PrevOpacity = Opacity;
		}
	};

	class DrawItemsController
	{
	private:
		// Constants

		static constexpr auto DRAW_ITEM_COUNT_MAX		   = 64;

		// Fields

		std::vector<DisplayItem> _displayItems = {};

	public:
		// Utilities

		void AddItem(GAME_OBJECT_ID objectID, const Vector2& origin);
		void RemoveItem(GAME_OBJECT_ID objectID, const Vector3& pos, unsigned int count = DISPLAY_PICKUP_COUNT_ARG_DEFAULT);
		void AddDisplayPickup(const ItemInfo& item);

		void Update();
		void Draw() const;
		void Clear();

	private:
		// Helpers

	};
}
