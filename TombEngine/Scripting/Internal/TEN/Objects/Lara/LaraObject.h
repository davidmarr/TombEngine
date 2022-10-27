#pragma once
#include "Objects/NamedBase.h"
#include "Lara/lara_struct.h"
#include "Math/Math.h"

struct LaraInfo;

namespace sol
{
	class state;
}
struct ItemInfo;
enum GAME_OBJECT_ID : short;

class Test : public NamedBase<Test, short>
{
public:
	using IdentifierType = short;

	Test(short num, bool alreadyInitialised = true);
	~Test();
	Test& operator=(Test const& other) = delete;
	Test(Test const& other) = delete;
	Test(Test&& other) noexcept;

	static void Register(sol::table& parent);

	void SetPoison(unsigned short $potency);
	void RemovePoison();

private:
	ItemInfo* m_item;
	short m_num;
	bool m_initialised;

	bool MeshExists(int number) const;
};
