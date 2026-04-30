@echo off
setlocal EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%.."
set "MANIFEST=%ROOT_DIR%\staging\manifest.json"
set "LAUNCHER_STUB=%ROOT_DIR%\dist\launcher_stub.exe"
set "STAGING_DIR=%ROOT_DIR%\staging"
set "CFG_OUTPUT_FILE=%TEMP%\packager_output_dir_%RANDOM%.tmp"
set "CFG_WORK_FILE=%TEMP%\packager_work_dir_%RANDOM%.tmp"
set "USER_OUTPUT_EXE=%~1"
set "APP_VERSION=%~2"
set "CFG_OUTPUT_DIR=dist"
set "CFG_WORK_DIR=work"
set "WORK_DIR=%ROOT_DIR%\work"
set "SIGNTOOL_EXE="
set "TIMESTAMP_URL=http://timestamp.digicert.com"

if defined SIGN_TIMESTAMP_URL set "TIMESTAMP_URL=%SIGN_TIMESTAMP_URL%"

if defined SIGNTOOL set "SIGNTOOL_EXE=%SIGNTOOL%"
if not defined SIGNTOOL_EXE if exist "C:\Program Files (x86)\Windows Kits\10\bin\x64\signtool.exe" set "SIGNTOOL_EXE=C:\Program Files (x86)\Windows Kits\10\bin\x64\signtool.exe"
if not defined SIGNTOOL_EXE if exist "C:\Program Files\Windows Kits\10\bin\x64\signtool.exe" set "SIGNTOOL_EXE=C:\Program Files\Windows Kits\10\bin\x64\signtool.exe"
if not defined SIGNTOOL_EXE (
	where signtool >nul 2>nul
	if not errorlevel 1 set "SIGNTOOL_EXE=signtool"
)

if "%APP_VERSION%"=="" set "APP_VERSION=1.0.0"

if defined STRICT_RELEASE (
	if not defined SIGN_CERT_SHA1 (
		echo ERROR: STRICT_RELEASE is set but SIGN_CERT_SHA1 is not configured.
		echo        Set SIGN_CERT_SHA1 to your certificate thumbprint to enable Authenticode signing,
		echo        or unset STRICT_RELEASE to allow unsigned release builds.
		exit /b 1
	)
)

echo Generating staging manifest...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%generate_manifest.ps1" -PackagerYml "%ROOT_DIR%\staging\packager.yml" -OutputManifest "%MANIFEST%"
if errorlevel 1 exit /b 1

powershell -NoProfile -Command "(Get-Content -Raw -LiteralPath '%MANIFEST%' | ConvertFrom-Json).output_dir" > "%CFG_OUTPUT_FILE%"
powershell -NoProfile -Command "(Get-Content -Raw -LiteralPath '%MANIFEST%' | ConvertFrom-Json).work_dir" > "%CFG_WORK_FILE%"

set /p CFG_OUTPUT_DIR=<"%CFG_OUTPUT_FILE%"
set /p CFG_WORK_DIR=<"%CFG_WORK_FILE%"

if exist "%CFG_OUTPUT_FILE%" del /q "%CFG_OUTPUT_FILE%" >nul 2>nul
if exist "%CFG_WORK_FILE%" del /q "%CFG_WORK_FILE%" >nul 2>nul

if "!CFG_OUTPUT_DIR!"=="" set "CFG_OUTPUT_DIR=dist"
if "!CFG_WORK_DIR!"=="" set "CFG_WORK_DIR=work"

set "CFG_OUTPUT_DIR=!CFG_OUTPUT_DIR:/=\!"
set "CFG_WORK_DIR=!CFG_WORK_DIR:/=\!"

if "%USER_OUTPUT_EXE%"=="" (
	if "!CFG_OUTPUT_DIR:~1,1!"==":" (
		set "OUTPUT_EXE=!CFG_OUTPUT_DIR!\Mywbstd.exe"
	) else (
		set "OUTPUT_EXE=%ROOT_DIR%\!CFG_OUTPUT_DIR!\Mywbstd.exe"
	)
) else (
	set "OUTPUT_EXE=%USER_OUTPUT_EXE%"
)

if "!CFG_WORK_DIR:~1,1!"==":" (
	set "WORK_DIR=!CFG_WORK_DIR!"
) else (
	set "WORK_DIR=%ROOT_DIR%\!CFG_WORK_DIR!"
)

if "!CFG_OUTPUT_DIR:~1,1!"==":" (
	set "LAUNCHER_STUB=!CFG_OUTPUT_DIR!\launcher_stub.exe"
	set "OUTPUT_DIR_ABS=!CFG_OUTPUT_DIR!"
) else (
	set "LAUNCHER_STUB=%ROOT_DIR%\!CFG_OUTPUT_DIR!\launcher_stub.exe"
	set "OUTPUT_DIR_ABS=%ROOT_DIR%\!CFG_OUTPUT_DIR!"
)

echo Building launcher, builder, updater...
call "%SCRIPT_DIR%build_launcher.bat" || exit /b 1
call "%SCRIPT_DIR%build_builder.bat" || exit /b 1
call "%SCRIPT_DIR%build_updater.bat" || exit /b 1

echo Embedding release payload...
call "%SCRIPT_DIR%embed_release.bat" "%LAUNCHER_STUB%" "%STAGING_DIR%" "%OUTPUT_EXE%" "%APP_VERSION%" "%WORK_DIR%" || exit /b 1

if defined SIGN_CERT_SHA1 (
	if not defined SIGNTOOL_EXE (
		echo ERROR: SIGN_CERT_SHA1 is set but signtool was not found.
		exit /b 1
	)
	call :sign_file "%LAUNCHER_STUB%" || exit /b 1
	if exist "%OUTPUT_DIR_ABS%\updater.exe" call :sign_file "%OUTPUT_DIR_ABS%\updater.exe" || exit /b 1
	call :sign_file "%OUTPUT_EXE%" || exit /b 1
) else (
	echo Signing skipped. Set SIGN_CERT_SHA1 to enable Authenticode signing.
)

echo Release build complete: %OUTPUT_EXE%
exit /b 0

:sign_file
set "TARGET_FILE=%~1"
if not exist "%TARGET_FILE%" (
	echo ERROR: Signing target not found: %TARGET_FILE%
	exit /b 1
)

echo Signing: %TARGET_FILE%
"%SIGNTOOL_EXE%" sign /fd SHA256 /sha1 "%SIGN_CERT_SHA1%" /tr "%TIMESTAMP_URL%" /td SHA256 "%TARGET_FILE%"
if errorlevel 1 exit /b 1

exit /b 0
