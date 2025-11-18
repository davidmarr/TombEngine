#include "framework.h"
#include <filesystem>
#include <codecvt>
#include "Renderer/Renderer.h"
#include "Specific/trutils.h"
#include "Specific/engine_main.h"

namespace TEN::Renderer 
{
	void Renderer::ChangeScreenResolution(int width, int height, bool windowed) 
	{
		_graphicsDevice->UnbindAllRenderTargets();
		_graphicsDevice->Flush();
		_graphicsDevice->ClearState();
		_graphicsDevice->ResizeSwapChain(width, height);

		_isWindowed = windowed;

		InitializeScreen(width, height, true);
	}

	std::string Renderer::GetDefaultAdapterName()
	{
		return _graphicsDevice->GetDefaultAdapterName();
	}

	std::unique_ptr<ITexture2D> Renderer::SetTextureOrDefault(std::wstring path)
	{
		std::unique_ptr<ITexture2D> texture;

		if (std::filesystem::is_regular_file(path))
		{
			texture = _graphicsDevice->CreateTexture2D(TEN::Utils::ToString(path));
		}
		else if (!path.empty()) // Loading default texture without path may be intentional.
		{
			texture = _graphicsDevice->CreateTexture2D();
			std::wstring_convert<std::codecvt_utf8<wchar_t>, wchar_t> converter;
			TENLog("Texture file not found: " + converter.to_bytes(path), LogLevel::Warning);
		}
		else
		{
			texture = _graphicsDevice->CreateTexture2D();
		}

		return texture;
	}
}
