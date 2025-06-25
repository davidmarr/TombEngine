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
	DrawItemsController g_DrawItems = {};

	void DrawItemsController::AddItem(GAME_OBJECT_ID objectID, const Vector3& position, const EulerAngles& rotation, float scale, int meshBits)
	{
		// Check if item already exists
		for (auto& item : _displayItems)
		{
			if (item.ObjectID == objectID)
			{
				// Update existing item
				item.Position = position;
				item.Orientation = rotation;
				item.Scale = scale;
				item.MeshBits = meshBits;
				return;
			}
		}

		// If at capacity, don’t add new item
		if (_displayItems.size() >= DRAW_ITEM_COUNT_MAX)
			return;

		DisplayItem newItem;
		newItem.ObjectID = objectID;

		newItem.Position = newItem.PrevPosition = position;
		newItem.Orientation = newItem.PrevOrientation = rotation;
		newItem.Scale = newItem.PrevScale = scale;
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

		StoreCameraInterpolationData();
	}

	void DrawItemsController::Draw() const
	{
		for (const auto& item : _displayItems)
		{
			g_Renderer.DrawObjectIn3DSpace(item);
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

	void DrawItemsController::SetItemPosition(GAME_OBJECT_ID objectID, const Vector3& newPos, bool disableInterpolation)
	{
		if (auto* item = SelectItemByID(objectID))
		{
			if (disableInterpolation)
				item->PrevPosition = newPos;

			item->Position = newPos;
		}
	}

	void DrawItemsController::SetItemRotation(GAME_OBJECT_ID objectID, const EulerAngles& newRot, bool disableInterpolation)
	{
		if (auto* item = SelectItemByID(objectID))
		{
			if (disableInterpolation)
				item->PrevOrientation = newRot;

			item->Orientation = newRot;
		}
	}

	void DrawItemsController::SetItemScale(GAME_OBJECT_ID objectID, float newScale, bool disableInterpolation)
	{
		if (auto* item = SelectItemByID(objectID))
		{
			if (disableInterpolation)
				item->PrevScale = newScale;

			item->Scale = newScale;
		}
	}

	void DrawItemsController::SetItemColor(GAME_OBJECT_ID objectID, Color& newColor, bool disableInterpolation)
	{
		if (auto* item = SelectItemByID(objectID))
		{
			if (disableInterpolation)
				item->PrevColor = newColor;

			item->Color = newColor;
		}
	}

	void DrawItemsController::SetItemMeshBits(GAME_OBJECT_ID objectID, int meshbits)
	{
		if (auto* item = SelectItemByID(objectID))
		{
			item->MeshBits = meshbits;
		}

	}

	void DrawItemsController::SetItemMeshRotation(GAME_OBJECT_ID objectID, int meshIndex, const EulerAngles& newRot, bool disableInterpolation)
	{
		if (auto* item = SelectItemByID(objectID))
		{
			if (disableInterpolation)
				item->PrevMeshRotations[meshIndex] = newRot;

			item->MeshRotations[meshIndex] = newRot;
		}

	}

	void DrawItemsController::SetItemVisibility(GAME_OBJECT_ID objectID, bool visible)
	{
		if (auto* item = SelectItemByID(objectID))
		{
			item->Visible = visible;
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

	Color DrawItemsController::GetItemColor(GAME_OBJECT_ID objectID)
	{
		if (auto* item = SelectItemByID(objectID))
		{
			return item->Color;
		}

		return Vector4::Zero;
	}

	bool DrawItemsController::GetItemVisibility(GAME_OBJECT_ID objectID)
	{
		if (auto* item = SelectItemByID(objectID))
		{
			return item->Visible;
		}

		return false;
	}

	EulerAngles DrawItemsController::GetItemMeshRotation(GAME_OBJECT_ID objectID, int meshIndex)
	{
		if (auto* item = SelectItemByID(objectID))
		{
			auto it = item->MeshRotations.find(meshIndex);
			if (it != item->MeshRotations.end())
				return it->second;
			else
				return EulerAngles::Identity;
		}
		return EulerAngles::Identity;
	}

	std::vector<DisplayItem>& DrawItemsController::GetItems()
	{
		return _displayItems;
	}

	void DrawItemsController::SetCameraPosition(const Vector3& pos, bool disableInterpolation)
	{
		if (disableInterpolation)
			_cameraPreviousPosition = pos;

		_cameraPosition = pos;
	}

	void DrawItemsController::SetCameraTargetPosition(const Vector3& target, bool disableInterpolation)
	{
		if (disableInterpolation)
			_targetPreviousPosition = target;

		_targetPosition = target;
	}

	void DrawItemsController::SetAmbientLight(const Vector4& lightColor)
	{
		_ambientLight = lightColor;
	}

	Vector4 DrawItemsController::GetAmbientLight() const
	{
		return _ambientLight;
	}

	Vector3 DrawItemsController::GetCameraPosition() const
	{
		return _cameraPosition;
	}

	Vector3 DrawItemsController::GetCameraTargetPosition() const
	{
		return _targetPosition;
	}

	Vector3 DrawItemsController::GetInterpolatedCameraPosition(float t) const
	{
		return Vector3::Lerp(_cameraPreviousPosition, _cameraPosition, t);
	}

	Vector3 DrawItemsController::GetInterpolatedCameraTargetPosition(float t) const
	{
		return Vector3::Lerp(_targetPreviousPosition, _targetPosition, t);
	}

	void DrawItemsController::StoreCameraInterpolationData()
	{
		_cameraPreviousPosition = _cameraPosition;
		_targetPreviousPosition = _targetPosition;
	}

	bool DrawItemsController::GetInventoryOverride() const
	{
		return _inventoryOverride;
	}

	void DrawItemsController::SetInventoryOverride(bool value)
	{
		_inventoryOverride = value;

	}

	int DrawItemsController::GetInventoryOpenStatus() const
	{
		return _openInventory;
	}

	void DrawItemsController::SetInventoryOpenStatus(int value)
	{
		_openInventory = value;
	}

}
