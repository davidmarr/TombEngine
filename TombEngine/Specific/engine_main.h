#pragma once

#include <process.h>
#include <vector>
#include <SDL3/SDL.h>
#include "Math/Math.h"
#include "Platform/ISubsystem.h"

using TEN::Platform::ISubsystem;
using TEN::Platform::MessageBoxIcon;
using TEN::Platform::CreatePlatformSubsystem;

using namespace TEN::Math;

extern std::string GameDirectory;
extern std::unique_ptr<ISubsystem> g_Platform;
extern bool ResetClock;

int main(int argc, char* argv[]);

Vector2i GetScreenResolution();
std::vector<Vector2i> GetAllSupportedScreenResolutions();
int GetCurrentScreenRefreshRate();
bool GenerateDummyLevel(const std::string& levelPath);
void PauseGameThread();
void ResumeGameThread();
void WaitIfGamePaused();
void EngineClose();