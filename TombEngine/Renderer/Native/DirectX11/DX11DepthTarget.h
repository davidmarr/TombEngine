#pragma once

#ifdef SDL_PLATFORM_WIN32

#include <d3d11.h>
#include <string>
#include <vector>
#include <wrl/client.h>
#include "Renderer/RendererUtils.h"
#include "Renderer/Graphics/IDepthTarget.h"

namespace TEN::Renderer::Native::DirectX11
{
	using namespace TEN::Renderer::Utils;
	using namespace TEN::Renderer::Graphics;

	using Microsoft::WRL::ComPtr;

	class DX11DepthTarget : public IDepthTarget
	{
	private:
		int _width;
		int _height;
		std::vector<ComPtr<ID3D11DepthStencilView>> _depthStencilViews;
		ComPtr<ID3D11Texture2D>	_depthStencilTexture;

	public:
		DX11DepthTarget() = default;
		~DX11DepthTarget() = default;

		int GetArraySize() override { return (int)_depthStencilViews.size(); }

		ID3D11DepthStencilView* GetD3D11DepthStencilView(int arrayIndex) const noexcept { return _depthStencilViews[arrayIndex].Get(); }
		ID3D11DepthStencilView* GetD3D11DepthStencilView()               const noexcept { return GetD3D11DepthStencilView(0); }
		ID3D11Texture2D*	    GetD3D11Texture()						 const noexcept { return _depthStencilTexture.Get(); }

		DX11DepthTarget(ID3D11Device* device, int width, int height, DXGI_FORMAT depthFormat)
		{
			HRESULT res;

			_width = width;
			_height = height;

			// Texture
			auto depthTexDesc = D3D11_TEXTURE2D_DESC{};
			depthTexDesc.Width = width;
			depthTexDesc.Height = height;
			depthTexDesc.MipLevels = 1;
			depthTexDesc.ArraySize = 1;
			depthTexDesc.SampleDesc.Count = 1;
			depthTexDesc.SampleDesc.Quality = 0;
			depthTexDesc.Format = depthFormat;
			depthTexDesc.Usage = D3D11_USAGE_DEFAULT;
			depthTexDesc.BindFlags = D3D11_BIND_DEPTH_STENCIL;
			depthTexDesc.CPUAccessFlags = 0;
			depthTexDesc.MiscFlags = 0;

			res = device->CreateTexture2D(&depthTexDesc, nullptr, &_depthStencilTexture);
			throwIfFailed(res);

			// DSV
			auto dsvDesc = D3D11_DEPTH_STENCIL_VIEW_DESC{};
			dsvDesc.Format = depthTexDesc.Format;
			dsvDesc.Flags = 0;
			dsvDesc.ViewDimension = D3D11_DSV_DIMENSION_TEXTURE2D;
			dsvDesc.Texture2D.MipSlice = 0;

			ComPtr<ID3D11DepthStencilView> dsv;
			res = device->CreateDepthStencilView(_depthStencilTexture.Get(), &dsvDesc, &dsv);
			throwIfFailed(res);
			_depthStencilViews.push_back(dsv);
		}

		DX11DepthTarget(ID3D11Device* device, int width, int height, int count, DXGI_FORMAT depthFormat)
		{
			HRESULT res;

			_width = width;
			_height = height;

			// Texture
			D3D11_TEXTURE2D_DESC depthTexDesc = {};
			depthTexDesc.Width = width;
			depthTexDesc.Height = height;
			depthTexDesc.MipLevels = 1;
			depthTexDesc.ArraySize = count;
			depthTexDesc.SampleDesc.Count = 1;
			depthTexDesc.SampleDesc.Quality = 0;
			depthTexDesc.Format = depthFormat;
			depthTexDesc.Usage = D3D11_USAGE_DEFAULT;
			depthTexDesc.BindFlags = D3D11_BIND_DEPTH_STENCIL;
			depthTexDesc.CPUAccessFlags = 0;
			depthTexDesc.MiscFlags = 0x0;

			res = device->CreateTexture2D(&depthTexDesc, nullptr, _depthStencilTexture.GetAddressOf());
			throwIfFailed(res);

			// DSV
			D3D11_DEPTH_STENCIL_VIEW_DESC dsvDesc = {};
			dsvDesc.Format = depthTexDesc.Format;
			dsvDesc.Flags = 0;
			dsvDesc.ViewDimension = D3D11_DSV_DIMENSION_TEXTURE2DARRAY;
			dsvDesc.Texture2DArray.ArraySize = 1;

			for (int i = 0; i < count; i++)
			{
				ComPtr<ID3D11DepthStencilView> dsv;
				dsvDesc.Texture2DArray.FirstArraySlice = D3D11CalcSubresource(0, i, 1);
				res = device->CreateDepthStencilView(_depthStencilTexture.Get(), &dsvDesc, dsv.GetAddressOf());
				throwIfFailed(res);
				_depthStencilViews.push_back(dsv);
			}
		}
	};
}

#endif