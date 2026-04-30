@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%.."
set "EMBED_CLI=%ROOT_DIR%\builder\embed_cli_build.exe"
if exist "%ROOT_DIR%\builder\embed_cli_stage.exe" set "EMBED_CLI=%ROOT_DIR%\builder\embed_cli_stage.exe"

if not exist "%EMBED_CLI%" set "EMBED_CLI=%ROOT_DIR%\builder\embed_cli.exe"

if not exist "%EMBED_CLI%" (
  echo ERROR: embed_cli not found at %EMBED_CLI%
  echo Run build_builder.bat first.
  exit /b 1
)

if "%~4"=="" (
  echo Usage: embed_release.bat ^<launcher_stub.exe^> ^<staging_dir^> ^<output.exe^> ^<app_version^> [work_dir]
  echo Example defaults:
  echo   embed_release.bat "%ROOT_DIR%\dist\launcher_stub.exe" "%ROOT_DIR%\staging" "%ROOT_DIR%\dist\Mywbstd.exe" "1.0.0" "%ROOT_DIR%\work"
  exit /b 1
)

if "%~5"=="" (
  "%EMBED_CLI%" "%~1" "%~2" "%~3" "%~4"
) else (
  "%EMBED_CLI%" "%~1" "%~2" "%~3" "%~4" "%~5"
)
if errorlevel 1 exit /b 1

echo Embedded EXE created: %~3
