@echo off
setlocal enabledelayedexpansion
set DOC_DIR=.\doc
set CSS_DIR=%DOC_DIR%\css
set CUSTOM_CSS_DIR=.\css
set LDOC_DIR=.\compiler\ldoc
set LUA_PATH=.\compiler\?.lua
set LUA_CPATH=.\compiler\?.dll

REM Check if argument is provided, if not, set to "."
if "%~1"=="" (
    set ARG=.
) else (
    set ARG=%*
)

echo Building LDoc documentation...
rmdir /s /q %DOC_DIR%
mkdir %DOC_DIR%

echo Running LDoc compiler...
.\compiler\lua.exe %LDOC_DIR%\ldoc.lua %ARG%

if %ERRORLEVEL% neq 0 (
    echo LDoc compilation failed with error code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

echo Organizing CSS files...
mkdir %CSS_DIR%
if exist "%DOC_DIR%\ldoc.css" (
    move /Y %DOC_DIR%\ldoc.css %CSS_DIR%\
    echo CSS moved to css folder
    
    echo Updating CSS references in HTML files...
    powershell -Command "(Get-ChildItem '%DOC_DIR%' -Filter *.html -Recurse) | ForEach-Object { (Get-Content $_.FullName -Raw) -replace 'ldoc\.css', 'css/ldoc.css' | Set-Content $_.FullName -NoNewline }"
)

if exist "%CUSTOM_CSS_DIR%" (
    echo Processing custom CSS files...
    xcopy /Y /Q "%CUSTOM_CSS_DIR%\*.css" "%CSS_DIR%\"
    
    echo Adding custom CSS links to HTML files...
    for %%d in ("%DOC_DIR%") do set "docFullPath=%%~fd"
    
    for %%f in (%CUSTOM_CSS_DIR%\*.css) do (
        set "cssName=%%~nf"
        
        for /r "%DOC_DIR%" %%h in (!cssName!.html) do (
            if exist "%%h" (
                set "htmlDir=%%~dph"
                set "htmlDir=!htmlDir:~0,-1!"
                set "relPath=!htmlDir:%docFullPath%=!"
                set "depth=0"
                
                if not "!relPath!"=="" (
                    for %%a in ("!relPath:\=" "!") do set /a depth+=1
                )
                
                set "cssPath="
                if !depth! gtr 0 (
                    for /l %%i in (1,1,!depth!) do set "cssPath=!cssPath!../"
                )
                set "cssPath=!cssPath!css/!cssName!.css"
                
                powershell -Command "$content = Get-Content '%%h' -Raw; $link = '    <link rel=\"stylesheet\" href=\"!cssPath!\">' + [Environment]::NewLine + '</head>'; $content = $content -replace '</head>', $link; Set-Content '%%h' $content -NoNewline"
            )
        )
    )
)

echo Post-processing Settings XML structure...
powershell.exe -ExecutionPolicy Bypass -File "settings_class_post_process.ps1"

if %ERRORLEVEL% neq 0 (
    echo XML post-processing failed with error code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

echo Documentation build completed successfully!
exit /b 0
