@echo off@echo off

:: Build script for nsParser plugin - All configurations:: Build script for RDMVersion NSIS plugin



setlocal enabledelayedexpansionsetlocal enabledelayedexpansion



:: Project pathsset PROJECT_FILE=%~dp0RDMVersion.vcxproj

set PROJECT_DIR=%~dp0set PLUGINS_DIR=%~dp0..\plugins

set PROJECT_FILE=%PROJECT_DIR%nsParser.vcxproj

set PLUGINS_DIR=%~dp0..\plugins:: Find MSBuild

set MSBUILD_PATH=

:: Find MSBuild

set MSBUILD_PATH=if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" (

    set MSBUILD_PATH=C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe

if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" ()

    set MSBUILD_PATH=C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exeif exist "C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe" (

)    set MSBUILD_PATH=C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe

if exist "C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe" ()

    set MSBUILD_PATH=C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exeif exist "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe" (

)    set MSBUILD_PATH=C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe

if exist "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe" ()

    set MSBUILD_PATH=C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exeif exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" (

)    set MSBUILD_PATH=C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe

)

if "%MSBUILD_PATH%"=="" (if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\MSBuild.exe" (

    echo ERROR: MSBuild not found!    set MSBUILD_PATH=C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\MSBuild.exe

    echo Please install Visual Studio 2022 with C++ workload.)

    pause

    exit /b 1if "%MSBUILD_PATH%"=="" (

)    echo ERROR: MSBuild not found!

    echo Please install Visual Studio 2019 or 2022 with C++ workload.

echo ============================================    pause

echo Building nsParser plugin - All configurations    exit /b 1

echo ============================================)

echo MSBuild: %MSBUILD_PATH%

echo Project: %PROJECT_FILE%echo ============================================

echo.echo Building RDMVersion plugin

echo ============================================

set BUILD_FAILED=0echo MSBuild: %MSBUILD_PATH%

echo Project:  %PROJECT_FILE%

:: Build x86-ansi (Release Win32)echo.

echo.

echo Building x86-ansi...:: Build x86-unicode

echo ----------------------------------------echo Building x86-unicode...

"%MSBUILD_PATH%" "%PROJECT_FILE%" /t:Rebuild /p:Configuration="Release" /p:Platform=Win32 /p:WindowsTargetPlatformVersion=10.0 /p:PlatformToolset=v143 /maxcpucount /p:UseMultiToolTask=true /p:CL_MPCount=0 /v:minimalecho ----------------------------------------

if errorlevel 1 ("%MSBUILD_PATH%" "%PROJECT_FILE%" /t:Rebuild /p:Configuration="Release Unicode" /p:Platform=Win32 /p:WindowsTargetPlatformVersion=10.0 /maxcpucount /v:minimal

    echo ERROR: x86-ansi build failed!

    set BUILD_FAILED=1if errorlevel 1 (

) else (    echo.

    echo SUCCESS: x86-ansi DLL created    echo ERROR: Build failed!

)    pause

    exit /b 1

:: Build x86-unicode (Release Unicode Win32))

echo.

echo Building x86-unicode...:: Copy to plugins directory

echo ----------------------------------------set OUTPUT_FILE=%~dp0Plugins\x86-unicode\RDMVersion.dll

"%MSBUILD_PATH%" "%PROJECT_FILE%" /t:Rebuild /p:Configuration="Release Unicode" /p:Platform=Win32 /p:WindowsTargetPlatformVersion=10.0 /p:PlatformToolset=v143 /maxcpucount /p:UseMultiToolTask=true /p:CL_MPCount=0 /v:minimalset DEST_DIR=%PLUGINS_DIR%\x86-unicode

if errorlevel 1 (

    echo ERROR: x86-unicode build failed!if exist "%OUTPUT_FILE%" (

    set BUILD_FAILED=1    if not exist "%DEST_DIR%" mkdir "%DEST_DIR%"

) else (    copy /Y "%OUTPUT_FILE%" "%DEST_DIR%\" >nul

    echo SUCCESS: x86-unicode DLL created    echo.

)    echo ============================================

    echo Build successful!

:: Build x64-ansi (Release x64)    echo Plugin copied to: %DEST_DIR%\RDMVersion.dll

echo.    echo ============================================

echo Building x64-ansi...) else (

echo ----------------------------------------    echo.

"%MSBUILD_PATH%" "%PROJECT_FILE%" /t:Rebuild /p:Configuration="Release" /p:Platform=x64 /p:WindowsTargetPlatformVersion=10.0 /p:PlatformToolset=v143 /maxcpucount /p:UseMultiToolTask=true /p:CL_MPCount=0 /v:minimal    echo ERROR: Output file not found: %OUTPUT_FILE%

if errorlevel 1 (    pause

    echo ERROR: x64-ansi build failed!    exit /b 1

    set BUILD_FAILED=1)

) else (

    echo SUCCESS: x64-ansi DLL createdpause

)

:: Build amd64-unicode (Release Unicode x64)
echo.
echo Building amd64-unicode...
echo ----------------------------------------
"%MSBUILD_PATH%" "%PROJECT_FILE%" /t:Rebuild /p:Configuration="Release Unicode" /p:Platform=x64 /p:WindowsTargetPlatformVersion=10.0 /p:PlatformToolset=v143 /maxcpucount /p:UseMultiToolTask=true /p:CL_MPCount=0 /v:minimal
if errorlevel 1 (
    echo ERROR: amd64-unicode build failed!
    set BUILD_FAILED=1
) else (
    echo SUCCESS: amd64-unicode DLL created
)

echo.
echo ============================================
if %BUILD_FAILED%==1 (
    echo BUILD FAILED - Check errors above
    echo ============================================
    pause
    exit /b 1
) else (
    echo BUILD SUCCESSFUL - All configurations built
    echo ============================================
    echo.
    echo Output files:
    echo - %PLUGINS_DIR%\x86-ansi\nsParser.dll
    echo - %PLUGINS_DIR%\x86-unicode\nsParser.dll
    echo - %PLUGINS_DIR%\x64-ansi\nsParser.dll
    echo - %PLUGINS_DIR%\amd64-unicode\nsParser.dll
)

pause
