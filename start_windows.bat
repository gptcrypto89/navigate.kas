@echo off
setlocal EnableDelayedExpansion

REM Navigate - Windows Setup and Run Script
REM Builds native libraries and runs the Flutter app on Windows
REM Usage: start.bat [--skip-build] [--debug]

set SKIP_BUILD=false
set DEBUG=false
set SCRIPT_DIR=%~dp0
set SECP256K1_DIR=%SCRIPT_DIR%secp256k1
set NAVIGATE_DIR=%SCRIPT_DIR%navigate
set FLUTTER_DIR=%SCRIPT_DIR%flutter

REM Parse arguments
for %%a in (%*) do (
    if "%%a"=="--skip-build" set SKIP_BUILD=true
    if "%%a"=="--debug" set DEBUG=true
)

echo 🚀 Navigate Setup and Launch (Windows)
echo ==================================
echo.

REM Show debug status
if "%DEBUG%"=="true" (
    echo 🐛 Debug logging: ENABLED
    echo.
) else (
    echo 🐛 Debug logging: DISABLED
    echo.
)

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

echo 📱 Launching Navigate on Windows...
echo.

REM Ensure library exists
set LIB_SOURCE=%SECP256K1_DIR%\build\windows\Release\secp256k1.dll
if not exist "%LIB_SOURCE%" (
    REM Try looking in just Release/ if not in build/windows/Release
    set LIB_SOURCE=%SECP256K1_DIR%\Release\secp256k1.dll
)

if not exist "%LIB_SOURCE%" (
    echo ❌ Error: Native library not found.
    echo 💡 Please build the library first by running: start.bat
    exit /b 1
)

REM Copy library to build directory for running
set BUILD_DIR=%NAVIGATE_DIR%\build\windows\runner\Debug
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"
copy "%LIB_SOURCE%" "%BUILD_DIR%\" >nul 2>nul

if "%DEBUG%"=="true" (
    echo 🚀 Running app in debug mode...
    flutter run -d windows --debug --verbose
) else (
    echo 🚀 Running app...
    flutter run -d windows
)

echo.
echo 🎉 Navigate is running!

