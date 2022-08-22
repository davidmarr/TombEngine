#pragma once
#include "Game/room.h"

namespace TEN::Collision::Attractors
{
	constexpr auto MAX_ATTRACTORS = 64;

	enum class AttractorType
	{
		None,
		Edge,
		Crevice,
		VerticalPole,
		HorizontalPole,
		SwingPole,
		ZipLine,
		Pinnacle,
		Tightrope
	};

	class Attractor
	{
	private:
		AttractorType Type		  = AttractorType::None;
		float		  Length	  = 0.0f;
		Vector3		  Point0	  = Vector3::Zero;
		Vector3		  Point1	  = Vector3::Zero;
		int			  RoomNumber0 = NO_ROOM;
		int			  RoomNumber1 = NO_ROOM;

	public:
		Attractor();
		Attractor(AttractorType type, Vector3 point0, Vector3 point1, int roomNumber0, int roomNumber1);

		void PrintDebugInfo();

		AttractorType GetType();
		float		  GetLength();
		Vector3		  GetPoint0();
		Vector3		  GetPoint1();
		int			  GetRoomNumber0();
		int			  GetRoomNumber1();

		void SetPoint0(Vector3 point);
		void SetPoint1(Vector3 point);

		bool IsEdge();
		bool IsCrevice();
		bool IsVerticalPole();
		bool IsHorizontalPole();
		bool IsSwingPole();
		bool IsZipLine();
		bool IsPinnacle();
		bool IsTightrope();
	};

	struct AttractorData
	{
		Attractor* Ptr = nullptr;

		bool IsIntersected;
		bool IsInFront;

		float Distance2D;
		float Distance3D;
		int Gradient;

		Vector3 IntersectionPoint;
	};
}
