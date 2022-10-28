#pragma once
#include "Objects/Interactive/InteractiveObject.h"
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

class LaraObject : public NamedBase<LaraObject, short>, InteractiveObject
{
public:
	using IdentifierType = short;

	LaraObject(short num, bool alreadyInitialised = true);
	~LaraObject();
	LaraObject& operator=(LaraObject const& other) = delete;
	LaraObject(LaraObject const& other) = delete;
	LaraObject(LaraObject&& other) noexcept;

	static void Register(sol::table& parent);

	void SetPoison(unsigned short $potency);
	void RemovePoison();

private:
	ItemInfo* m_item;
	short m_num;
	bool m_initialised;

	bool MeshExists(int number) const;
};
