#pragma once
#include <d3d11.h>
#include "Renderer/RendererUtils.h"
#include "Renderer/Graphics/Vertices/Vertex.h"
#include "Renderer/Graphics/IVertexBuffer.h"
#include <wrl/client.h>
#include <vector>
#include "Specific/fast_vector.h"

using namespace TEN::Renderer::Graphics::Vertices;

namespace TEN::Renderer::Native::DirectX11
{
	using namespace TEN::Renderer::Utils;
	using namespace TEN::Renderer::Graphics;

	using Microsoft::WRL::ComPtr;
	
	class DX11VertexBuffer final : public IVertexBuffer
	{
	private:
		int _numVertices;

	public:
		ComPtr<ID3D11Buffer> Buffer;
		int Stride;

		DX11VertexBuffer() 
		{
		};
		
		template <typename CVertex>
		DX11VertexBuffer(ID3D11Device* device, int numVertices, std::vector<CVertex> vertices)
		{
			Stride = sizeof(CVertex);

			D3D11_BUFFER_DESC desc = {};

			desc.Usage = D3D11_USAGE_DYNAMIC;
			desc.ByteWidth = Stride * (numVertices > 0 ? numVertices : 1);
			desc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
			desc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;

			if (vertices.size() != 0)
			{
				D3D11_SUBRESOURCE_DATA initData = {};
				initData.pSysMem = vertices.data();
				initData.SysMemPitch = Stride * numVertices;

				throwIfFailed(device->CreateBuffer(&desc, &initData, &Buffer));
			}
			else
			{
				throwIfFailed(device->CreateBuffer(&desc, nullptr, &Buffer));
			}

			_numVertices = numVertices;
		}

		template <typename CVertex>
		DX11VertexBuffer(ID3D11Device* device, int numVertices, fast_vector<CVertex> vertices)
		{
			Stride = sizeof(CVertex);

			D3D11_BUFFER_DESC desc = {};

			desc.Usage = D3D11_USAGE_DYNAMIC;
			desc.ByteWidth = Stride * (numVertices > 0 ? numVertices : 1);
			desc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
			desc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;

			if (vertices.size() != 0)
			{
				D3D11_SUBRESOURCE_DATA initData = {};
				initData.pSysMem = vertices.data();
				initData.SysMemPitch = Stride * numVertices;

				throwIfFailed(device->CreateBuffer(&desc, &initData, &Buffer));
			}
			else
			{
				throwIfFailed(device->CreateBuffer(&desc, nullptr, &Buffer));
			}

			_numVertices = numVertices;
		}

		template <typename CVertex>
		DX11VertexBuffer(ID3D11Device* device, int numVertices, CVertex* vertices)
		{
			Stride = sizeof(CVertex);

			D3D11_BUFFER_DESC desc = {};

			desc.Usage = D3D11_USAGE_DYNAMIC;
			desc.ByteWidth = Stride * (numVertices > 0 ? numVertices : 1);
			desc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
			desc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;

			if (numVertices != 0)
			{
				D3D11_SUBRESOURCE_DATA initData = {};
				initData.pSysMem = vertices;
				initData.SysMemPitch = Stride * numVertices;

				throwIfFailed(device->CreateBuffer(&desc, &initData, &Buffer));
			}
			else
			{
				throwIfFailed(device->CreateBuffer(&desc, nullptr, &Buffer));
			}

			_numVertices = numVertices;
		}

		template <typename CVertex>
		bool Update(ID3D11DeviceContext* context, CVertex* data, int startVertex, int count)
		{
			D3D11_MAPPED_SUBRESOURCE mappedResource;
			HRESULT res = context->Map(Buffer.Get(), 0, D3D11_MAP_WRITE_DISCARD, 0, &mappedResource);

			if (SUCCEEDED(res))
			{
				void* dataPtr = (mappedResource.pData);
				memcpy(dataPtr, &data[startVertex], count * Stride);
				context->Unmap(Buffer.Get(), 0);
				return true;
			}
			else
			{
				TENLog("Could not update constant buffer! " + std::to_string(res), LogLevel::Error);
				return false;
			}
		}
	};
}
