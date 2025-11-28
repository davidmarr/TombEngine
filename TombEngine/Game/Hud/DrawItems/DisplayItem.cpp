#include "framework.h"
#include "Game/Hud/DrawItems/DisplayItem.h"

#include "Math/Math.h"
#include "Renderer/Renderer.h"
#include "Specific/clock.h"

using namespace TEN::Math;

namespace TEN::Hud
{
	void DisplayItem::SetName(std::string itemName)
	{
		ItemName = itemName;
	}

	void DisplayItem::SetObjectID(GAME_OBJECT_ID objectID)
	{
		ObjectID = objectID;
	}

	void DisplayItem::SetPosition(const Vector3& newPos, bool disableInterpolation)
	{
		if (disableInterpolation)
			PrevPosition = newPos;

		Position = newPos;
	}

	void DisplayItem::SetRotation(const EulerAngles& newRot, bool disableInterpolation)
	{
		if (disableInterpolation)
			PrevOrientation = newRot;

		Orientation = newRot;
	}

	void DisplayItem::SetScale(float newScale, bool disableInterpolation)
	{
		if (disableInterpolation)
			PrevScale = newScale;

		Scale = newScale;
	}

	void DisplayItem::SetColor(Color& newColor, bool disableInterpolation)
	{
		if (disableInterpolation)
			PrevColor = newColor;

		ItemColor = newColor;
	}

	void DisplayItem::SetVisibility(bool visible)
	{
		Visible = visible;
	}

	void DisplayItem::SetMeshBits(int meshbits)
	{
		MeshBits = meshbits;
	}

	void DisplayItem::SetMeshVisibility(int meshIndex, bool isVisible)
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

	void DisplayItem::SetMeshRotation(int meshIndex, const EulerAngles& newRot, bool disableInterpolation)
	{
		if (disableInterpolation)
			PrevMeshRotations[meshIndex] = newRot;

		MeshRotations[meshIndex] = newRot;
	}

	void DisplayItem::SetAnimation(int animation)
	{
		//add checks for bounds of animation and frame
		AnimNumber = animation;
	}

	void DisplayItem::SetFrame(int frame)
	{
		//add checks for bounds of animation and frame
		FrameNumber = frame;
	}

	std::string DisplayItem::GetName() const
	{
		return ItemName;
	}

	GAME_OBJECT_ID DisplayItem::GetObjectID() const
	{
		return ObjectID;
	}

	Vector3 DisplayItem::GetPosition() const
	{
		return Position;
	}

	EulerAngles DisplayItem::GetRotation() const
	{
		return Orientation;
	}

	float DisplayItem::GetScale() const
	{
		return Scale;
	}

	Color DisplayItem::GetColor() const
	{
		return ItemColor;
	}

	bool DisplayItem::GetVisibility() const
	{
		return Visible;
	}

	int DisplayItem::GetMeshBits() const
	{
		return MeshBits.ToPackedBits();
	}

	bool DisplayItem::GetMeshVisibility(int meshIndex) const
	{
		return MeshBits.Test(meshIndex);
	}

	EulerAngles DisplayItem::GetMeshRotation(int meshIndex) const
	{
		auto it = MeshRotations.find(meshIndex);
		if (it != MeshRotations.end())
			return it->second;
		else
			return EulerAngles::Identity;

	}

	int DisplayItem::GetAnimation() const
	{
		return AnimNumber;
	}

	int DisplayItem::GetFrame() const
	{
		return FrameNumber;
	}

	int DisplayItem::GetPreviousFrame() const
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
