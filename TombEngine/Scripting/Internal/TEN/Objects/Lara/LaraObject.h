#pragma once
#include "Objects/NamedBase.h"
#include "Lara/lara_struct.h"
#include "Math/Math.h"

struct LaraInfo;

namespace sol
{
	class state;
}

class Test : public NamedBase<int, bool>
{
public:
	using IdentifierType = std::reference_wrapper<LaraInfo>;
	Test(LaraInfo& ref);
	~Test() = default;

	Test& operator=(Test const& other) = delete;
	Test(Test const& other) = delete;

	static void Register(sol::table&);

	void SetPoison(unsigned short $potency);
	void RemovePoison();

private:
	LaraInfo& m_lara;
};
