#include "framework.h"
#include "Game/Hud/DrawItems/DisplayItem.h"

#include "Math/Math.h"
#include "Renderer/Renderer.h"
#include "Specific/clock.h"

using namespace TEN::Math;

namespace TEN::Hud
{
	void DisplayItem::SetItemName(std::string itemName)
	{
		ItemName = itemName;
	}

	void DisplayItem::SetItemObjectID(GAME_OBJECT_ID objectID)
	{
		ObjectID = objectID;
	}

	void DisplayItem::SetItemPosition(const Vector3& newPos, bool disableInterpolation)
	{
		if (disableInterpolation)
			PrevPosition = newPos;

		Position = newPos;
	}

	void DisplayItem::SetItemRotation(const EulerAngles& newRot, bool disableInterpolation)
	{
		if (disableInterpolation)
			PrevOrientation = newRot;

		Orientation = newRot;
	}

	void DisplayItem::SetItemScale(float newScale, bool disableInterpolation)
	{
		if (disableInterpolation)
			PrevScale = newScale;

		Scale = newScale;
	}

	void DisplayItem::SetItemColor(Color& newColor, bool disableInterpolation)
	{
		if (disableInterpolation)
			PrevColor = newColor;

		ItemColor = newColor;
	}

	void DisplayItem::SetItemVisibility(bool visible)
	{
		Visible = visible;
	}

	void DisplayItem::SetItemMeshBits(int meshbits)
	{
		MeshBits = meshbits;
	}

	void DisplayItem::SetItemMeshVisibility(int meshIndex, bool isVisible)
	{
		if (!MeshExists(meshIndex))
			return;

		if (isVisible)
		{
			MeshBits.Set(meshIndex);
		}
		else
		{
			MeshBits.Clear(meshIndex);
		}
	}

	void DisplayItem::SetItemMeshRotation(int meshIndex, const EulerAngles& newRot, bool disableInterpolation)
	{
		if (disableInterpolation)
			PrevMeshRotations[meshIndex] = newRot;

		MeshRotations[meshIndex] = newRot;
	}

	void DisplayItem::SetItemAnimation(int animation)
	{
		//add checks for bounds of animation and frame
		AnimNumber = animation;
	}

	void DisplayItem::SetItemFrame(int frame)
	{
		//add checks for bounds of animation and frame
		FrameNumber = frame;
	}

	std::string DisplayItem::GetItemName() const
	{
		return ItemName;
	}

	GAME_OBJECT_ID DisplayItem::GetItemObjectID() const
	{
		return ObjectID;
	}

	Vector3 DisplayItem::GetItemPosition() const
	{
		return Position;
	}

	EulerAngles DisplayItem::GetItemRotation() const
	{
		return Orientation;
	}

	float DisplayItem::GetItemScale() const
	{
		return Scale;
	}

	Color DisplayItem::GetItemColor() const
	{
		return ItemColor;
	}

	bool DisplayItem::GetItemVisibility() const
	{
		return Visible;
	}

	int DisplayItem::GetItemMeshBits() const
	{
		return MeshBits.ToPackedBits();
	}

	bool DisplayItem::GetItemMeshVisibility(int meshIndex) const
	{
		return MeshBits.Test(meshIndex);
	}

	EulerAngles DisplayItem::GetItemMeshRotation(int meshIndex) const
	{
		auto it = MeshRotations.find(meshIndex);
		if (it != MeshRotations.end())
			return it->second;
		else
			return EulerAngles::Identity;

	}

	int DisplayItem::GetItemAnimation() const
	{
		return AnimNumber;
	}

	int DisplayItem::GetItemFrame() const
	{
		return FrameNumber;
	}

	int DisplayItem::GetItemPreviousFrame() const
	{
		return PrevFrameNumber;
	}

	// Interpolation Helpers
	void DisplayItem::StoreInterpolationData()
	{
		PrevPosition = Position;
		PrevOrientation = Orientation;
		PrevScale = Scale;
		PrevColor = ItemColor;
		PrevMeshRotations = MeshRotations;
		PrevFrameNumber = FrameNumber;
	}

	Vector3 DisplayItem::GetInterpolatedPosition(float t) const
	{
		return Vector3::Lerp(PrevPosition, Position, t);
	}

	EulerAngles DisplayItem::GetInterpolatedOrientation(float t) const
	{
		return EulerAngles::Lerp(PrevOrientation, Orientation, t);
	}

	float DisplayItem::GetInterpolatedScale(float t) const
	{
		return Lerp(PrevScale, Scale, t);
	}

	Color DisplayItem::GetInterpolatedColor(float t) const
	{
		return Color::Lerp(PrevColor, ItemColor, t);
	}

	EulerAngles DisplayItem::GetInterpolatedMeshRotation(int meshIndex, float t) const
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

	bool DisplayItem::MeshExists(int index) const
	{
		if (index < 0 || index >= Objects[ObjectID].nmeshes)
		{
			return false;
		}

		return true;
	}

}
