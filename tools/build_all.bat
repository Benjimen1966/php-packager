@echo off
setlocal

set "SCRIPT_DIR=%~dp0"

echo Generating staging manifest...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%generate_manifest.ps1" -PackagerYml "%SCRIPT_DIR%..\staging\packager.yml" -OutputManifest "%SCRIPT_DIR%..\staging\manifest.json"
if errorlevel 1 exit /b 1

call "%SCRIPT_DIR%build_launcher.bat" || exit /b 1
call "%SCRIPT_DIR%build_builder.bat" || exit /b 1
call "%SCRIPT_DIR%build_updater.bat" || exit /b 1
echo All projects built.
