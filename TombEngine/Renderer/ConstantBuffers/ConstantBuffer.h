#pragma once

#include <d3d11.h>
#include <wrl/client.h>

#include "Game/Debug/Debug.h"
#include "Renderer/RendererUtils.h"
#include "Renderer/Graphics/VRAMTracker.h"

namespace TEN::Renderer::ConstantBuffers
{
	template <typename CBuff>
	class ConstantBuffer
	{
		ComPtr<ID3D11Buffer> buffer;
		size_t _vramSize = 0;

	public:
		ConstantBuffer() = default;

		ConstantBuffer(ConstantBuffer&& other) noexcept
			: buffer(std::move(other.buffer)), _vramSize(other._vramSize)
		{
			other._vramSize = 0;
		}

		ConstantBuffer& operator=(ConstantBuffer&& other) noexcept
		{
			if (this != &other)
			{
				if (_vramSize > 0)
					Graphics::VRAMTracker::Get().Remove(Graphics::VRAMCategory::ConstantBuffer, _vramSize);

				buffer = std::move(other.buffer);
				_vramSize = other._vramSize;
				other._vramSize = 0;
			}
			return *this;
		}

		ConstantBuffer(const ConstantBuffer&) = delete;
		ConstantBuffer& operator=(const ConstantBuffer&) = delete;

		ConstantBuffer(ID3D11Device* device)
		{
			auto desc = D3D11_BUFFER_DESC{};
			desc.ByteWidth = sizeof(CBuff);
			desc.Usage = D3D11_USAGE_DYNAMIC;
			desc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
			desc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
			Utils::throwIfFailed(device->CreateBuffer(&desc, nullptr, buffer.GetAddressOf()));
			buffer->SetPrivateData(WKPDID_D3DDebugObjectName, 32, typeid(CBuff).name());

			_vramSize = desc.ByteWidth;
			Graphics::VRAMTracker::Get().Add(Graphics::VRAMCategory::ConstantBuffer, _vramSize);
		}

		~ConstantBuffer()
		{
			if (_vramSize > 0)
				Graphics::VRAMTracker::Get().Remove(Graphics::VRAMCategory::ConstantBuffer, _vramSize);
		}

		ID3D11Buffer** get()
		{
			return buffer.GetAddressOf();
		}

		void UpdateData(CBuff& data, ID3D11DeviceContext* ctx)
		{
			auto mappedResource = D3D11_MAPPED_SUBRESOURCE{};
			auto res = ctx->Map(buffer.Get(), 0, D3D11_MAP_WRITE_DISCARD, 0, &mappedResource);
			if (SUCCEEDED(res))
			{
				void* dataPtr = (mappedResource.pData);
				memcpy(dataPtr, &data, sizeof(CBuff));
				ctx->Unmap(buffer.Get(), 0);
			}
			else
			{
				TENLog("Could not update constant buffer.", LogLevel::Error);
			}
		}
	};
}
