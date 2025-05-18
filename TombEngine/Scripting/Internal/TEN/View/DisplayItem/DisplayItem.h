#pragma once

namespace sol { class state; };

namespace TEN::Scripting::DisplayItem
{

    void Register(sol::state* lua, sol::table& parent);

}
