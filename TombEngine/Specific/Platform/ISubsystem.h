#pragma once
#include "framework.h"
#include <memory>
#include <string>

namespace TEN::Platform
{
    enum class MessageBoxIcon
    {
        Info,
        Warning,
        Error
    };

    class ISubsystem
    {
    public:
        virtual ~ISubsystem() = default;

        // Called very early (soon after startup).
        // Use it to check OS-level prerequisites, like VC++ Redistributable.
        virtual void CheckPrerequisites() = 0;

        // Installs the platform-specific crash handler.
        // On Windows this can install an unhandled exception filter, symbol loading, etc.
        virtual void InstallCrashHandler() = 0;

        // Shows an error or info dialog to the user.
        // Implementation depends on the platform (MessageBox on Windows, something else elsewhere).
        virtual void ShowErrorMessage(const std::string& text,
            MessageBoxIcon icon = MessageBoxIcon::Error) = 0;

        // Optional per-frame/platform tick.
        // Useful if the platform needs periodic polling (e.g., console input, background tasks).
        virtual void Tick() = 0;

        // Called before shutdown.
        // Use this to clean up platform-specific resources if needed.
        virtual void Shutdown() = 0;
    };


    std::unique_ptr<ISubsystem> CreatePlatformSubsystem();
}