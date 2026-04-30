@echo off
setlocal EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%.."
set "MANIFEST=%ROOT_DIR%\staging\manifest.json"
set "CFG_FILE=%TEMP%\packager_output_dir_%RANDOM%.tmp"
set "CFG_OUTPUT_DIR=dist"
set "SOURCE_DIR=%ROOT_DIR%\dist"
set "ISS_FILE=%ROOT_DIR%\installer\setup.iss"
set "ISCC_EXE="
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

if defined STRICT_RELEASE (
  if not defined SIGN_CERT_SHA1 (
    echo ERROR: STRICT_RELEASE is set but SIGN_CERT_SHA1 is not configured.
    echo        Set SIGN_CERT_SHA1 to your certificate thumbprint to enable Authenticode signing,
    echo        or unset STRICT_RELEASE to allow unsigned installer builds.
    exit /b 1
  )
)

if not exist "%MANIFEST%" (
  echo Generating staging manifest...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%generate_manifest.ps1" -PackagerYml "%ROOT_DIR%\staging\packager.yml" -OutputManifest "%MANIFEST%"
  if errorlevel 1 exit /b 1
)

powershell -NoProfile -Command "(Get-Content -Raw -LiteralPath '%MANIFEST%' | ConvertFrom-Json).output_dir" > "%CFG_FILE%"
set /p CFG_OUTPUT_DIR=<"%CFG_FILE%"
if exist "%CFG_FILE%" del /q "%CFG_FILE%" >nul 2>nul

if "!CFG_OUTPUT_DIR!"=="" set "CFG_OUTPUT_DIR=dist"
set "CFG_OUTPUT_DIR=!CFG_OUTPUT_DIR:/=\!"

if "!CFG_OUTPUT_DIR:~1,1!"==":" (
  set "SOURCE_DIR=!CFG_OUTPUT_DIR!"
) else (
  set "SOURCE_DIR=%ROOT_DIR%\!CFG_OUTPUT_DIR!"
)

if not exist "%SOURCE_DIR%\Mywbstd.exe" (
  echo ERROR: Missing packaged app EXE at "%SOURCE_DIR%\Mywbstd.exe"
  echo Run tools\build_release.bat first.
  exit /b 1
)

if not exist "%SOURCE_DIR%\updater.exe" (
  echo ERROR: Missing updater EXE at "%SOURCE_DIR%\updater.exe"
  echo Run tools\build_updater.bat or tools\build_release.bat first.
  exit /b 1
)

if defined ISCC set "ISCC_EXE=%ISCC%"
if not defined ISCC_EXE if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" set "ISCC_EXE=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not defined ISCC_EXE if exist "C:\Program Files\Inno Setup 6\ISCC.exe" set "ISCC_EXE=C:\Program Files\Inno Setup 6\ISCC.exe"
if not defined ISCC_EXE if exist "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" set "ISCC_EXE=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
if not defined ISCC_EXE (
  where iscc >nul 2>nul
  if not errorlevel 1 set "ISCC_EXE=iscc"
)

if not defined ISCC_EXE (
  echo ERROR: Inno Setup compiler not found. Set ISCC env var or install Inno Setup 6.
  exit /b 1
)

echo Building installer from source dir: %SOURCE_DIR%
"%ISCC_EXE%" /Qp /DBuildSourceDir="%SOURCE_DIR%" "%ISS_FILE%"
if errorlevel 1 exit /b 1

if defined SIGN_CERT_SHA1 (
  if not defined SIGNTOOL_EXE (
    echo ERROR: SIGN_CERT_SHA1 is set but signtool was not found.
    exit /b 1
  )
  set "SETUP_EXE=%ROOT_DIR%\installer\Output\MywbstdSetup.exe"
  if not exist "%SETUP_EXE%" (
    echo ERROR: Installer output not found: %SETUP_EXE%
    exit /b 1
  )
  echo Signing installer: %SETUP_EXE%
  "%SIGNTOOL_EXE%" sign /fd SHA256 /sha1 "%SIGN_CERT_SHA1%" /tr "%TIMESTAMP_URL%" /td SHA256 "%SETUP_EXE%"
  if errorlevel 1 exit /b 1
) else (
  echo Installer signing skipped. Set SIGN_CERT_SHA1 to enable Authenticode signing.
)

echo Installer build complete.
