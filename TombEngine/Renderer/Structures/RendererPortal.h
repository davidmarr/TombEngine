#pragma once
#include <vector>
#include <SimpleMath.h>

struct MESH_INFO;

namespace TEN::Renderer
{
	struct RendererPortal
	{
		Vector3 AbsoluteCoordinates[4];
		Vector4 ScreenCoordinates[4];
		Vector3 ViewDirection;
		Vector3 Normal;
		bool Visited;
		bool NotVisible;
		short Room;
	};
}
