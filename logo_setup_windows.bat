@echo off
setlocal EnableDelayedExpansion

REM Navigate - Logo Setup Script (Windows)
REM Generates app icons from logo.png for all platforms
REM Usage: logo.bat

set SCRIPT_DIR=%~dp0
set LOGO_SOURCE=%SCRIPT_DIR%logo.png
set LOGO_DEST=%SCRIPT_DIR%navigate\assets\app_icon.png
set NAVIGATE_DIR=%SCRIPT_DIR%navigate
set FLUTTER_DIR=%SCRIPT_DIR%flutter
set WINDOWS_ICONS_DIR=%NAVIGATE_DIR%\windows\runner\resources

echo 🎨 Navigate Logo Setup
echo ==================================
echo.

REM Check if logo.png exists
if not exist "%LOGO_SOURCE%" (
    echo ❌ Error: logo.png not found at %LOGO_SOURCE%
    echo 💡 Please ensure logo.png exists in the project root directory
    exit /b 1
)

echo ✓ Found logo.png
echo.

REM Setup Flutter environment
if exist "%FLUTTER_DIR%" (
    set PATH=%FLUTTER_DIR%\bin;%PATH%
)

REM Check for Flutter
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ⚠️  Flutter not found in PATH
    echo Checking for local Flutter installation...
    
    if not exist "%FLUTTER_DIR%" (
        echo ❌ Error: Flutter not found and no local installation detected
        echo 💡 Please install Flutter or run start.bat first to clone Flutter SDK
        exit /b 1
    )
    
    set PATH=%FLUTTER_DIR%\bin;%PATH%
    
    where flutter >nul 2>nul
    if !ERRORLEVEL! NEQ 0 (
        echo ❌ Error: Flutter not found after adding to PATH
        exit /b 1
    )
)

echo ✓ Flutter found
echo.

REM Create assets directory if it doesn't exist
if not exist "%SCRIPT_DIR%navigate\assets" mkdir "%SCRIPT_DIR%navigate\assets"

REM Copy logo to assets
echo 📋 Copying logo to assets...
copy /Y "%LOGO_SOURCE%" "%LOGO_DEST%" >nul
echo ✓ Logo copied to %LOGO_DEST%
echo.

REM Navigate to Flutter project
cd "%NAVIGATE_DIR%"

REM Generate Windows icons (ICO format)
echo 🪟 Generating Windows icons...
echo ⚠️  Note: Proper .ico generation requires ImageMagick or similar tools.
echo    Ideally, install flutter_launcher_icons package and configure it for Windows.

REM Check if flutter_launcher_icons is configured and run it
call flutter pub run flutter_launcher_icons >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo ✓ Windows icons generated (via flutter_launcher_icons)
) else (
    REM Try with dart run if flutter pub run fails
    call dart run flutter_launcher_icons >nul 2>nul
    if !ERRORLEVEL! EQU 0 (
        echo ✓ Windows icons generated (via dart run)
    ) else (
        echo ⚠️  Warning: Failed to generate Windows icons automatically.
        echo    Please manually update the icon at:
        echo    %WINDOWS_ICONS_DIR%\app_icon.ico
    )
)
echo.

echo ✅ Logo setup complete!
echo.
echo 📦 Next steps:
echo    - Rebuild your app to see the new logo
echo    - Run: start.bat
echo.

