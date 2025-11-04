#pragma once

#include "Renderer/Graphics/ITextureBase.h"
#include "Renderer/Graphics/IRenderTargetView.h"
#include "Renderer/Graphics/IDepthStencilView.h"

namespace TEN::Renderer::Graphics
{
	class IRenderTarget2D : public ITextureBase
	{
	public:
		virtual int GetArraySize() = 0;
		
		virtual IRenderTargetView* GetRenderTargetView(int arrayIndex) = 0;
		IRenderTargetView* GetRenderTargetView() { return GetRenderTargetView(0); }

		virtual IDepthStencilView* GetDepthStencilView(int arrayIndex) = 0;
		IDepthStencilView* GetDepthStencilView() { return GetDepthStencilView(0); }
	};
}
