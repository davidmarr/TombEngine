#pragma once

#include "Renderer/Graphics/IRenderTarget2D.h"
#include "Renderer/Graphics/IDepthTarget.h"

namespace TEN::Renderer::Graphics
{
	class IRenderSurface2D
	{
	private:
		IRenderTarget2D*	_renderTarget	= nullptr;
		IDepthTarget*		_depthTarget	= nullptr;

	public:
		IRenderSurface2D(IRenderTarget2D* renderTarget, IDepthTarget* depthTarget)
		{
			_renderTarget = renderTarget;
			_depthTarget = depthTarget;
		}

		~IRenderSurface2D()
		{
			if (_renderTarget != nullptr)
				delete _renderTarget;
			if (_depthTarget != nullptr)
				delete _depthTarget;
		}

		IRenderTarget2D* GetRenderTarget() { return _renderTarget; }
		IDepthTarget* GetDepthTarget() { return _depthTarget; }
	};
}
