@echo off
setlocal EnableDelayedExpansion

REM Navigate - Windows Release Build Script
REM Builds release versions of the app for distribution
REM Usage: release.bat [--skip-build]

set SKIP_BUILD=false
set SCRIPT_DIR=%~dp0
set RELEASE_DIR=%SCRIPT_DIR%release
set NAVIGATE_DIR=%SCRIPT_DIR%navigate
set FLUTTER_DIR=%SCRIPT_DIR%flutter
set SECP256K1_DIR=%SCRIPT_DIR%secp256k1

REM Parse arguments
for %%a in (%*) do (
    if "%%a"=="--skip-build" set SKIP_BUILD=true
)

echo 📦 Navigate Release Build (Windows)
echo ==================================
echo.
echo Release directory: %RELEASE_DIR%
echo.

REM Setup Flutter environment
if exist "%FLUTTER_DIR%" (
    set PATH=%FLUTTER_DIR%\bin;%PATH%
)

REM Check for Flutter
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ⚠️  Flutter not found in PATH
    echo Cloning Flutter SDK...
    
    if not exist "%FLUTTER_DIR%" (
        echo 📥 Cloning Flutter SDK...
        git clone https://github.com/flutter/flutter.git -b stable "%FLUTTER_DIR%"
    )
    
    set PATH=%FLUTTER_DIR%\bin;%PATH%
    
    where flutter >nul 2>nul
    if !ERRORLEVEL! NEQ 0 (
        echo ❌ Error: Flutter not found after cloning.
        exit /b 1
    )
)

echo ✓ Flutter found
echo.

REM Build native libraries if needed
if "%SKIP_BUILD%"=="false" (
    echo 🔧 Building secp256k1 native libraries...
    echo.
    
    REM Clone secp256k1 if not exists
    if not exist "%SECP256K1_DIR%" (
        echo 📥 Cloning secp256k1 from bitcoin-core (tag v0.7.0)...
        git clone https://github.com/bitcoin-core/secp256k1.git "%SECP256K1_DIR%"
        pushd "%SECP256K1_DIR%"
        git checkout v0.7.0
        popd
    )
    
    pushd "%SECP256K1_DIR%"
    
    REM Check for CMake
    where cmake >nul 2>nul
    if %ERRORLEVEL% NEQ 0 (
        echo ❌ Error: CMake not found. Please install CMake.
        exit /b 1
    )

    if not exist "build\windows" mkdir build\windows
    cd build\windows
    
    echo 🪟 Building for Windows...
    cmake ..\.. -DSECP256K1_ENABLE_MODULE_RECOVERY=ON -DSECP256K1_BUILD_TESTS=OFF -DSECP256K1_BUILD_BENCHMARK=OFF -DSECP256K1_BUILD_EXHAUSTIVE_TESTS=OFF
    cmake --build . --config Release
    
    if exist "Release\secp256k1.dll" (
        echo ✓ Windows library built
    ) else (
        echo ❌ Error: Windows library build failed
        exit /b 1
    )
    
    popd
    echo.
) else (
    echo ⏭️  Skipping native library build
    echo.
)

REM Navigate to Flutter project
cd "%NAVIGATE_DIR%"

if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"

echo 🪟 Building Windows release...
flutter build windows --release

set WINDOWS_BUNDLE=%NAVIGATE_DIR%\build\windows\runner\Release

if not exist "%WINDOWS_BUNDLE%" (
    echo ❌ Error: Windows bundle not found at %WINDOWS_BUNDLE%
    exit /b 1
)

REM Copy library to build folder before packaging
set LIB_SOURCE=%SECP256K1_DIR%\build\windows\Release\secp256k1.dll
copy "%LIB_SOURCE%" "%WINDOWS_BUNDLE%\" >nul 2>nul

REM Copy to release directory
set RELEASE_PLATFORM_DIR=%RELEASE_DIR%\windows
if exist "%RELEASE_PLATFORM_DIR%" rmdir /s /q "%RELEASE_PLATFORM_DIR%"
mkdir "%RELEASE_PLATFORM_DIR%"
xcopy "%WINDOWS_BUNDLE%\*" "%RELEASE_PLATFORM_DIR%\" /E /I /Y >nul

echo ✓ Windows release built
echo   Location: %RELEASE_PLATFORM_DIR%
echo.

echo ✅ Release build complete!
echo.
echo 📦 Release files are in: %RELEASE_DIR%\windows
echo.

