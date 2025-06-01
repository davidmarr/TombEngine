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
	void DrawItemsController::AddItem(GAME_OBJECT_ID objectID, const Vector3& origin, float scale, float opacity, int meshBits)
	{
		// Check if item already exists
		for (auto& item : _displayItems)
		{
			if (item.ObjectID == objectID)
			{
				// Update existing item
				item.Position = origin;
				item.Scale = scale;
				return;
			}
		}

		// If at capacity, don’t add new item
		if (_displayItems.size() >= DRAW_ITEM_COUNT_MAX)
			return;

		DisplayItem newItem;
		newItem.ObjectID = objectID;

		newItem.Position = origin;
		newItem.PrevPosition = newItem.Position;

		newItem.Scale = newItem.PrevScale = scale;
		newItem.Opacity = newItem.PrevOpacity = opacity;
		newItem.MeshBits = meshBits;
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
		if (_displayItems.empty())
			return;

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

	void DrawItemsController::SetItemAlpha(GAME_OBJECT_ID objectID, float newAlpha)
	{
		if (auto* item = SelectItemByID(objectID))
		{
			item->Opacity = newAlpha;
		}
	}

	void DrawItemsController::SetItemMeshBits(GAME_OBJECT_ID objectID, int meshbits)
	{
		if (auto* item = SelectItemByID(objectID))
		{
			item->MeshBits = meshbits;
		}

	}

	void DrawItemsController::SetItemMeshRotation(GAME_OBJECT_ID objectID, int meshIndex, EulerAngles& rot)
	{

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

	void DrawItemsController::SetCameraPosition(const Vector3& pos)
	{
		_cameraPosition = pos;
	}

	void DrawItemsController::SetCameraTarget(const Vector3& target)
	{
		_targetPosition = target;
	}

	Vector3 DrawItemsController::GetCameraPosition() const
	{
		return _cameraPosition;
	}

	Vector3 DrawItemsController::GetTargetPosition() const
	{
		return _targetPosition;
	}

}
