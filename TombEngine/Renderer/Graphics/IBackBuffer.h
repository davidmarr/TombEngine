#pragma once

#include "Renderer/Graphics/IRenderTarget2D.h"
#include "Renderer/Graphics/IDepthTarget.h"

namespace TEN::Renderer::Graphics
{
	class IBackBuffer
	{
	private:
		IRenderTarget2D* _renderTarget;
		IDepthTarget* _depthTarget;

	public:
		IBackBuffer(IRenderTarget2D* renderTargert, IDepthTarget* depthTarget)
		{
			_renderTarget = renderTargert;
			_depthTarget = depthTarget;
		}

		IRenderTarget2D* GetRenderTarget() { return _renderTarget; }
		IDepthTarget* GetDepthTarget() { return _depthTarget; }
	};
}
