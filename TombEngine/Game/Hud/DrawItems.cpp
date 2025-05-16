#include "framework.h"
#include "Game/Hud/DrawItems.h"

#include "Math/Math.h"
#include "Renderer/Renderer.h"
#include "Scripting/Include/Flow/ScriptInterfaceFlowHandler.h"
#include "Specific/clock.h"

using namespace TEN::Math;
using TEN::Renderer::g_Renderer;

namespace TEN::Hud
{
	void DrawItemsController::AddItem(GAME_OBJECT_ID objectID, const Vector3& origin, float scale)
	{
		if (_displayItems.size() >= DRAW_ITEM_COUNT_MAX)
			return;

		DisplayItem newItem;
		newItem.ObjectID = objectID;

		newItem.Position = origin;
		newItem.PrevPosition = newItem.Position;

		newItem.Scale = newItem.PrevScale = scale;
		newItem.Opacity = newItem.PrevOpacity = 1.0f;

		_displayItems.push_back(newItem);
	}
	void DrawItemsController::RemoveItem(GAME_OBJECT_ID objectID)
	{
		auto item = std::find_if(_displayItems.begin(), _displayItems.end(),
			[&](const DisplayItem& item)
			{
				return item.ObjectID == objectID;
			});

		if (item != _displayItems.end())
		{
			int removedIndex = static_cast<int>(std::distance(_displayItems.begin(), item));
			_displayItems.erase(item);
		}
	}

	void DrawItemsController::Update()
	{
		for (auto& item : _displayItems)
		{
			item.StoreInterpolationData();
		}
	}

	void DrawItemsController::Draw() const
	{
		for (const auto& item : _displayItems)
		{
			g_Renderer.DrawItem(item);
		}
	}

	void DrawItemsController::Clear()
	{
		_displayItems.clear();
	}

	DisplayItem* DrawItemsController::SelectItemByID(GAME_OBJECT_ID id)
	{
		for (auto& item : _displayItems)
		{
			if (item.ObjectID == id)
				return &item;
		}
		return nullptr;
	}

	void DrawItemsController::SetItemPosition(GAME_OBJECT_ID id, const Vector3& newPos)
	{
		if (auto* item = SelectItemByID(id))
		{
			item->Position = newPos;
		}
	}

	void DrawItemsController::SetItemRotation(GAME_OBJECT_ID id, const EulerAngles& newRot)
	{
		if (auto* item = SelectItemByID(id))
		{
			item->Orientation = newRot;
		}
	}

	void DrawItemsController::SetItemScale(GAME_OBJECT_ID id, float newScale)
	{
		if (auto* item = SelectItemByID(id))
		{
			item->Scale = newScale;
		}
	}

}
