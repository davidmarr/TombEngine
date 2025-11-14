#pragma once

#ifdef _WIN32

#pragma comment(linker,"/manifestdependency:\"" \
    "type='win32' " \
    "name='Microsoft.Windows.Common-Controls' " \
    "version='6.0.0.0' " \
    "processorArchitecture='*' "  \
    "publicKeyToken='6595b64144ccf1df' " \
    "language='*'\"")

#include <Windows.h>
#include <string>
#include "Specific/Platform/ISubsystem.h"
#include "Specific/trutils.h"

using namespace TEN::Utils;

namespace TEN::Platform
{
    /// <summary>
    /// Windows-specific implementation of the platform subsystem.
    /// Encapsulates all remaining Win32 calls (registry access, crash handler,
    /// message boxes, etc.) behind a clean interface.
    /// </summary>
    class WindowsSubsystem final : public ISubsystem
    {
    private:
        SDL_Window* _window;

    public:
        WindowsSubsystem();
        ~WindowsSubsystem() override;

        void Initialize() override;
        void CheckPrerequisites() override;
        void InstallCrashHandler() override;
        void ShowErrorMessage(const std::string& text, MessageBoxIcon icon = MessageBoxIcon::Error) override;
        void Tick() override;
        void Shutdown() override;
        std::vector<unsigned short> GetProductOrFileVersion(bool productVersion) override;
        bool Is64Bit() override;
        void SetSDL3Window(SDL_Window* window);
        SDL_Window* GetSDL3Window();

    private:
        HINSTANCE _hInstance = nullptr;

        /// <summary>
        /// Internal helper that checks for the Microsoft Visual C++ Redistributable
        /// in the registry and prompts the user to install it if needed.
        /// </summary>
        void CheckVcRedist();

        /// <summary>
        /// Internal helper that actually installs the unhandled exception filter.
        /// </summary>
        void InstallExceptionFilter();
    };
}

#endif // _WIN32
