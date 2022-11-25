#pragma once
#include "Specific/Input/InputAction.h"

struct ItemInfo;

namespace TEN::Input
{
	constexpr int MAX_KEYBOARD_KEYS    = 256;
	constexpr int MAX_GAMEPAD_KEYS     = 16;
	constexpr int MAX_GAMEPAD_AXES     = 6;
	constexpr int MAX_GAMEPAD_POV_AXES = 4;

	constexpr int MAX_INPUT_SLOTS = MAX_KEYBOARD_KEYS + MAX_GAMEPAD_KEYS + MAX_GAMEPAD_POV_AXES + MAX_GAMEPAD_AXES * 2;

	enum InputKey
	{
		KEY_FORWARD,
		KEY_BACK,
		KEY_LEFT,
		KEY_RIGHT,
		KEY_CROUCH,
		KEY_SPRINT,
		KEY_WALK,
		KEY_JUMP,
		KEY_ACTION,
		KEY_DRAW,
		KEY_FLARE,
		KEY_LOOK,
		KEY_ROLL,
		KEY_OPTION,
		KEY_PAUSE,
		KEY_LSTEP,
		KEY_RSTEP,

		KEY_ACCELERATE,
		KEY_REVERSE,
		KEY_SPEED,
		KEY_SLOW,
		KEY_BRAKE,
		KEY_FIRE,

		KEY_SMALL_MEDIPACK,
		KEY_LARGE_MEDIPACK,
		KEY_PREVIOUS_WEAPON,
		KEY_NEXT_WEAPON,
		KEY_WEAPON_1,
		KEY_WEAPON_2,
		KEY_WEAPON_3,
		KEY_WEAPON_4,
		KEY_WEAPON_5,
		KEY_WEAPON_6,
		KEY_WEAPON_7,
		KEY_WEAPON_8,
		KEY_WEAPON_9,
		KEY_WEAPON_10,

		KEY_COUNT
	};

	enum InputActions : long
	{
		IN_NONE		  = 0,
		IN_FORWARD	  = (1 << KEY_FORWARD),
		IN_BACK		  = (1 << KEY_BACK),
		IN_LEFT		  = (1 << KEY_LEFT),
		IN_RIGHT	  = (1 << KEY_RIGHT),
		IN_CROUCH	  = (1 << KEY_CROUCH),
		IN_SPRINT	  = (1 << KEY_SPRINT),
		IN_WALK		  = (1 << KEY_WALK),
		IN_JUMP		  = (1 << KEY_JUMP),
		IN_ACTION	  = (1 << KEY_ACTION),
		IN_DRAW		  = (1 << KEY_DRAW),
		IN_FLARE	  = (1 << KEY_FLARE),
		IN_LOOK		  = (1 << KEY_LOOK),
		IN_ROLL		  = (1 << KEY_ROLL),
		IN_OPTION	  = (1 << KEY_OPTION),
		IN_PAUSE	  = (1 << KEY_PAUSE),
		IN_LSTEP	  = (1 << KEY_LSTEP),
		IN_RSTEP	  = (1 << KEY_RSTEP),

		/*IN_ACCELERATE = (1 << KEY_ACCELERATE),
		IN_REVERSE	  = (1 << KEY_REVERSE),
		IN_SPEED	  = (1 << KEY_SPEED),
		IN_SLOW		  = (1 << KEY_SLOW),
		IN_BRAKE	  = (1 << KEY_BRAKE),
		IN_FIRE		  = (1 << KEY_FIRE),

		IN_SMALL_MEDIPACK  = (1 << KEY_SMALL_MEDIPACK),
		IN_LARGE_MEDIPACK  = (1 << KEY_LARGE_MEDIPACK),
		IN_NEXT_WEAPON	   = (1 << KEY_NEXT_WEAPON),
		IN_PREVIOUS_WEAPON = (1 << KEY_PREVIOUS_WEAPON),
		IN_WEAPON_1		   = (1 << KEY_WEAPON_1),
		IN_WEAPON_2		   = (1 << KEY_WEAPON_2),
		IN_WEAPON_3		   = (1 << KEY_WEAPON_3),
		IN_WEAPON_4		   = (1 << KEY_WEAPON_4),
		IN_WEAPON_5		   = (1 << KEY_WEAPON_5),
		IN_WEAPON_6		   = (1 << KEY_WEAPON_6),
		IN_WEAPON_7		   = (1 << KEY_WEAPON_7),
		IN_WEAPON_8		   = (1 << KEY_WEAPON_8),
		IN_WEAPON_9		   = (1 << KEY_WEAPON_9),
		IN_WEAPON_10	   = (1 << KEY_WEAPON_10),*/

		// Additional input actions without direct key relation

		// TODO
		IN_SAVE		  = (1 << (17 + 0)),
		IN_LOAD		  = (1 << (17 + 1)),
		IN_SELECT	  = (1 << (17 + 2)),
		IN_DESELECT   = (1 << (17 + 3)),
		IN_LOOKSWITCH = (1 << (17 + 4))
	};
	
	// Temporary input constants for use with vehicles:

	// TODO: Not needed. Thought too far ahead.
	constexpr int VEHICLE_IN_UP			= IN_FORWARD;
	constexpr int VEHICLE_IN_DOWN		= IN_BACK;
	constexpr int VEHICLE_IN_LEFT		= IN_LEFT;
	constexpr int VEHICLE_IN_RIGHT		= IN_RIGHT;

	constexpr int VEHICLE_IN_ACCELERATE = IN_ACTION;
	constexpr int VEHICLE_IN_REVERSE	= IN_BACK;
	constexpr int VEHICLE_IN_SPEED		= IN_SPRINT;
	constexpr int VEHICLE_IN_SLOW		= IN_WALK;
	constexpr int VEHICLE_IN_BRAKE		= IN_JUMP;
	constexpr int VEHICLE_IN_FIRE		= IN_DRAW | IN_CROUCH;

	// TODO: Not needed since BRAKE is explicitly assosiated with dismounts anyway.
	constexpr int VEHICLE_IN_DISMOUNT	= IN_JUMP | IN_ROLL;

	enum InputAxis
	{
		MoveVertical,
		MoveHorizontal,
		CameraVertical,
		CameraHorizontal,
		Count
	};

	enum class RumbleMode
	{
		None,
		Left,
		Right,
		Both
	};

	struct RumbleData
	{
		RumbleMode Mode		 = RumbleMode::None;
		float	   Power	 = 0.0f;
		float	   LastPower = 0.0f;
		float	   FadeSpeed = 0.0f;
	};

	extern const char* g_KeyNames[];

	extern std::vector<InputAction> ActionMap;
	extern std::vector<bool>		KeyMap;
	extern std::vector<float>		AxisMap;

	// Legacy input bit fields.
	extern long DbInput; // Debounce: is input clicked?
	extern long TrInput; // Throttle: is input held?

	extern short KeyboardLayout[2][KEY_COUNT];

	void InitialiseInput(HWND handle);
	void DeinitialiseInput();
	void DefaultConflict();
	void UpdateInputActions(ItemInfo* item);
	void ClearAllActions();
	void Rumble(float power, float delayInSec = 0.3f, RumbleMode mode = RumbleMode::Both);
	void StopRumble();

	// TODO: Later, all these global action accessor functions should be tied to a specific controller/player.
	// Having them loose like this is very inelegant, but since this is only the first iteration, they will do for now. -- Sezz 2022.10.12
	void  ClearAction(ActionID actionID);
	bool  NoAction();
	bool  IsClicked(ActionID actionID);
	bool  IsHeld(ActionID actionID, float delayInSec = 0.0f);
	bool  IsPulsed(ActionID actionID, float delayInSec, float initialDelayInSec = 0.0f);
	bool  IsReleased(ActionID actionID, float maxDelayInSec = INFINITY);
	float GetActionValue(ActionID actionID);
	float GetActionTimeActive(ActionID actionID);
	float GetActionTimeInactive(ActionID actionID);

	bool IsDirectionActionHeld();
	bool IsWakeActionHeld();
	bool IsOpticActionHeld();
}
