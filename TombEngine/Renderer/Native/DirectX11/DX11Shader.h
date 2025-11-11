#pragma once

#include <d3d11.h>
#include "Renderer/RendererUtils.h"
#include "Renderer/Graphics/IShader.h"
#include "Game/debug/debug.h"
#include <wrl/client.h>
#include <vector>
#include <d3dcompiler.h>
#include <map>

namespace TEN::Renderer::Native::DirectX11
{
	using namespace TEN::Renderer::Utils;
	using namespace TEN::Renderer::Graphics;
	using namespace TEN::Debug;

	using Microsoft::WRL::ComPtr;

	class DX11Shader final : public IShader
	{
	public:
		ComPtr<ID3D11VertexShader> VertexShader = nullptr;
		ComPtr<ID3D11GeometryShader> GeometryShader = nullptr;
		ComPtr<ID3D11PixelShader> PixelShader = nullptr;
		ComPtr<ID3D10Blob> Blob = nullptr;

		DX11Shader()
		{
		}

		~DX11Shader()
		{
			if (VertexShader != nullptr)
			{
				VertexShader->Release();
				VertexShader = nullptr;
			}

			if (GeometryShader != nullptr)
			{
				GeometryShader->Release();
				GeometryShader = nullptr;
			}

			if (PixelShader != nullptr)
			{
				PixelShader->Release();
				PixelShader = nullptr;
			}

			if (Blob != nullptr)
			{
				Blob->Release();
				Blob = nullptr;
			}
		}
	};
}