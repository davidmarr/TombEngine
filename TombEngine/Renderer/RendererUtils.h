#pragma once
#include <string>
#include <wrl/client.h>

namespace TEN::Renderer::Utils
{
	void throwIfFailed(const HRESULT& res);
	void throwIfFailed(const HRESULT& res, const std::string& info);
	void throwIfFailed(const HRESULT& res, const std::wstring& info);

	std::wstring GetAssetPath(const wchar_t* fileName);
}
