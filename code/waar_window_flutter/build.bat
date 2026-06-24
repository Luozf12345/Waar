@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "APP_NAME=waar_window_flutter"
set "DEFAULT_FLUTTER_SDK=%USERPROFILE%\tools\flutter1"
set "LOCAL_PROP_FILE=local.prop"

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%I in ("%SCRIPT_DIR%\..\..") do set "REPO_ROOT=%%~fI"
set "OUTPUT_RELEASE=%REPO_ROOT%\app"
set "OUTPUT_DEBUG=%REPO_ROOT%\app\debug"
set "BUILD_MODE="

:parse_args
if "%~1"=="" goto :args_done
if /I "%~1"=="-h" goto :usage
if /I "%~1"=="--help" goto :usage
if /I "%~1"=="help" goto :usage
if /I "%~1"=="--flutter-sdk" (
  if "%~2"=="" (
    echo Missing value for --flutter-sdk
    goto :usage
  )
  set "FLUTTER_SDK=%~2"
  shift
  shift
  goto :parse_args
)
if /I "%~1"=="debug" (
  if defined BUILD_MODE (
    echo Duplicate build mode: %~1
    goto :usage
  )
  set "BUILD_MODE=debug"
  shift
  goto :parse_args
)
if /I "%~1"=="release" (
  if defined BUILD_MODE (
    echo Duplicate build mode: %~1
    goto :usage
  )
  set "BUILD_MODE=release"
  shift
  goto :parse_args
)
echo Unknown argument: %~1
goto :usage

:args_done
if not defined BUILD_MODE (
  echo Select build mode:
  echo   1^) debug
  echo   2^) release
  set /p "CHOICE=Choice [1-2] (default: 2): "
  if "!CHOICE!"=="1" (
    set "BUILD_MODE=debug"
  ) else (
    set "BUILD_MODE=release"
  )
)

if not defined FLUTTER_SDK (
  call :load_flutter_sdk_from_local_prop
)
if not defined FLUTTER_SDK (
  set "FLUTTER_SDK=%DEFAULT_FLUTTER_SDK%"
)

set "FLUTTER_BIN=%FLUTTER_SDK%\bin\flutter.bat"
if not exist "%FLUTTER_BIN%" (
  echo Flutter executable not found: %FLUTTER_BIN%
  exit /b 1
)

if /I "%BUILD_MODE%"=="debug" (
  set "OUT_DIR=%OUTPUT_DEBUG%"
  set "PRODUCT_DIR=Debug"
  set "APK_NAME=app-debug.apk"
) else if /I "%BUILD_MODE%"=="release" (
  set "OUT_DIR=%OUTPUT_RELEASE%"
  set "PRODUCT_DIR=Release"
  set "APK_NAME=app-release.apk"
) else (
  echo Unknown build mode: %BUILD_MODE%
  goto :usage
)

echo ==^> Build mode   : %BUILD_MODE%
echo ==^> Platform     : Windows (x64^)
echo ==^> Flutter SDK  : %FLUTTER_SDK%
echo ==^> Output dir   : %OUT_DIR%
echo.

pushd "%SCRIPT_DIR%"
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
call :sync_android_local_properties

echo ==^> Building APK...
call "%FLUTTER_BIN%" build apk --%BUILD_MODE%
if errorlevel 1 goto :failed

echo ==^> Building desktop app...
call "%FLUTTER_BIN%" build windows --%BUILD_MODE%
if errorlevel 1 goto :failed

echo ==^> Copying artifacts...
set "APK_SRC=%SCRIPT_DIR%\build\app\outputs\flutter-apk\%APK_NAME%"
if not exist "%APK_SRC%" (
  echo APK not found: %APK_SRC%
  goto :failed
)
copy /Y "%APK_SRC%" "%OUT_DIR%\%APP_NAME%.apk" >nul

set "WIN_SRC=%SCRIPT_DIR%\build\windows\x64\runner\%PRODUCT_DIR%"
if not exist "%WIN_SRC%" (
  echo Windows build not found: %WIN_SRC%
  goto :failed
)
if exist "%OUT_DIR%\%APP_NAME%" rmdir /S /Q "%OUT_DIR%\%APP_NAME%"
mkdir "%OUT_DIR%\%APP_NAME%"
xcopy /E /I /Y "%WIN_SRC%\*" "%OUT_DIR%\%APP_NAME%\" >nul

popd

echo.
echo Build completed.
echo Artifacts:
echo   - %OUT_DIR%\%APP_NAME%.apk
echo   - %OUT_DIR%\%APP_NAME%\
goto :eof

:load_flutter_sdk_from_local_prop
set "PROP_FILE=%SCRIPT_DIR%\%LOCAL_PROP_FILE%"
if not exist "%PROP_FILE%" exit /b 0
for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%PROP_FILE%") do (
  if /I "%%A"=="flutter.sdk" (
    set "FLUTTER_SDK=%%B"
    goto :expand_flutter_sdk
  )
)
exit /b 0

:expand_flutter_sdk
if not defined FLUTTER_SDK exit /b 0
set "FLUTTER_SDK=%FLUTTER_SDK:"=%"
for /f "tokens=* delims= " %%A in ("%FLUTTER_SDK%") do set "FLUTTER_SDK=%%A"
if /I "%FLUTTER_SDK:~0,2%"=="~/" (
  set "FLUTTER_SDK=%USERPROFILE%\%FLUTTER_SDK:~2%"
) else if "%FLUTTER_SDK:~0,1%"=="~" (
  set "FLUTTER_SDK=%USERPROFILE%%FLUTTER_SDK:~1%"
)
exit /b 0

:sync_android_local_properties
set "ANDROID_PROPS=%SCRIPT_DIR%\android\local.properties"
set "SDK_DIR_LINE="
if exist "%ANDROID_PROPS%" (
  for /f "usebackq delims=" %%L in (`findstr /B /C:"sdk.dir=" "%ANDROID_PROPS%" 2^>nul`) do (
    set "SDK_DIR_LINE=%%L"
  )
)
> "%ANDROID_PROPS%" echo flutter.sdk=%FLUTTER_SDK%
if defined SDK_DIR_LINE >> "%ANDROID_PROPS%" echo !SDK_DIR_LINE!
exit /b 0

:usage
echo Usage: build.bat [options] [debug^|release]
echo.
echo Options:
echo   --flutter-sdk ^<path^>  Override Flutter SDK directory
echo                           priority: --flutter-sdk ^> FLUTTER_SDK env ^> local.prop ^> %DEFAULT_FLUTTER_SDK%
echo.
echo Build APK and Windows desktop app.
echo   release -^> app\
echo   debug   -^> app\debug\
exit /b 1

:failed
popd 2>nul
exit /b 1
