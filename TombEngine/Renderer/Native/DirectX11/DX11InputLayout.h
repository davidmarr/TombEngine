#pragma once

#include <d3d11.h>
#include "Renderer/RendererUtils.h"
#include "Renderer/Graphics/IInputLayout.h"
#include "Renderer/Structures/RendererInputLayout.h"
#include <wrl/client.h>
#include <vector>

namespace TEN::Renderer::Native::DirectX11
{
	using namespace TEN::Renderer::Utils;
	using namespace TEN::Renderer::Structures;
	using namespace TEN::Renderer::Graphics;

	using Microsoft::WRL::ComPtr;

	class DX11InputLayout final : public IInputLayout
	{
	public:
		ComPtr<ID3D11InputLayout> InputLayout;

		DX11InputLayout()
		{
		};

		DX11InputLayout(ID3D11Device* device, std::vector<RendererInputLayoutField> fields)
		{
			std::vector<D3D11_INPUT_ELEMENT_DESC> elements;

			for (auto field : fields)
			{
				D3D11_INPUT_ELEMENT_DESC element;

				element.SemanticIndex = field.Slot;
				element.SemanticName = field.Semantic;
				element.AlignedByteOffset = elements.size() == 0 ? 0 : D3D11_APPEND_ALIGNED_ELEMENT;
				element.InputSlot = 0;
				element.InputSlotClass = D3D11_INPUT_PER_VERTEX_DATA;
				element.InstanceDataStepRate = 0;

				switch (field.Format)
				{
				case VertexInputFormat::RGBA8_Unorm:
					element.Format = DXGI_FORMAT_R8G8B8A8_UINT;
					break;
					
				case VertexInputFormat::R8G8_Unorm:
					element.Format = DXGI_FORMAT_R8G8_UINT;
					break;

				case VertexInputFormat::RGB32_Float:
					element.Format = DXGI_FORMAT_R32G32B32_FLOAT;
					break;

				case VertexInputFormat::RGBA32_Float:
					element.Format = DXGI_FORMAT_R32G32B32A32_FLOAT;
					break;

				case VertexInputFormat::R32_Float:
					element.Format = DXGI_FORMAT_R32_FLOAT;
					break;

				default:
					continue;

				}

				elements.push_back(element);
			}

			//const auto& roomShader = _shaders.Get(Shader::Rooms);
			//Utils::throwIfFailed(device->CreateInputLayout(elements.data(), elements.size(), roomShader.Vertex.Blob->GetBufferPointer(), roomShader.Vertex.Blob->GetBufferSize(), &InputLayout));
		}
	};
}
