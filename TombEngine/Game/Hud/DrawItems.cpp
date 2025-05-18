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

	DisplayItem* DrawItemsController::SelectItemByID(GAME_OBJECT_ID objectID)
	{
		for (auto& item : _displayItems)
		{
			if (item.ObjectID == objectID)
				return &item;
		}
		return nullptr;
	}

	void DrawItemsController::SetItemPosition(GAME_OBJECT_ID objectID, const Vector3& newPos)
	{
		if (auto* item = SelectItemByID(objectID))
		{
			item->Position = newPos;
		}
	}

	void DrawItemsController::SetItemRotation(GAME_OBJECT_ID objectID, const EulerAngles& newRot)
	{
		if (auto* item = SelectItemByID(objectID))
		{
			item->Orientation = newRot;
		}
	}

	void DrawItemsController::SetItemScale(GAME_OBJECT_ID objectID, float newScale)
	{
		if (auto* item = SelectItemByID(objectID))
		{
			item->Scale = newScale;
		}
	}

	Vector3 DrawItemsController::GetItemPosition(GAME_OBJECT_ID objectID)
	{
		if (auto* item = SelectItemByID(objectID))
		{
			return item->Position;
		}

		return Vector3::Zero;
	}

	EulerAngles DrawItemsController::GetItemRotation(GAME_OBJECT_ID objectID)
	{
		if (auto* item = SelectItemByID(objectID))
		{
			return item->Orientation;
		}

		return EulerAngles::Identity;
	}

	float DrawItemsController::GetItemScale(GAME_OBJECT_ID objectID)
	{
		if (auto* item = SelectItemByID(objectID))
		{
			return item->Scale;
		}

		return 0.0f;
	}

	std::vector<DisplayItem>& DrawItemsController::GetItems()
	{
		return _displayItems;
	}

}
