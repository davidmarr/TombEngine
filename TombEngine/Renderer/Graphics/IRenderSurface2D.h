#pragma once

#include "Renderer/Graphics/IRenderTarget2D.h"
#include "Renderer/Graphics/IDepthTarget.h"

namespace TEN::Renderer::Graphics
{
	class IRenderSurface2D
	{
	private:
		IRenderTarget2D* _renderTarget;
		IDepthTarget* _depthTarget;

	public:
		IRenderSurface2D(IRenderTarget2D* renderTarget, IDepthTarget* depthTarget)
		{
			_renderTarget = renderTarget;
			_depthTarget = depthTarget;
		}

		IRenderTarget2D* GetRenderTarget() { return _renderTarget; }
		IDepthTarget* GetDepthTarget() { return _depthTarget; }
	};
}
