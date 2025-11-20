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

        virtual void Initialize() = 0;
        virtual void CheckPrerequisites() = 0;
        virtual void InstallCrashHandler() = 0;
        virtual void ShowErrorMessage(const std::string& text, MessageBoxIcon icon = MessageBoxIcon::Error) = 0;
        virtual void Tick() = 0;
        virtual void Shutdown() = 0;
        virtual std::vector<unsigned short> GetProductOrFileVersion(bool productVersion) = 0;
        virtual bool Is64Bit() = 0;
        virtual void SetSDL3Window(SDL_Window* window) = 0;
        virtual SDL_Window* GetSDL3Window() = 0;
        virtual void HideConsole() = 0;
    };


    std::unique_ptr<ISubsystem> CreatePlatformSubsystem();
}