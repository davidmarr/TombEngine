// WindowsSubsystem.h
#pragma once

#ifdef _WIN32

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
    public:
        WindowsSubsystem();
        ~WindowsSubsystem() override;

        /// <summary>
        /// Check OS-level prerequisites required by the engine.
        /// Currently: verify that the VC++ 2015–2022 Redistributable is installed.
        /// Shows a prompt to download it if it is missing.
        /// </summary>
        void CheckPrerequisites() override;

        /// <summary>
        /// Install a global unhandled exception filter.
        /// This allows us to catch crashes, log them and display an error message
        /// instead of just silently terminating.
        /// </summary>
        void InstallCrashHandler() override;

        /// <summary>
        /// Show a simple message box using the native Windows API.
        /// Used to report errors or important information to the user.
        /// </summary>
        void ShowErrorMessage(const std::string& text,
            MessageBoxIcon icon = MessageBoxIcon::Error) override;

        /// <summary>
        /// Optional per-frame platform tick.
        /// Currently not used on Windows, but can be used later for things like
        /// polling console input, OS signals, etc.
        /// </summary>
        void Tick() override;

        /// <summary>
        /// Perform any platform-specific shutdown work.
        /// Currently empty, but kept for symmetry and future expansion.
        /// </summary>
        void Shutdown() override;
        
        std::vector<unsigned short> GetProductOrFileVersion(bool productVersion) override;

        bool Is64Bit() override;

        void DisableDpiAwareness() override;

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
