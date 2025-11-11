#pragma once

#include "Renderer/RendererEnums.h"
#include "Renderer/RendererUtils.h"
#include <string>
#include <map>

using namespace TEN::Renderer;
using namespace TEN::Renderer::Utils;

namespace TEN::Renderer::Graphics
{
    struct ShaderCompileRequest
    {
        std::string SourceDirectory;
        std::string BinaryDirectory;
        std::string FileName;
        std::string EntryPoint;
        ShaderType Type;
        std::map<std::string, std::string> Macros;
        bool ForceRecompile = false;
        unsigned int CompileIndex = 0;
    };

	class IShader
	{
	};
}
