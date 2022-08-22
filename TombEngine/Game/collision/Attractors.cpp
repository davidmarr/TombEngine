#include "framework.h"
#include "Game/collision/Attractors.h"

#include <ois/OISKeyboard.h>

#include "Game/Lara/lara.h"
#include "Math/Geometry.h"
#include "Renderer/Renderer11.h"
#include "Specific/input.h"

using namespace TEN::Input;
using namespace TEN::Math::Geometry;
using TEN::Renderer::g_Renderer;

namespace TEN::Collision::Attractors
{
	Attractor::Attractor() {}

	Attractor::Attractor(AttractorType type, Vector3 point0, Vector3 point1, int roomNumber0, int roomNumber1)
	{
		this->Type = type;
		this->Point0 = point0;
		this->Point1 = point1;
		this->Length = Vector3::Distance(Point0, Point1);
		this->RoomNumber0 = roomNumber0;
		this->RoomNumber1 = roomNumber1;
	}

	void Attractor::PrintDebugInfo()
	{
		// Set points.
		if (KeyMap[OIS::KeyCode::KC_Q])
			Lara.Attractor.DebugAttractor.SetPoint0(LaraItem->Pose.Position.ToVector3());
		if (KeyMap[OIS::KeyCode::KC_W])
			Lara.Attractor.DebugAttractor.SetPoint1(LaraItem->Pose.Position.ToVector3());

		// Show attractor as white line.
		g_Renderer.AddLine3D(Lara.Attractor.DebugAttractor.GetPoint0(), Lara.Attractor.DebugAttractor.GetPoint1(), Vector4(1, 1, 1, 1));

		// Show tether line. Magenta when in front, white when behind.
		auto closestPoint1 = GetClosestPointOnLine(LaraItem->Pose.Position.ToVector3(), Lara.Attractor.DebugAttractor.GetPoint0(), Lara.Attractor.DebugAttractor.GetPoint1());
		auto front = TranslateVector(LaraItem->Pose.Position, LaraItem->Pose.Orientation.y, LARA_RADIUS, -LARA_HEIGHT);
		
		if (IsPointInFront(LaraItem->Pose, closestPoint1))
			g_Renderer.AddLine3D(front.ToVector3(), closestPoint1, Vector4(1, 0, 1, 1));
		else
			g_Renderer.AddLine3D(front.ToVector3(), closestPoint1, Vector4(1, 1, 1, 1));
	}

	AttractorType Attractor::GetType()
	{
		return Type;
	}

	Vector3 Attractor::GetPoint0()
	{
		return Point0;
	}

	Vector3 Attractor::GetPoint1()
	{
		return Point1;
	}

	float Attractor::GetLength()
	{
		return Length;
	}

	int Attractor::GetRoomNumber0()
	{
		return RoomNumber0;
	}

	int Attractor::GetRoomNumber1()
	{
		return RoomNumber1;
	}

	void Attractor::SetPoint0(Vector3 point)
	{
		this->Point0 = point;
	}

	void Attractor::SetPoint1(Vector3 point)
	{
		this->Point1 = point;
	}

	bool Attractor::IsEdge()
	{
		return (Type == AttractorType::Edge);
	}

	bool Attractor::IsCrevice()
	{
		return (Type == AttractorType::Crevice);
	}

	bool Attractor::IsVerticalPole()
	{
		return (Type == AttractorType::VerticalPole);
	}

	bool Attractor::IsHorizontalPole()
	{
		return (Type == AttractorType::HorizontalPole);
	}

	bool Attractor::IsSwingPole()
	{
		return (Type == AttractorType::SwingPole);
	}

	bool Attractor::IsZipLine()
	{
		return (Type == AttractorType::ZipLine);
	}

	bool Attractor::IsPinnacle()
	{
		return (Type == AttractorType::Pinnacle);
	}

	bool Attractor::IsTightrope()
	{
		return (Type == AttractorType::Tightrope);
	}
}
