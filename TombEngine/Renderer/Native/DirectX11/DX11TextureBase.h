#pragma once
#include <d3d11.h>
#include <string>
#include <wrl/client.h>
#include "Renderer/Graphics/ITextureBase.h"

namespace TEN::Renderer::Native::DirectX11
{
	using namespace TEN::Renderer::Graphics;
	
	using Microsoft::WRL::ComPtr;
	
	class DX11TextureBase : public ITextureBase
	{
	public:
		ComPtr<ID3D11ShaderResourceView> ShaderResourceView;
	};
}
