#pragma once
#include <vector>
#include <SimpleMath.h>

namespace TEN::Renderer
{
	struct RendererPortal
	{
		bool Visited;
		short AdjoiningRoom;
		Vector3 Normal;
		Vector4 AbsoluteVertices[4];
		Vector4 ClipSpaceVertices[4];
		Vector3 CameraViewVector;
	};
}
