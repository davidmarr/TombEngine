#include "framework.h"
#include "Specific/winmain.h"
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

WINAPP App;

// SDL threads
SDL_Thread* GameThread = nullptr;
SDL_Thread* ConsoleThread = nullptr;
unsigned int ThreadSuspendCount = 0;

// Cooperative pause
SDL_Mutex* GamePauseMutex = nullptr;
SDL_Condition* GamePauseCond = nullptr;
bool       GamePaused = false;

HACCEL hAccTable;
HWND WindowsHandle;
std::unique_ptr<ISubsystem> g_Platform;

// Indicates to hybrid graphics systems to prefer discrete part by default.
extern "C"
{
	__declspec(dllexport) DWORD NvOptimusEnablement = 0x00000001;
	__declspec(dllexport) int AmdPowerXpressRequestHighPerformance = 1;
}

bool ArgEquals(wchar_t* incomingArg, std::string name)
{
	auto lowerArg = TEN::Utils::ToLower(TEN::Utils::ToString(incomingArg));
	return (lowerArg == "-" + name) || (lowerArg == "/" + name);
}

Vector2i GetScreenResolution()
{
	RECT desktop;
	const HWND hDesktop = GetDesktopWindow();
	GetWindowRect(hDesktop, &desktop);
	Vector2i resolution;
	resolution.x = desktop.right;
	resolution.y = desktop.bottom;
	return resolution;
}

int GetCurrentScreenRefreshRate()
{
	DEVMODE devmode;
	memset(&devmode, 0, sizeof(devmode));
	devmode.dmSize = sizeof(devmode);
	
	if (EnumDisplaySettings(NULL, ENUM_CURRENT_SETTINGS, &devmode))
	{
		return devmode.dmDisplayFrequency;
	}
	else
	{
		return 0;
	}
}

std::vector<Vector2i> GetAllSupportedScreenResolutions()
{
	auto resList = std::vector<Vector2i>{};

	DEVMODE dm = { 0 };
	dm.dmSize = sizeof(dm);
	for (int iModeNum = 0; EnumDisplaySettings(NULL, iModeNum, &dm) != 0; iModeNum++)
	{
		bool add = true;
		for (auto m : resList)
		{
			if (m.x == dm.dmPelsWidth && m.y == dm.dmPelsHeight)
			{
				add = false;
				break;
			}
		}
		if (add)
		{
			auto res = Vector2i(dm.dmPelsWidth, dm.dmPelsHeight);
			resList.push_back(res);
		}
	}

	std::sort(
		resList.begin(), resList.end(),
		[](Vector2i& a, Vector2i& b)
		{
			return ((a.x == b.x) ? (a.y < b.y) : (a.x < b.x));
		});

	return resList;
}

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
	// Equivalent of the old WM_ACTIVATE "gain focus" branch
	SetInputLockState(false);

	if (!g_Configuration.EnableWindowedMode)
	{
		// In your old code this forced fullscreen on focus.
		// Now the fullscreen state is gestito da SDL, ma lasciamo la call
		// se il tuo renderer fa qualcosa di specifico.
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
	//LPWSTR* argv;
	//int argc;
	//argv = CommandLineToArgvW(GetCommandLineW(), &argc);
	std::string gameDir{};

	// Parse command line arguments.
	/*for (int i = 1; i < argc; i++)
	{
		if (ArgEquals(TEN::Utils::ToWString(argv[i]), "setup"))
		{
			setup = true;
		}
		else if (ArgEquals(argv[i], "debug"))
		{
			DebugMode = true;
		}
		else if (ArgEquals(argv[i], "level") && argc > (i + 1))
		{
			levelFile = TEN::Utils::ToString(argv[i + 1]);
		}
		else if (ArgEquals(argv[i], "hash") && argc > (i + 1))
		{
			SystemNameHash = std::stoul(std::wstring(argv[i + 1]));
		}
		else if (ArgEquals(argv[i], "gamedir") && argc > (i + 1))
		{
			gameDir = TEN::Utils::ToString(argv[i + 1]);
		}
	}
	LocalFree(argv);*/

	// Construct asset directory.
	gameDir = ConstructAssetDirectory(gameDir);

	// Hide console window if mode isn't debug.
#if !_DEBUG
	if (!DebugMode)
	{
		FreeConsole();
	}
	else
#endif
	{
		ConsoleThread = SDL_CreateThread(ConsoleInput, "ConsoleInput", nullptr);
		if (ConsoleThread)
			SDL_DetachThread(ConsoleThread);
	}

	// Clear application structure.
	memset(&App, 0, sizeof(WINAPP));
	
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

	// Disable DPI scaling on Windows 8.1+ systems.
	g_Platform->DisableDpiAwareness();

	// Set up main window.
	//INITCOMMONCONTROLSEX commCtrlInit;
	//commCtrlInit.dwSize = sizeof(INITCOMMONCONTROLSEX);
	//commCtrlInit.dwICC = ICC_USEREX_CLASSES | ICC_STANDARD_CLASSES;
	//InitCommonControlsEx(&commCtrlInit);

	// Initialize main window.

	int width = g_Configuration.ScreenWidth;
	int height = g_Configuration.ScreenHeight;

	Uint32 windowFlags = SDL_WINDOW_RESIZABLE;
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

	HWND hwnd = nullptr;
#if defined(SDL_PLATFORM_WIN32)
	SDL_PropertiesID props = SDL_GetWindowProperties(sdlWindow);
	hwnd = (HWND)SDL_GetPointerProperty(props, SDL_PROP_WINDOW_WIN32_HWND_POINTER, nullptr);
#endif

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
			WinClose();
			return 0;
		}

		LoadConfiguration();
	}

	try
	{
		// Unlike CoInitialize(), this line prevents event spamming if a .dll fails.
		g_Platform->ComInitialize();

		// Initialize audio (should be called prior to initializing renderer, because video handler needs it).
		Sound_Init(gameDir);

		SDL_PropertiesID props = SDL_GetWindowProperties(g_Platform->GetSDL3Window());
		HWND handle = (HWND)SDL_GetPointerProperty(props, SDL_PROP_WINDOW_WIN32_HWND_POINTER, nullptr);

		// Initialize renderer.
		g_Renderer.Initialize(gameDir, g_Configuration.ScreenWidth, g_Configuration.ScreenHeight, g_Configuration.EnableWindowedMode, handle);

		// Initialize input.
		InitializeInput();

		// Load level if specified in command line.
		CurrentLevel = g_GameFlow->GetLevelNumber(levelFile);

		App.bNoFocus = false;
		App.isInScene = false;

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
	//if (GetForegroundWindow() != WindowsHandle)
	//	SetForegroundWindow(WindowsHandle);

	//WinProcMsg();
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

		// Evita di girare al 100% quando non ci sono eventi
		SDL_Delay(1);
	}

	ThreadEnded = true;

	while (DoTheGame)
		SDL_Delay(1);

	TENLog("Cleaning up and exiting...", LogLevel::Info);

	// Cleanup SDL
	SDL_DestroyWindow(sdlWindow);
	SDL_Quit();

	WinClose();
	exit(EXIT_SUCCESS);
}

void WinClose()
{
	// Ferma il game thread
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

	// Distruggi sincronizzazione
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

	// Il thread della console è stato detachato, non c'è nulla da chiudere.
	// Se invece preferisci aspettarlo:
	// if (ConsoleThread) { int s; SDL_WaitThread(ConsoleThread, &s); }

	DestroyAcceleratorTable(hAccTable);
	ShutdownTENLog();
	g_Platform->ComUninitialize();
}
