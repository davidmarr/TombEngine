#include "framework.h"
#include "Specific/Platform/WindowsSubsystem.h"

#ifdef _WIN32

#include <DbgHelp.h>
#include <shellapi.h>
#include <sstream>
#include <iostream>
#include <commctrl.h>
#include "Specific/trutils.h"

extern "C"
{
    __declspec(dllexport) DWORD NvOptimusEnablement = 0x00000001;
    __declspec(dllexport) int AmdPowerXpressRequestHighPerformance = 1;
}

namespace TEN::Platform
{
    static LONG WINAPI HandleException(EXCEPTION_POINTERS* exceptionInfo)
    {
        DWORD code = exceptionInfo->ExceptionRecord->ExceptionCode;
        const char* codeName = "Unknown exception";

        // Translate common exception codes into human-readable text.
        switch (code)
        {
        case EXCEPTION_ACCESS_VIOLATION:         codeName = "Access violation";              break;
        case EXCEPTION_ARRAY_BOUNDS_EXCEEDED:    codeName = "Array out of bounds";           break;
        case EXCEPTION_BREAKPOINT:               codeName = "Breakpoint encountered";        break;
        case EXCEPTION_DATATYPE_MISALIGNMENT:    codeName = "Data type misalignment";        break;
        case EXCEPTION_FLT_DIVIDE_BY_ZERO:       codeName = "Floating-point division by zero"; break;
        case EXCEPTION_FLT_OVERFLOW:             codeName = "Floating-point overflow";       break;
        case EXCEPTION_ILLEGAL_INSTRUCTION:      codeName = "Illegal instruction";           break;
        case EXCEPTION_IN_PAGE_ERROR:            codeName = "Exception in page error";       break;
        case EXCEPTION_INT_DIVIDE_BY_ZERO:       codeName = "Integer division by zero";      break;
        case EXCEPTION_INT_OVERFLOW:             codeName = "Integer overflow";              break;
        case EXCEPTION_INVALID_DISPOSITION:      codeName = "Invalid disposition";           break;
        case EXCEPTION_NONCONTINUABLE_EXCEPTION: codeName = "Non-continuable exception";     break;
        case EXCEPTION_PRIV_INSTRUCTION:         codeName = "Privileged instruction";        break;
        case EXCEPTION_SINGLE_STEP:              codeName = "Single-step exception";         break;
        case EXCEPTION_STACK_OVERFLOW:           codeName = "Stack overflow";                break;
        default:
            break;
        }

        // Initialize symbol handler so we can resolve addresses to function names
        HANDLE process = GetCurrentProcess();
        SymInitialize(process, NULL, TRUE);

        DWORD64 address = (DWORD64)exceptionInfo->ExceptionRecord->ExceptionAddress;
        char symbolBuffer[sizeof(SYMBOL_INFO) + MAX_SYM_NAME];
        PSYMBOL_INFO symbol = reinterpret_cast<PSYMBOL_INFO>(symbolBuffer);
        symbol->SizeOfStruct = sizeof(SYMBOL_INFO);
        symbol->MaxNameLen = MAX_SYM_NAME;

        // Build a string describing where the crash happened.
        std::ostringstream oss;
        if (SymFromAddr(process, address, 0, symbol))
        {
            // If debug symbols are available, show function name + address.
            oss << "address " << symbol->Name << " (0x" << std::hex << address << ")";
        }
        else
        {
            // Fallback: only show raw address if we cannot resolve a symbol.
            oss << "address 0x" << std::hex << address;
        }

        std::string errorMessage = "Unhandled exception: ";
        errorMessage += codeName;
        errorMessage += " at ";
        errorMessage += oss.str();
        errorMessage += ".";

        // Log the error message using the engine's logging system.
        TENLog(errorMessage, LogLevel::Error);

        // Show a blocking message box so the user sees what happened.
        MessageBoxA(
            nullptr,
            errorMessage.c_str(),
            "TombEngine - Crash",
            MB_ICONERROR | MB_OK);

        // Instruct Windows to terminate the process after handling the exception.
        return EXCEPTION_EXECUTE_HANDLER;
    }

    WindowsSubsystem::WindowsSubsystem()
    {

    }

    WindowsSubsystem::~WindowsSubsystem()
    {
        // Nothing special to do here yet.
        // If you allocate any Windows-specific resources later,
        // this is the place to release them.
    }

    void WindowsSubsystem::Initialize()
    {
        _hInstance = GetModuleHandle(nullptr);

        INITCOMMONCONTROLSEX commCtrlInit;
        commCtrlInit.dwSize = sizeof(INITCOMMONCONTROLSEX);
        commCtrlInit.dwICC = ICC_USEREX_CLASSES | ICC_STANDARD_CLASSES;
        InitCommonControlsEx(&commCtrlInit);

        // Don't use SHCore library directly, as it's not available on pre-win 8.1 systems.

        typedef HRESULT(WINAPI* SetDpiAwarenessProc)(UINT);
        static constexpr unsigned int PROCESS_SYSTEM_DPI_AWARE = 1;

        auto lib = LoadLibrary("SHCore.dll");
        if (lib == NULL)
            return;

        auto setDpiAwareness = (SetDpiAwarenessProc)GetProcAddress(lib, "SetProcessDpiAwareness");
        if (setDpiAwareness == NULL)
            return;

        setDpiAwareness(PROCESS_SYSTEM_DPI_AWARE);
        FreeLibrary(lib);

        CoInitializeEx(NULL, COINIT_MULTITHREADED);
    }

    void WindowsSubsystem::CheckVcRedist()
    {
        // Registry path where the VC++ 2015–2022 runtime stores its version info.
        const char* redistKey =
#ifdef _WIN64
            R"(SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64)";
#else
            R"(SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86)";
#endif

        HKEY hKey;
        LSTATUS result = RegOpenKeyExA(HKEY_LOCAL_MACHINE, redistKey, 0, KEY_READ, &hKey);
        if (result == ERROR_SUCCESS)
        {
            DWORD majorVersion = 0;
            DWORD minorVersion = 0;
            DWORD dataSize = sizeof(DWORD);

            bool okMajor = RegQueryValueExA(hKey, "Major", nullptr, nullptr,
                reinterpret_cast<LPBYTE>(&majorVersion), &dataSize) == ERROR_SUCCESS;
            bool okMinor = RegQueryValueExA(hKey, "Minor", nullptr, nullptr,
                reinterpret_cast<LPBYTE>(&minorVersion), &dataSize) == ERROR_SUCCESS;

            RegCloseKey(hKey);

            // We require at least v14.40 of the runtime, and also ensure that
            // vcruntime140.dll can actually be loaded.
            if (okMajor && okMinor && majorVersion >= 14 && minorVersion >= 40)
            {
                HMODULE hModule = LoadLibraryW(L"vcruntime140.dll");
                if (hModule != NULL)
                {
                    FreeLibrary(hModule);
                    return; // Runtime is installed correctly; nothing else to do.
                }
            }
        }

        // If we reach this point, either the key was not found
        // or the version/dll is not acceptable. Prompt the user to install it.
        const char* redistUrl =
#ifdef _WIN64
            R"(https://aka.ms/vs/17/release/vc_redist.x64.exe)";
#else
            R"(https://aka.ms/vs/17/release/vc_redist.x86.exe)";
#endif

        const char* message =
            "TombEngine requires the Microsoft Visual C++ 2015-2022 Redistributable to be installed.\n"
            "Would you like to download it now?";

        int msgBoxResult = MessageBoxA(
            nullptr,
            message,
            "Missing libraries",
            MB_ICONWARNING | MB_OKCANCEL);

        if (msgBoxResult == IDOK)
        {
            // Launch the default browser to download the redistributable.
            HINSTANCE hResult = ShellExecuteA(
                nullptr,
                "open",
                redistUrl,
                nullptr,
                nullptr,
                SW_SHOWNORMAL);

            if ((intptr_t)hResult <= 32)
            {
                // ShellExecute failed. Show a more detailed error.
                std::string err = "Failed to start browser to download runtimes. Error code: ";
                err += std::to_string(static_cast<long>(reinterpret_cast<intptr_t>(hResult)));

                MessageBoxA(
                    nullptr,
                    err.c_str(),
                    "Error",
                    MB_ICONERROR | MB_OK);
            }
        }
    }

    void WindowsSubsystem::InstallExceptionFilter()
    {
        SetUnhandledExceptionFilter(HandleException);
    }

    void WindowsSubsystem::CheckPrerequisites()
    {
        CheckVcRedist();
    }

    void WindowsSubsystem::InstallCrashHandler()
    {
        InstallExceptionFilter();
    }

    void WindowsSubsystem::ShowErrorMessage(const std::string& text, MessageBoxIcon icon)
    {
        UINT flags = MB_OK;
        switch (icon)
        {
        case MessageBoxIcon::Info:
            flags |= MB_ICONINFORMATION;
            break;
        case MessageBoxIcon::Warning:
            flags |= MB_ICONWARNING;
            break;
        case MessageBoxIcon::Error:
        default:
            flags |= MB_ICONERROR;
            break;
        }

        MessageBoxA(
            nullptr,
            text.c_str(),
            "TombEngine",
            flags);
    }

    void WindowsSubsystem::Tick()
    {
        // No periodic Windows-specific work is required at the moment.
        // This method exists as a hook for future functionality
        // (e.g. console polling, OS integration, etc.).
    }

    void WindowsSubsystem::Shutdown()
    {
        CoUninitialize();
    }

    std::vector<unsigned short> WindowsSubsystem::GetProductOrFileVersion(bool productVersion)
    {
        auto fileName = GetBinaryPath(true);

        DWORD dummy;
        DWORD size = GetFileVersionInfoSizeW(fileName.data(), &dummy);

        if (size == 0)
        {
            TENLog("GetFileVersionInfoSizeW failed", LogLevel::Error);
            return {};
        }

        std::unique_ptr<unsigned char[]> buffer(new unsigned char[size]);

        // Load version info.
        if (!GetFileVersionInfoW(fileName.data(), 0, size, buffer.get()))
        {
            TENLog("GetFileVersionInfoW failed", LogLevel::Error);
            return {};
        }

        VS_FIXEDFILEINFO* info;
        unsigned int infoSize;

        if (!VerQueryValueW(buffer.get(), L"\\", (void**)&info, &infoSize))
        {
            TENLog("VerQueryValueW failed", LogLevel::Error);
            return {};
        }

        if (infoSize != sizeof(VS_FIXEDFILEINFO))
        {
            TENLog("VerQueryValueW returned wrong size for VS_FIXEDFILEINFO", LogLevel::Error);
            return {};
        }

        if (productVersion)
        {
            return
            {
                HIWORD(info->dwProductVersionMS),
                LOWORD(info->dwProductVersionMS),
                HIWORD(info->dwProductVersionLS),
                LOWORD(info->dwProductVersionLS)
            };
        }
        else
        {
            return
            {
                HIWORD(info->dwFileVersionMS),
                LOWORD(info->dwFileVersionMS),
                HIWORD(info->dwFileVersionLS),
                LOWORD(info->dwFileVersionLS)
            };
        }
    }

    bool WindowsSubsystem::Is64Bit()
    {
#ifdef _WIN64
        return true;
#else
        return false;
#endif
    }

    std::unique_ptr<ISubsystem> CreatePlatformSubsystem()
    {
        // On Windows, we return the concrete WindowsSubsystem.
        return std::make_unique<WindowsSubsystem>();
    }

    void WindowsSubsystem::SetSDL3Window(SDL_Window* window)
    {
        _window = window;
    }

    SDL_Window* WindowsSubsystem::GetSDL3Window()
    {
        return _window;
    }

    void WindowsSubsystem::HideConsole()
    {
        FreeConsole();
    }

} // namespace TEN::Platform

#endif