#pragma once

#include <atomic>
#include <d3d11.h>
#include <string>

namespace TEN::Renderer::Graphics
{
	enum class VRAMCategory
	{
		Texture,
		RenderTarget,
		ConstantBuffer,
		VertexBuffer,
		IndexBuffer,

		Count
	};

	class VRAMTracker
	{
	public:
		static VRAMTracker& Get()
		{
			static VRAMTracker instance;
			return instance;
		}

		void Add(VRAMCategory category, size_t bytes)
		{
			_categories[static_cast<int>(category)] += bytes;
			_total += bytes;
		}

		void Remove(VRAMCategory category, size_t bytes)
		{
			_categories[static_cast<int>(category)] -= bytes;
			_total -= bytes;
		}

		size_t GetTotal() const
		{
			return _total.load();
		}

		size_t GetCategory(VRAMCategory category) const
		{
			return _categories[static_cast<int>(category)].load();
		}

		std::string GetSummary() const
		{
			auto toMB = [](size_t bytes) { return static_cast<float>(bytes) / (1024.0f * 1024.0f); };

			return "VRAM usage: " +
				std::to_string(toMB(GetTotal())) + " MB total | " +
				"Textures: " + std::to_string(toMB(GetCategory(VRAMCategory::Texture))) + " MB | " +
				"RenderTargets: " + std::to_string(toMB(GetCategory(VRAMCategory::RenderTarget))) + " MB | " +
				"CB: " + std::to_string(toMB(GetCategory(VRAMCategory::ConstantBuffer))) + " MB | " +
				"VB: " + std::to_string(toMB(GetCategory(VRAMCategory::VertexBuffer))) + " MB | " +
				"IB: " + std::to_string(toMB(GetCategory(VRAMCategory::IndexBuffer))) + " MB";
		}

		static size_t GetDXGIFormatBytesPerPixel(DXGI_FORMAT format)
		{
			switch (format)
			{
			case DXGI_FORMAT_R32G32B32A32_FLOAT:
			case DXGI_FORMAT_R32G32B32A32_UINT:
			case DXGI_FORMAT_R32G32B32A32_SINT:
			case DXGI_FORMAT_R32G32B32A32_TYPELESS:
				return 16;

			case DXGI_FORMAT_R32G32B32_FLOAT:
			case DXGI_FORMAT_R32G32B32_UINT:
			case DXGI_FORMAT_R32G32B32_SINT:
			case DXGI_FORMAT_R32G32B32_TYPELESS:
				return 12;

			case DXGI_FORMAT_R16G16B16A16_FLOAT:
			case DXGI_FORMAT_R16G16B16A16_UNORM:
			case DXGI_FORMAT_R16G16B16A16_UINT:
			case DXGI_FORMAT_R16G16B16A16_SNORM:
			case DXGI_FORMAT_R16G16B16A16_SINT:
			case DXGI_FORMAT_R16G16B16A16_TYPELESS:
			case DXGI_FORMAT_R32G32_FLOAT:
			case DXGI_FORMAT_R32G32_UINT:
			case DXGI_FORMAT_R32G32_SINT:
			case DXGI_FORMAT_R32G32_TYPELESS:
				return 8;

			case DXGI_FORMAT_R8G8B8A8_UNORM:
			case DXGI_FORMAT_R8G8B8A8_UNORM_SRGB:
			case DXGI_FORMAT_R8G8B8A8_UINT:
			case DXGI_FORMAT_R8G8B8A8_SNORM:
			case DXGI_FORMAT_R8G8B8A8_SINT:
			case DXGI_FORMAT_R8G8B8A8_TYPELESS:
			case DXGI_FORMAT_B8G8R8A8_UNORM:
			case DXGI_FORMAT_B8G8R8A8_UNORM_SRGB:
			case DXGI_FORMAT_B8G8R8A8_TYPELESS:
			case DXGI_FORMAT_R10G10B10A2_UNORM:
			case DXGI_FORMAT_R10G10B10A2_UINT:
			case DXGI_FORMAT_R10G10B10A2_TYPELESS:
			case DXGI_FORMAT_R11G11B10_FLOAT:
			case DXGI_FORMAT_R16G16_FLOAT:
			case DXGI_FORMAT_R16G16_UNORM:
			case DXGI_FORMAT_R16G16_UINT:
			case DXGI_FORMAT_R16G16_SNORM:
			case DXGI_FORMAT_R16G16_SINT:
			case DXGI_FORMAT_R16G16_TYPELESS:
			case DXGI_FORMAT_R32_FLOAT:
			case DXGI_FORMAT_R32_UINT:
			case DXGI_FORMAT_R32_SINT:
			case DXGI_FORMAT_R32_TYPELESS:
			case DXGI_FORMAT_D32_FLOAT:
			case DXGI_FORMAT_D24_UNORM_S8_UINT:
			case DXGI_FORMAT_R24G8_TYPELESS:
			case DXGI_FORMAT_R24_UNORM_X8_TYPELESS:
				return 4;

			case DXGI_FORMAT_R8G8_UNORM:
			case DXGI_FORMAT_R8G8_UINT:
			case DXGI_FORMAT_R8G8_SNORM:
			case DXGI_FORMAT_R8G8_SINT:
			case DXGI_FORMAT_R8G8_TYPELESS:
			case DXGI_FORMAT_R16_FLOAT:
			case DXGI_FORMAT_R16_UNORM:
			case DXGI_FORMAT_R16_UINT:
			case DXGI_FORMAT_R16_SNORM:
			case DXGI_FORMAT_R16_SINT:
			case DXGI_FORMAT_R16_TYPELESS:
			case DXGI_FORMAT_D16_UNORM:
				return 2;

			case DXGI_FORMAT_R8_UNORM:
			case DXGI_FORMAT_R8_UINT:
			case DXGI_FORMAT_R8_SNORM:
			case DXGI_FORMAT_R8_SINT:
			case DXGI_FORMAT_R8_TYPELESS:
			case DXGI_FORMAT_A8_UNORM:
				return 1;

			// Block-compressed formats: return 0, use ComputeBlockCompressedSize() instead.
			case DXGI_FORMAT_BC1_UNORM:
			case DXGI_FORMAT_BC1_UNORM_SRGB:
			case DXGI_FORMAT_BC1_TYPELESS:
			case DXGI_FORMAT_BC2_UNORM:
			case DXGI_FORMAT_BC2_UNORM_SRGB:
			case DXGI_FORMAT_BC2_TYPELESS:
			case DXGI_FORMAT_BC3_UNORM:
			case DXGI_FORMAT_BC3_UNORM_SRGB:
			case DXGI_FORMAT_BC3_TYPELESS:
			case DXGI_FORMAT_BC4_UNORM:
			case DXGI_FORMAT_BC4_SNORM:
			case DXGI_FORMAT_BC4_TYPELESS:
			case DXGI_FORMAT_BC5_UNORM:
			case DXGI_FORMAT_BC5_SNORM:
			case DXGI_FORMAT_BC5_TYPELESS:
			case DXGI_FORMAT_BC6H_UF16:
			case DXGI_FORMAT_BC6H_SF16:
			case DXGI_FORMAT_BC6H_TYPELESS:
			case DXGI_FORMAT_BC7_UNORM:
			case DXGI_FORMAT_BC7_UNORM_SRGB:
			case DXGI_FORMAT_BC7_TYPELESS:
				return 0;

			default:
				return 4;
			}
		}

		static size_t ComputeTexture2DSize(const D3D11_TEXTURE2D_DESC& desc)
		{
			size_t totalSize = 0;
			auto bpp = GetDXGIFormatBytesPerPixel(desc.Format);

			unsigned int mipLevels = desc.MipLevels;
			if (mipLevels == 0)
			{
				// MipLevels = 0 means full mip chain down to 1x1.
				unsigned int maxDim = std::max(desc.Width, desc.Height);
				mipLevels = 1;
				while (maxDim > 1)
				{
					maxDim >>= 1;
					mipLevels++;
				}
			}

			for (unsigned int mip = 0; mip < mipLevels; mip++)
			{
				auto mipWidth  = std::max(1u, desc.Width >> mip);
				auto mipHeight = std::max(1u, desc.Height >> mip);

				if (bpp > 0)
				{
					totalSize += static_cast<size_t>(mipWidth) * mipHeight * bpp;
				}
				else
				{
					// Block-compressed: 4x4 blocks.
					auto blockWidth  = std::max(1u, (mipWidth + 3) / 4);
					auto blockHeight = std::max(1u, (mipHeight + 3) / 4);

					size_t blockSize = 8; // BC1, BC4
					switch (desc.Format)
					{
					case DXGI_FORMAT_BC2_UNORM:
					case DXGI_FORMAT_BC2_UNORM_SRGB:
					case DXGI_FORMAT_BC2_TYPELESS:
					case DXGI_FORMAT_BC3_UNORM:
					case DXGI_FORMAT_BC3_UNORM_SRGB:
					case DXGI_FORMAT_BC3_TYPELESS:
					case DXGI_FORMAT_BC5_UNORM:
					case DXGI_FORMAT_BC5_SNORM:
					case DXGI_FORMAT_BC5_TYPELESS:
					case DXGI_FORMAT_BC6H_UF16:
					case DXGI_FORMAT_BC6H_SF16:
					case DXGI_FORMAT_BC6H_TYPELESS:
					case DXGI_FORMAT_BC7_UNORM:
					case DXGI_FORMAT_BC7_UNORM_SRGB:
					case DXGI_FORMAT_BC7_TYPELESS:
						blockSize = 16;
						break;
					default:
						break;
					}

					totalSize += static_cast<size_t>(blockWidth) * blockHeight * blockSize;
				}
			}

			totalSize *= desc.ArraySize;
			return totalSize;
		}

	private:
		VRAMTracker() = default;

		std::atomic<size_t> _total = 0;
		std::atomic<size_t> _categories[static_cast<int>(VRAMCategory::Count)] = {};
	};
}
