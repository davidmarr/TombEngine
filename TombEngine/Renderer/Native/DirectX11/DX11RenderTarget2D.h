#pragma once
#include <vector>
#include <d3d11.h>
#include <wrl/client.h>
#include "Renderer/Native/DirectX11/DX11TextureBase.h"
#include "Renderer/RendererUtils.h"
#include "Renderer/Graphics/IRenderTarget2D.h"

namespace TEN::Renderer::Native::DirectX11
{
	using namespace TEN::Renderer::Utils;
	using Microsoft::WRL::ComPtr;

	class DX11RenderTarget2D : public IRenderTarget2D, protected DX11Texture2D
	{
	private:
		std::vector<ComPtr<ID3D11RenderTargetView>> _renderTargetViews;

	public:
		int GetWidth() override { return _width; }
		int GetHeight() override { return _height; }

		int GetArraySize() override { return _renderTargetViews.size(); }

		ID3D11RenderTargetView* GetRenderTargetView(int arrayIndex) const noexcept { return _renderTargetViews[arrayIndex].Get(); }
		ID3D11RenderTargetView* GetRenderTargetView()               const noexcept { return GetRenderTargetView(0); }

		DX11RenderTarget2D() = default;

		// Default constructor
		DX11RenderTarget2D(ID3D11Device* device, int width, int height, DXGI_FORMAT colorFormat, bool isTypeless)
		{
			HRESULT res;

			_width = width;
			_height = height;
			
			// Texture
			D3D11_TEXTURE2D_DESC desc = {};
			desc.Width = width;
			desc.Height = height;
			desc.MipLevels = 1;
			desc.ArraySize = 1;
			desc.Format = isTypeless ? MakeTypeless(colorFormat) : colorFormat;
			desc.SampleDesc.Count = 1;
			desc.SampleDesc.Quality = 0;
			desc.Usage = D3D11_USAGE_DEFAULT;
			desc.BindFlags = D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
			desc.CPUAccessFlags = 0;
			desc.MiscFlags = 0;

			res = device->CreateTexture2D(&desc, nullptr, _texture.GetAddressOf());
			throwIfFailed(res);
			
			// RTV
			D3D11_RENDER_TARGET_VIEW_DESC rtvDesc = {};
			rtvDesc.Format = colorFormat;
			rtvDesc.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2D;
			rtvDesc.Texture2D.MipSlice = 0;

			ComPtr<ID3D11RenderTargetView> rtv;
			res = device->CreateRenderTargetView(_texture.Get(), &rtvDesc, rtv.GetAddressOf());
			throwIfFailed(res);
			_renderTargetViews.push_back(rtv); // copy -> AddRef (ok)

			// SRV
			D3D11_SHADER_RESOURCE_VIEW_DESC srvDesc = {};
			srvDesc.Format = colorFormat;
			srvDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
			srvDesc.Texture2D.MostDetailedMip = 0;
			srvDesc.Texture2D.MipLevels = 1;

			_shaderResourceView.Reset();
			res = device->CreateShaderResourceView(_texture.Get(), &srvDesc, _shaderResourceView.GetAddressOf());
			throwIfFailed(res);
		}

		// Used by SMAA because it needs to have two render targets with same texture
		DX11RenderTarget2D(ID3D11Device* device, DX11RenderTarget2D* parent, DXGI_FORMAT colorFormat)
		{
			HRESULT res;

			// Copy ComPtr from parent
			ID3D11Texture2D* texture = parent->GetTexture();
			texture->AddRef();
			_texture.Attach(texture);

			// RTV with different format
			D3D11_RENDER_TARGET_VIEW_DESC rtvDesc = {};
			rtvDesc.Format = colorFormat;
			rtvDesc.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2D;
			rtvDesc.Texture2D.MipSlice = 0;

			ComPtr<ID3D11RenderTargetView> rtv;
			res = device->CreateRenderTargetView(_texture.Get(), &rtvDesc, rtv.GetAddressOf());
			throwIfFailed(res);
			_renderTargetViews.push_back(rtv);

			// SRV
			D3D11_SHADER_RESOURCE_VIEW_DESC srvDesc = {};
			srvDesc.Format = colorFormat;
			srvDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
			srvDesc.Texture2D.MostDetailedMip = 0;
			srvDesc.Texture2D.MipLevels = 1;

			_shaderResourceView.Reset();
			res = device->CreateShaderResourceView(_texture.Get(), &srvDesc, _shaderResourceView.GetAddressOf());
			throwIfFailed(res);
		}

		// Constructor for the backbuffer only
		DX11RenderTarget2D(ID3D11Device* device, ID3D11Texture2D* textureRaw)
		{
			HRESULT res;

			// Prendiamo ownership della nostra ref
			textureRaw->AddRef();   // Increment COM ref 
			_texture.Attach(textureRaw);

			// RTV
			D3D11_TEXTURE2D_DESC tdesc = {};
			_texture->GetDesc(&tdesc);

			_width = tdesc.Width;
			_height = tdesc.Height;

			D3D11_RENDER_TARGET_VIEW_DESC rtvDesc = {};
			rtvDesc.Format = tdesc.Format;
			rtvDesc.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2D;
			rtvDesc.Texture2D.MipSlice = 0;

			ComPtr<ID3D11RenderTargetView> rtv;
			res = device->CreateRenderTargetView(_texture.Get(), &rtvDesc, rtv.GetAddressOf());
			throwIfFailed(res);
			_renderTargetViews.push_back(rtv);

			// SRV
			if (tdesc.BindFlags & D3D11_BIND_SHADER_RESOURCE)
			{
				D3D11_SHADER_RESOURCE_VIEW_DESC srvDesc = {};
				srvDesc.Format = tdesc.Format;
				srvDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
				srvDesc.Texture2D.MostDetailedMip = 0;
				srvDesc.Texture2D.MipLevels = 1;

				_shaderResourceView.Reset();
				res = device->CreateShaderResourceView(_texture.Get(), &srvDesc, _shaderResourceView.GetAddressOf());
				throwIfFailed(res);
			}
		}

		// Texture array
		DX11RenderTarget2D(ID3D11Device* device, int width, int height, int count, DXGI_FORMAT colorFormat)
		{
			HRESULT res;

			_width = width;
			_height = height;

			D3D11_TEXTURE2D_DESC desc = {};
			desc.Width = width;
			desc.Height = height;
			desc.MipLevels = 1;
			desc.ArraySize = count;
			desc.Format = colorFormat;
			desc.SampleDesc.Count = 1;
			desc.SampleDesc.Quality = 0;
			desc.Usage = D3D11_USAGE_DEFAULT;
			desc.BindFlags = D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
			desc.CPUAccessFlags = 0;
			desc.MiscFlags = 0x0;

			res = device->CreateTexture2D(&desc, NULL, _texture.GetAddressOf());
			throwIfFailed(res);

			// RTV
			D3D11_RENDER_TARGET_VIEW_DESC viewDesc = {};
			viewDesc.Format = desc.Format;
			viewDesc.Texture2DArray.ArraySize = 1;
			viewDesc.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2DARRAY;

			for (int i = 0; i < count; i++)
			{
				ComPtr<ID3D11RenderTargetView> rtv;
				viewDesc.Texture2DArray.FirstArraySlice = D3D11CalcSubresource(0, i, 1);
				res = device->CreateRenderTargetView(_texture.Get(), &viewDesc, rtv.GetAddressOf());
				throwIfFailed(res);
				_renderTargetViews.push_back(rtv);
			}

			// SRV
			D3D11_SHADER_RESOURCE_VIEW_DESC shaderDesc = {};
			shaderDesc.Format = desc.Format;
			shaderDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2DARRAY;
			shaderDesc.Texture2DArray.MostDetailedMip = 0;
			shaderDesc.Texture2DArray.MipLevels = 1;
			shaderDesc.Texture2DArray.ArraySize = count;
			shaderDesc.Texture2DArray.FirstArraySlice = 0;

			res = device->CreateShaderResourceView(_texture.Get(), &shaderDesc, _shaderResourceView.GetAddressOf());
			throwIfFailed(res);
		}

	private:
		static DXGI_FORMAT MakeTypeless(DXGI_FORMAT format)
		{
			switch (format)
			{
			case DXGI_FORMAT_R8G8B8A8_UNORM_SRGB:
			case DXGI_FORMAT_R8G8B8A8_UNORM:
			case DXGI_FORMAT_R8G8B8A8_UINT:
			case DXGI_FORMAT_R8G8B8A8_SNORM:
			case DXGI_FORMAT_R8G8B8A8_SINT:
				return DXGI_FORMAT_R8G8B8A8_TYPELESS;

			case DXGI_FORMAT_BC1_UNORM_SRGB:
			case DXGI_FORMAT_BC1_UNORM:
				return DXGI_FORMAT_BC1_TYPELESS;

			case DXGI_FORMAT_BC2_UNORM_SRGB:
			case DXGI_FORMAT_BC2_UNORM:
				return DXGI_FORMAT_BC2_TYPELESS;

			case DXGI_FORMAT_BC3_UNORM_SRGB:
			case DXGI_FORMAT_BC3_UNORM:
				return DXGI_FORMAT_BC3_TYPELESS;

			default:
				return format;
			}
		}
	};
}
