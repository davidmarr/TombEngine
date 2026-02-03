#pragma once

#include <string>

namespace TEN::Renderer::Graphics
{
	struct AdapterInfo
	{
		std::string Name = {};
		unsigned int VendorId = 0;
		unsigned int DeviceId = 0;
		unsigned int SubSysId = 0;
		unsigned int Revision = 0;
		size_t DedicatedVideoMemory = 0;
		size_t DedicatedSystemMemory = 0;
		size_t SharedSystemMemory = 0;
	};
}
