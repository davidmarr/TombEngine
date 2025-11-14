#include "framework.h"
#include "Specific/engine_main.h"
#include <SDL3/SDL.h>
#include <process.h>
#include <iostream>
#include <codecvt>
#include <filesystem>

#include "Game/control/control.h"
#include "Game/savegame.h"
#include "Renderer/Renderer.h"
#include "resource.h"
#include "Sound/sound.h"
#include "Specific/level.h"
#include "Specific/configuration.h"
#include "Specific/Parallel.h"
#include "Specific/trutils.h"
#include "Scripting/Internal/LanguageScript.h"
#include "Scripting/Include/ScriptInterfaceState.h"
#include "Scripting/Include/ScriptInterfaceLevel.h"
#include "Video/Video.h"

using namespace TEN::Renderer;
using namespace TEN::Input;
using namespace TEN::Utils;
using namespace TEN::Video;

// SDL threads
SDL_Thread* GameThread = nullptr;
SDL_Thread* ConsoleThread = nullptr;
unsigned int ThreadSuspendCount = 0;

// Cooperative pause
SDL_Mutex* GamePauseMutex = nullptr;
SDL_Condition* GamePauseCond = nullptr;
bool       GamePaused = false;

bool ResetClock;
std::unique_ptr<ISubsystem> g_Platform;

bool ArgEquals(const char* incomingArg, const std::string& name)
{
	if (!incomingArg)
		return false;

	std::string arg(incomingArg);

	arg = TEN::Utils::ToLower(arg);
	std::string lowerName = TEN::Utils::ToLower(name);

	if (!arg.empty() && (arg[0] == '-' || arg[0] == '/'))
	{
		arg.erase(0, 1);
		if (!arg.empty() && arg[0] == '-') 
			arg.erase(0, 1);
	}

	return arg == lowerName;
}


Vector2i GetScreenResolution()
{
	Vector2i res{ 0, 0 };

	SDL_DisplayID display = SDL_GetPrimaryDisplay();
	if (!display)
		return res;

	const SDL_DisplayMode* mode = SDL_GetCurrentDisplayMode(display);
	if (!mode)
		return res;

	res.x = mode->w;
	res.y = mode->h;
	return res;
}

int GetCurrentScreenRefreshRate()
{
	SDL_DisplayID display = SDL_GetPrimaryDisplay();
	if (!display)
		return 0;

	const SDL_DisplayMode* mode = SDL_GetCurrentDisplayMode(display);
	if (!mode)
		return 0;

	if (mode->refresh_rate <= 0.0f)
		return 0;

	return static_cast<int>(mode->refresh_rate + 0.5f);
}

std::vector<Vector2i> GetAllSupportedScreenResolutions()
{
	std::vector<Vector2i> resList;

	SDL_DisplayID display = SDL_GetPrimaryDisplay();
	if (!display)
		return resList;

	int count = 0;
	SDL_DisplayMode** modes = SDL_GetFullscreenDisplayModes(display, &count);
	if (!modes || count <= 0)
		return resList;

	resList.reserve(count);

	for (int i = 0; i < count; ++i)
	{
		const SDL_DisplayMode* mode = modes[i];
		if (!mode)
			continue;

		Vector2i res{ mode->w, mode->h };

		bool add = true;
		for (const auto& m : resList)
		{
			if (m.x == res.x && m.y == res.y)
			{
				add = false;
				break;
			}
		}

		if (add)
			resList.push_back(res);
	}

	SDL_free(modes);

	std::sort(
		resList.begin(), resList.end(),
		[](const Vector2i& a, const Vector2i& b)
		{
			return (a.x == b.x) ? (a.y < b.y) : (a.x < b.x);
		});

	return resList;
}

// TODO: use xxd -i or bin2c for writing the level as C array instead of using
// Windows resource system that is not portable to other platforms
bool GenerateDummyLevel(const std::string& levelPath)
{
	// Try loading embedded resource "data.bin"
	HRSRC hResource = FindResource(NULL, MAKEINTRESOURCE(IDR_TITLELEVEL), "BIN");
	if (hResource == NULL)
	{
		TENLog("Embedded title level file not found.", LogLevel::Error);
		return false;
	}

	// Load resource into memory.
	HGLOBAL hGlobal = LoadResource(NULL, hResource);
	if (hGlobal == NULL)
	{
		TENLog("Failed to load embedded title level file.", LogLevel::Error);
		return false;
	}

	// Lock resource to get data pointer.
	void* pData = LockResource(hGlobal);
	DWORD dwSize = SizeofResource(NULL, hResource);

	// Write resource data to file.
	try
	{
		auto dir = std::filesystem::path(levelPath).parent_path();
		if (!dir.empty())
			std::filesystem::create_directories(dir);

		auto outFile = std::ofstream(levelPath, std::ios::binary);
		if (!outFile)
			throw std::ios_base::failure("Failed to create title level file.");

		outFile.write(reinterpret_cast<const char*>(pData), dwSize);
		if (!outFile)
			throw std::ios_base::failure("Failed to write to title level file.");

		outFile.close();
	}
	catch (const std::exception& ex)
	{
		TENLog("Error while generating title level file: " + std::string(ex.what()), LogLevel::Error);
		return false;
	}

	return true;
}

int SDLCALL ConsoleInput(void*)
{
	auto input = std::string();
	while (!ThreadEnded)
	{
		if (!std::getline(std::cin, input))
			break;

		if (std::regex_match(input, std::regex("^\\s*$")))
			continue;

		if (g_GameScript == nullptr)
		{
			TENLog("Scripting engine not initialized.", LogLevel::Error);
			continue;
		}
		else
		{
			g_GameScript->AddConsoleInput(input);
		}
	}

	return 0;
}

static void HandleWindowFocusGained(SDL_Window* window)
{
	SetInputLockState(false);

	if (!g_Configuration.EnableWindowedMode)
	{
		g_Renderer.ToggleFullScreen(true);
	}

	if (ThreadSuspendCount > 0)
	{
		TENLog("Resuming game thread", LogLevel::Info);

		if (!g_VideoPlayer.Resume())
			ResumeAllSounds(SoundPauseMode::Global);

		ResumeGameThread();
	}
}

static void HandleWindowFocusLost(SDL_Window* window)
{
	SetInputLockState(true);

	if (!g_Configuration.EnableWindowedMode)
		SDL_MinimizeWindow(window);

	bool isMinimized =
		(SDL_GetWindowFlags(window) & SDL_WINDOW_MINIMIZED) != 0;

	if ((!DebugMode || isMinimized) && ThreadSuspendCount == 0)
	{
		TENLog("Suspending game thread", LogLevel::Info);

		if (!g_VideoPlayer.Pause())
			PauseAllSounds(SoundPauseMode::Global);

		PauseGameThread();
	}
}

void PauseGameThread()
{
	SDL_LockMutex(GamePauseMutex);

	ThreadSuspendCount++;
	GamePaused = true;

	SDL_UnlockMutex(GamePauseMutex);
}

void ResumeGameThread()
{
	SDL_LockMutex(GamePauseMutex);

	if (ThreadSuspendCount > 0)
		ThreadSuspendCount--;

	if (ThreadSuspendCount == 0)
	{
		GamePaused = false;
		SDL_BroadcastCondition(GamePauseCond); // sveglia il game thread
	}

	SDL_UnlockMutex(GamePauseMutex);
}

void WaitIfGamePaused()
{
	SDL_LockMutex(GamePauseMutex);
	while (GamePaused && !ThreadEnded && DoTheGame)
	{
		SDL_WaitCondition(GamePauseCond, GamePauseMutex);
	}
	SDL_UnlockMutex(GamePauseMutex);
}

int main(int argc, char* argv[])
{
	g_Platform = CreatePlatformSubsystem();
	g_Platform->Initialize();
	g_Platform->CheckPrerequisites();
	
	// Initialize SDL3
	if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_EVENTS))
	{
		// handle error
		return 1;
	}

	// Process command line arguments.
	bool setup = false;
	std::string levelFile = {};
	std::string gameDir{};

	// Parse command line arguments.
	for (int i = 1; i < argc; ++i)
	{
		std::string arg = argv[i];

		if (ArgEquals(arg.c_str(), "setup"))
		{
			setup = true;
		}
		else if (ArgEquals(arg.c_str(), "debug"))
		{
			DebugMode = true;
		}
		else if (ArgEquals(arg.c_str(), "level") && i + 1 < argc)
		{
			levelFile = argv[++i]; // consumi l’argomento successivo
		}
		else if (ArgEquals(arg.c_str(), "hash") && i + 1 < argc)
		{
			SystemNameHash = std::stoul(argv[++i]);
		}
		else if (ArgEquals(arg.c_str(), "gamedir") && i + 1 < argc)
		{
			gameDir = argv[++i];
		}
	}

	// Construct asset directory.
	gameDir = ConstructAssetDirectory(gameDir);

	// Hide console window if mode isn't debug.
#if !_DEBUG
	if (!DebugMode)
	{
		g_Platform->HideConsole();
	}
	else
#endif
	{
		ConsoleThread = SDL_CreateThread(ConsoleInput, "ConsoleInput", nullptr);
		if (ConsoleThread)
			SDL_DetachThread(ConsoleThread);
	}

	// Initialize logging.
	InitTENLog(gameDir);
	g_Platform->InstallCrashHandler();

	auto windowName = std::string("Starting TombEngine");

	// Indicate version.
	auto ver = g_Platform->GetProductOrFileVersion(false);

	if (ver.size() == 4)
	{
		windowName = windowName + " version " +
					 std::to_string(ver[0]) + "." +
					 std::to_string(ver[1]) + "." +
					 std::to_string(ver[2]) + "." +
					 std::to_string(ver[3]);
	}

	if (g_Platform->Is64Bit())
		windowName = windowName + " (64-bit)";
	else
		windowName = windowName + " (32-bit)";

	TENLog(windowName, LogLevel::Info);

	// Initialize savegame and scripting systems.
	SaveGame::Init(gameDir);
	ScriptInterfaceState::Init(gameDir);

	// Initialize scripting.
	try 
	{
		g_GameFlow = ScriptInterfaceState::CreateFlow();
		g_GameScriptEntities = ScriptInterfaceState::CreateObjectsHandler();
		g_GameStringsHandler = ScriptInterfaceState::CreateStringsHandler();

		// This must be loaded last as it adds metafunctions to the global
		// table so that every global variable added henceforth gets put
		// into a special hidden table which we can clean up.
		// By doing this last, we ensure that all built-in usertypes
		// are added to a hierarchy in the REAL global table, not the fake
		// hidden one.
		g_GameScript = ScriptInterfaceState::CreateGame();

		//todo Major hack. This should not be needed to leak outside of
		//LogicHandler internals. In a future version stuff from FlowHandler
		//should be moved to LogicHandler or vice versa to make this stuff
		//less fragile (squidshire, 16/09/22)
		g_GameScript->ShortenTENCalls();
		g_GameFlow->SetGameDir(gameDir);
		g_GameFlow->LoadFlowScript();
	}
	catch (TENScriptException const& e)
	{
		auto errorMessage = std::string{ "A Lua error occurred while setting up scripts; " } + __func__ + ": " + e.what();
		TENLog(errorMessage, LogLevel::Error, LogConfig::All);
		g_Platform->ShowErrorMessage(errorMessage, MessageBoxIcon::Error);
		ShutdownTENLog();
		g_Platform->Shutdown();
		return 0;
	}

	// Initialize main window.
	int width = g_Configuration.ScreenWidth;
	int height = g_Configuration.ScreenHeight;

	unsigned int windowFlags = SDL_WINDOW_RESIZABLE;
	if (!g_Configuration.EnableWindowedMode)
		windowFlags |= SDL_WINDOW_FULLSCREEN;

	SDL_Window* sdlWindow = SDL_CreateWindow(
		g_GameFlow->GetString(STRING_WINDOW_TITLE),
		width,
		height,
		windowFlags);

	if (!sdlWindow)
	{
		auto errorMessage = std::string("Failed to create SDL window: ") + SDL_GetError();
		TENLog(errorMessage, LogLevel::Error);
		g_Platform->ShowErrorMessage(errorMessage, MessageBoxIcon::Error);
		SDL_Quit();
		g_Platform->Shutdown();
		return 0;
	}

	g_Platform->SetSDL3Window(sdlWindow);

	// Create renderer and enumerate adapters and video modes.
	g_Renderer.Create();

	// Initialize key bindings.
	g_Bindings.Initialize();

	// Load configuration and optionally show setup dialog.
	InitDefaultConfiguration();
	if (setup || !LoadConfiguration())
	{
		if (!SetupDialog())
		{
			EngineClose();
			return 0;
		}

		LoadConfiguration();
	}

	try
	{
		// Initialize audio (should be called prior to initializing renderer, because video handler needs it).
		Sound_Init(gameDir);

		// Initialize renderer.
		g_Renderer.Initialize(gameDir, g_Configuration.ScreenWidth, g_Configuration.ScreenHeight, g_Configuration.EnableWindowedMode);

		// Initialize input.
		InitializeInput();

		// Load level if specified in command line.
		CurrentLevel = g_GameFlow->GetLevelNumber(levelFile);

		SDL_ShowWindow(sdlWindow);
		SDL_RaiseWindow(sdlWindow);
	}
	catch (std::exception& ex)
	{
		auto errorMessage = "Error during game initialization: " + std::string(ex.what());
		TENLog(errorMessage, LogLevel::Error);
		g_Platform->ShowErrorMessage(errorMessage, MessageBoxIcon::Error);
		SDL_Quit();
		g_Platform->Shutdown();
		exit(EXIT_FAILURE);
	}

	DoTheGame = true;

	g_Parallel.Initialize();
	ThreadEnded = false;
	ThreadSuspendCount = 0;

	GamePauseMutex = SDL_CreateMutex();
	GamePauseCond = SDL_CreateCondition();

	GameThread = SDL_CreateThread(GameMain, "GameMain", nullptr);
	if (!GameThread)
	{
		TENLog(std::string("Failed to create game thread: ") + SDL_GetError(), LogLevel::Error);
		DoTheGame = false;
	}

	// The game window likes to steal input anyway, so let's put it at the
	// foreground so the user at least expects it.
	SDL_Window* focused = SDL_GetKeyboardFocus();
	if (focused != sdlWindow)
	{
		SDL_RaiseWindow(sdlWindow);
	}

	bool running = true;
	while (running && !ThreadEnded && DoTheGame)
	{
		SDL_Event ev;
		while (SDL_PollEvent(&ev))
		{
			switch (ev.type)
			{
			case SDL_EVENT_QUIT:
			case SDL_EVENT_WINDOW_CLOSE_REQUESTED:
				DoTheGame = false;
				running = false;
				break;

			case SDL_EVENT_WINDOW_FOCUS_GAINED:
				HandleWindowFocusGained(sdlWindow);
				break;

			case SDL_EVENT_WINDOW_FOCUS_LOST:
				HandleWindowFocusLost(sdlWindow);
				break;

			default:
				break;
			}
		}

		// Avoid looping at 100% where there're no events
		SDL_Delay(1);
	}

	ThreadEnded = true;

	while (DoTheGame)
		SDL_Delay(1);

	TENLog("Cleaning up and exiting...", LogLevel::Info);

	SDL_DestroyWindow(sdlWindow);
	SDL_Quit();
	EngineClose();

	exit(EXIT_SUCCESS);
}

void EngineClose()
{
	if (GameThread)
	{
		int status = 0;
		SDL_LockMutex(GamePauseMutex);
		GamePaused = false;
		SDL_BroadcastCondition(GamePauseCond);
		SDL_UnlockMutex(GamePauseMutex);

		SDL_WaitThread(GameThread, &status);
		GameThread = nullptr;
	}

	if (GamePauseCond)
	{
		SDL_DestroyCondition(GamePauseCond);
		GamePauseCond = nullptr;
	}
	if (GamePauseMutex)
	{
		SDL_DestroyMutex(GamePauseMutex);
		GamePauseMutex = nullptr;
	}

	ShutdownTENLog();
}
