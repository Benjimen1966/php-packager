@echo off
setlocal EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%.."
set "MANIFEST=%ROOT_DIR%\staging\manifest.json"
set "CFG_FILE=%TEMP%\packager_output_dir_%RANDOM%.tmp"
set "CFG_OUTPUT_DIR=dist"
set "OUT_DIR=%ROOT_DIR%\dist"

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

echo Building launcher...
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
"%FPC_EXE%" -Fu"%ROOT_DIR%\launcher\src" -Fu"%ROOT_DIR%\shared\src" -FE"%OUT_DIR%" -o"%OUT_DIR%\launcher_stub.exe" "%ROOT_DIR%\launcher\launcher.lpr"
if errorlevel 1 exit /b 1
echo Done.
