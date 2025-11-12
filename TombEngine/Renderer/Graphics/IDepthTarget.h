#pragma once

namespace TEN::Renderer::Graphics
{
	class IDepthTarget
	{
		virtual int GetArraySize() = 0;
	};

	struct IDepthTargetBinding
	{
		IDepthTarget* DepthTarget;
		int ArrayIndex;

		IDepthTargetBinding(IDepthTarget* depthTarget, int arrayIndex)
		{
			DepthTarget = depthTarget;
			ArrayIndex = arrayIndex;
		}
	};
}
