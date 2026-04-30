@echo off
setlocal EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%.."
set "MANIFEST=%ROOT_DIR%\staging\manifest.json"
set "CFG_FILE=%TEMP%\packager_output_dir_%RANDOM%.tmp"
set "CFG_OUTPUT_DIR=dist"
set "OUT_DIR=%ROOT_DIR%\dist"
set "BUILD_EMBED_CLI=%ROOT_DIR%\builder\embed_cli_build.exe"
set "STAGE_EMBED_CLI=%ROOT_DIR%\builder\embed_cli_stage.exe"
set "PRIMARY_EMBED_CLI=%ROOT_DIR%\builder\embed_cli.exe"

if exist "%MANIFEST%" (
	powershell -NoProfile -Command "(Get-Content -Raw -LiteralPath '%MANIFEST%' | ConvertFrom-Json).output_dir" > "%CFG_FILE%"
	set /p CFG_OUTPUT_DIR=<"%CFG_FILE%"
	if exist "%CFG_FILE%" del /q "%CFG_FILE%" >nul 2>nul
	if "!CFG_OUTPUT_DIR!"=="" set "CFG_OUTPUT_DIR=dist"
	set "CFG_OUTPUT_DIR=!CFG_OUTPUT_DIR:/=\!"
	if "!CFG_OUTPUT_DIR:~1,1!"==":" (
		set "OUT_DIR=!CFG_OUTPUT_DIR!"
	) else (
		set "OUT_DIR=%ROOT_DIR%\!CFG_OUTPUT_DIR!"
	)
)

set "FPC_EXE="
if defined FPC set "FPC_EXE=%FPC%"
if not defined FPC_EXE if exist "C:\lazarus40\fpc\3.2.2\bin\x86_64-win64\fpc.exe" set "FPC_EXE=C:\lazarus40\fpc\3.2.2\bin\x86_64-win64\fpc.exe"
if not defined FPC_EXE (
	where fpc >nul 2>nul
	if not errorlevel 1 set "FPC_EXE=fpc"
)
if not defined FPC_EXE (
	echo ERROR: Free Pascal compiler not found. Set FPC env var or install FPC.
	exit /b 1
)

echo Building embed_cli...
if not exist "%ROOT_DIR%\builder" mkdir "%ROOT_DIR%\builder"
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

"%FPC_EXE%" -Fu"%ROOT_DIR%\builder\src" -Fu"%ROOT_DIR%\shared\src" -FE"%ROOT_DIR%\builder" -o"%STAGE_EMBED_CLI%" "%ROOT_DIR%\builder\embed_cli.lpr"
if errorlevel 1 exit /b 1

copy /y "%STAGE_EMBED_CLI%" "%BUILD_EMBED_CLI%" >nul 2>nul
if errorlevel 1 (
	echo WARN: Could not refresh builder\embed_cli_build.exe - likely locked. Using staged binary for this build.
	set "BUILD_EMBED_CLI=%STAGE_EMBED_CLI%"
) else (
	del /q "%STAGE_EMBED_CLI%" >nul 2>nul
)

copy /y "%BUILD_EMBED_CLI%" "%PRIMARY_EMBED_CLI%" >nul 2>nul
if errorlevel 1 (
  echo WARN: Could not refresh builder\embed_cli.exe - likely locked. Using builder\embed_cli_build.exe for packaging.
)

copy /y "%BUILD_EMBED_CLI%" "%OUT_DIR%\embed_cli.exe" >nul 2>nul
if errorlevel 1 (
	echo WARN: Could not refresh output_dir\embed_cli.exe - likely locked. Using builder\embed_cli.exe for packaging.
)
echo Done.
